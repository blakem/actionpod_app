class TwilioController < ApplicationController

  respond_to :html, :xml
  def greeting
    @postto = base_url + '/join_conference.xml'
  end

  def join_conference
  end

  private
    def base_url 
      "http://actionpods.heroku.com/twilio"
    end
end
