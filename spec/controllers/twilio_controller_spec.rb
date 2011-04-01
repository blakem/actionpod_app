require 'spec_helper'

describe TwilioController do
  describe "when not logged in" do
    it "should be success" do
  	  controller.user_signed_in?.should be_false
      get 'greeting.xml'
      response.should be_success
    end
  end
end
