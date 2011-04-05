class TwilioController < ApplicationController

  respond_to :html, :xml
  def greeting
    event = find_event_from_params(params)
    @event_name = event ? event.name : "Call"
    @postto = base_url + '/join_conference.xml'
  end

  def join_conference
    event = find_event_from_params(params)
    @timelimit = event ? event.pool.timelimit : 30
    @timelimit *= 60
  end

  def incoming
    @postto = base_url + '/join_conference.xml'
  end
  
  def sms
  end

  private
    def base_url 
      "http://actionpods.heroku.com/twilio"
    end
    
    def find_event_from_params(params)
      call = match_call_from_params(params)
      call ? Event.find_by_id(call.event_id) : nil
    end
    
    def match_call_from_params(params)
      call = Call.find_by_Sid(params[:CallSid])
      return call if call
      Call.where(:PhoneNumberSid => params[:PhoneNumberSid]).sort { |a,b| a.id <=> b.id }.last
    end
end
