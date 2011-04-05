require 'spec_helper'

describe TwilioController do
  render_views
  before(:each) do
    @request.env["HTTP_ACCEPT"] = "application/xml"
  end

  describe "when not logged in" do
    it "should be success" do
  	  controller.user_signed_in?.should be_false
      post :greeting
      response.content_type.should =~ /^application\/xml/
      response.should be_success
    end
  end

  describe "greeting" do
    it "should say hello" do
      post :greeting
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>gather', :numdigits => '1')
      response.should have_selector('response>gather', :action => 'http://actionpods.heroku.com/twilio/join_conference.xml')
      response.should have_selector('response>gather>say', :content => 'Hello')
      response.should have_selector('response>gather>say', :content => 'Please press 1')
    end

    it "should match up with the event being called" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call')      
      Call.create(:Sid => '12345', :event_id => event.id)
      post :greeting, :CallSid => '12345'
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>gather', :numdigits => '1')
      response.should have_selector('response>gather>say', :content => 'Hello, welcome to your Morning Call.')
    end
  end

  describe "join_conference" do
    it "should join a conference room" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 33)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      Call.create(:Sid => '54321', :event_id => event.id)
      post :join_conference, :CallSid => '54321'
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Joining a conference room')
      response.should have_selector('response>dial', :timelimit => (33 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => 'MyRoom')
    end
  end
  
  describe "incoming" do
    it "should say hello" do
      post :incoming
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>gather', :numdigits => '1')
      response.should have_selector('response>gather', :action => 'http://actionpods.heroku.com/twilio/join_conference.xml')
      response.should have_selector('response>gather>say', :content => 'Hello')
      response.should have_selector('response>gather>say', :content => 'Please press 1')
    end

    # How do we match up incoming calls?
    # it "should match up with the event being called" do
    #   user = Factory(:user)
    #   event = Factory(:event, :user_id => user.id, :name => 'Morning Call')      
    #   Call.create(:Sid => '12345', :event_id => event.id)
    #   post :greeting, :CallSid => '12345'
    #   response.content_type.should =~ /^application\/xml/
    #   response.should have_selector('response>gather', :numdigits => '1')
    #   response.should have_selector('response>gather>say', :content => 'Hello, welcome to your Morning Call.')
    # end
  end

  describe "sms" do
    it "should send back a welcome message" do
      post :sms
      response.should have_selector('response>sms', :content => "Welcome to ActionPods.  See actionpods.heroku.com for more information.")
    end
  end
end
