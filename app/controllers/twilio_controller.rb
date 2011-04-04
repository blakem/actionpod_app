class TwilioController < ApplicationController

  respond_to :html, :xml
  def greeting
    @event_name = "Call"
    call_sid = params[:CallSid]
    call = Call.find_by_Sid(call_sid)
    event = Event.find_by_id(call.event_id) if call
    @event_name = event.name if event
    @postto = base_url + '/join_conference.xml'
  end

  def join_conference
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
end
