require 'spec_helper'

describe PagesController do
  render_views
  describe "when not logged in" do
    it "should redirect to the login page" do
  	  controller.user_signed_in?.should be_false
      get 'home'
      response.should redirect_to(:action=>"new", :controller=>"devise/sessions")
    end
    
    it "should use a default Time.zone" do
      Time.zone.to_s.should == '(GMT+00:00) UTC'
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

    it "should be successful when logged in as admin" do
	    controller.user_signed_in?.should be_true
      controller.admin_signed_in?.should be_false
      controller.current_user.admin = "true"
      controller.current_user.save
      controller.admin_signed_in?.should be_true      
      get 'home'
      response.should be_success
      response.should have_selector('title', :content => 'ActionPods')
    end   

    it "should use the users time_zone" do
      Time.zone.to_s.should == '(GMT-08:00) Pacific Time (US & Canada)'
    end

  end
end
