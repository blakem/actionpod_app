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
      response.should have_selector('response>say', :content => 'Hello')
    end
  end
end
