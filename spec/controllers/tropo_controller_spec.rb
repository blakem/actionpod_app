require 'spec_helper'

describe TropoController do
  describe "greeting" do
    it "should 'say'" do
      post :greeting
      puts response.body
      response.body.should =~ /say/
    end
  end
end
