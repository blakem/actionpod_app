require 'spec_helper'

describe PagesController do
  render_views

  describe "success" do
    it "should be successful when logged in" do
      get 'home'
      response.should be_success
    end   
  end
end
