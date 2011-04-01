class TwilioController < ApplicationController

  respond_to :html, :xml
  def greeting
    user = User.find_by_primary_phone(params[:To])
    if user
      event = user.events.first
    end
    @event_name = user && event ? event.name : ''
    @postto = base_url + '/join_conference.xml'
  end

  def join_conference
  end

  private
    def base_url 
      "http://actionpods.heroku.com/twilio"
    end
end
