class TwilioController < ApplicationController

  respond_to :html, :xml
  def greeting
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      output = render_to_string :action => :say_sorry
    else
      @event_name = event.name
      @postto = base_url + '/put_on_hold.xml'
      output  = render_to_string
    end
    $stderr.puts output if Rails.env.production?
    render :inline => output, :format => :xml
  end
  
  def say_sorry
  end

  def put_on_hold
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      @timelimit = event.pool.timelimit
      @pool = event.pool 
      @event = event
      @timelimit *= 60
    end
  end

  def incoming
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      TwilioCaller.create_call_from_call_hash(params.merge(:Sid => params[:CallSid]), event.id)
      @event_name = event.name
      @postto = base_url + '/put_on_hold.xml'
    end
  end
  
  def place_in_conference
    @timelimit = (params[:timelimit] || 15) * 60
    @conference = params[:conference] || 'DefaultConference'
  end
  
  def sms
  end

  private
    def base_url 
      "http://www.15minutecalls.com/twilio"
    end
    
    def find_event_from_params(params)
      call = match_call_from_params(params)
      return Event.find_by_id(call.event_id) if call
      user = match_user_from_params(params)
      return nil unless user
      user.events.each do |event|
        return event if event.schedule.occurs_on?(Time.now)
      end
      return nil
    end
    
    def match_call_from_params(params)
      call = Call.find_by_Sid(params[:CallSid])
      return call if call
      Call.where(:PhoneNumberSid => params[:PhoneNumberSid]).sort { |a,b| a.id <=> b.id }.last
    end
    
    def match_user_from_params(params)
      key = params[:Direction] == 'inbound' ? :From : :To
      User.find_by_primary_phone(params[key])
    end
end
