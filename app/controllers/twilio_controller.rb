class TwilioController < ApplicationController

  def greeting
    @postto = base_url + '/join_conference.xml'
    respond_to { |format| format.xml { @postto } }
  end

  def join_conference
    respond_to { |format| format.xml }
  end

  def base_url 
    "http://actionpods.heroku.com/twilio"
  end

end
