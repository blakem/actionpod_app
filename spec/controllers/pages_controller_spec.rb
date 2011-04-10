require 'spec_helper'

describe PagesController do
  render_views
  describe "GET /home when not logged in" do
    it "should show a welcome page" do
  	  controller.user_signed_in?.should be_false
      get :home
      response.should have_selector('h1', :content => 'Welcome')
    end
    
    it "should use a default Time.zone" do
      Time.zone = 'UTC'
      get :home
      Time.zone.to_s.should == '(GMT+00:00) UTC'
    end
  end
  
  describe "GET /home success" do
    login_user_before_each
 
    it "should be successful when logged in" do
	    controller.user_signed_in?.should be_true
      get :home
      response.should be_success
      response.should have_selector('title', :content => '15-Minute Calls')
    end   

    it "should be successful when logged in as admin" do
	    controller.user_signed_in?.should be_true
      controller.admin_signed_in?.should be_false
      controller.current_user.admin = "true"
      controller.current_user.save
      controller.admin_signed_in?.should be_true      
      get :home
      response.should be_success
      response.should have_selector('title', :content => '15-Minute Calls')
    end   

    it "should use the users time_zone" do
      Time.zone.to_s.should == '(GMT-08:00) Pacific Time (US & Canada)'
    end
        
    it "should show a link to your Events" do
      user = controller.current_user
      event = Factory(:event, :user_id => user.id)
      
      get :home
      response.should have_selector('ul>li', :content => event.schedule_str)
      response.should have_selector('ul>li', :content => event.name)
    end

    it "should show the Users name" do
      user = controller.current_user
      user.name.should_not be_empty
      get :home
      response.should have_selector('h1', :content => user.name )
    end
  end


  describe "GET /callcal" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :callcal
        response.should redirect_to(root_path)
      end
    end

    describe "when logged in" do
      login_user_before_each
      it "should be a success" do
        controller.user_signed_in?.should be_true
        get :callcal
        response.should be_success
      end
    end
  end
end
