require 'spec_helper'

describe PagesController do
  render_views
  describe "when not logged in" do
    it "should redirect to the login page" do
	  controller.user_signed_in?.should be_false
      get 'home'
      response.should redirect_to(:action=>"new", :controller=>"devise/sessions")
    end
  end
  
  describe "success" do
    login_user
 
    it "should be successful when logged in" do
	  controller.user_signed_in?.should be_true
      get 'home'
      response.should be_success
      response.should have_selector('title', :content => 'ActionPods')
    end   
  end
end
