require 'spec_helper'

describe TwilioController do
  render_views
  describe "when not logged in" do
    it "should be success" do
  	  controller.user_signed_in?.should be_false
      get 'greeting.xml'
      response.content_type.should =~ /^application\/xml/
      response.should be_success
    end
  end

  describe "greeting" do
    it "should say hello" do
      get 'greeting.xml'
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>gather', :numdigits => '1')
      # response.should have_selector('response>gather', :action => 'join_conference.xml')
      response.should have_selector('response>gather>say', :content => 'Hello')
      response.should have_selector('response>gather>say', :content => 'Please press 1')
    end
  end

  describe "join_conference" do
    it "should join a conference room" do
      get 'join_conference.xml'
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Joining a conference room')
      response.should have_selector('response>dial>conference', :content => 'MyRoom')
    end
  end
end
