require 'spec_helper'

describe RailsAdmin::MainController do
  render_views
  describe "when not logged in" do
    it "should redirect to the login page" do
  	  controller.user_signed_in?.should be_false
  	  controller.admin_signed_in?.should be_false
      get 'index'
      response.should_not be_success
      response.should redirect_to(root_path)
    end
  end
  
  describe "when logged in as a non-admin user" do
    login_user_before_each
 
    it "should redirect to the login page" do
	    controller.user_signed_in?.should be_true
  	  controller.admin_signed_in?.should be_false
      get 'index'
      response.should_not be_success
      response.should redirect_to(root_path)
    end
  end
  
  describe "when logged in as an admin user" do
    login_admin_before_each
    it "should be a success" do
      get 'index'
	    controller.user_signed_in?.should be_true
  	  controller.admin_signed_in?.should be_true
      response.should be_success
      response.should have_selector('span', :content => 'Dashboard')      
    end
  end
end