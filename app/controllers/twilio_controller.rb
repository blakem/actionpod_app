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
      call_sid = params[:CallSid]
      call = Call.find_by_Sid(call_sid)
      call ? Event.find_by_id(call.event_id) : nil
    end
end
