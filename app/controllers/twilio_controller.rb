class TwilioController < ApplicationController

  respond_to :html, :xml
  def greeting
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      @event_name = event.name
      @postto = base_url + '/put_on_hold.xml'
    end
  end
  
  def greeting_fallback
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      self.put_on_hold
      render :action => :put_on_hold
    end
  end
  
  def callback
    call = Call.find_by_Sid(params[:CallSid])
    call.Duration = params[:CallDuration]
    call.save
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
      unless params[:CallSid].blank?
        call = Call.find_by_Sid(params[:CallSid])
        return call if call
      end
      unless params[:PhoneNumberSid].blank?
        call = Call.where(:PhoneNumberSid => params[:PhoneNumberSid]).sort { |a,b| a.id <=> b.id }.last
        return call if call
      end
      return nil
    end
    
    def match_user_from_params(params)
      key = params[:Direction] == 'inbound' ? :From : :To
      return nil if params[key].blank?
      User.find_by_primary_phone(params[key])
    end
end
