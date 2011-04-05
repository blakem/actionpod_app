require 'spec_helper'

describe PagesController do
  render_views
  describe "when not logged in" do
    it "should show a welcome page" do
  	  controller.user_signed_in?.should be_false
      get :home
      response.should have_selector('h3', :content => 'Welcome')
    end
    
    it "should use a default Time.zone" do
      Time.zone = 'UTC'
      get :home
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
    
    it "should show 'You don't have any scheduled calls' when appropriate" do
      user = controller.current_user
      user.events.should be_empty
      get 'home'
      response.should have_selector('h3', :content => "You don't have any scheduled calls")
    end
    
    it "should show a link to your Events" do
      user = controller.current_user
      event = Factory(:event, :user_id => user.id)
      
      get 'home'
      response.should have_selector('h3', :content => "Your Scheduled Calls:")
      response.should have_selector('ul>li', :content => event.schedule_str)
      response.should have_selector('ul>li', :content => event.name)
    end

    it "should show the Users name" do
      user = controller.current_user
      user.name.should_not be_empty
      get 'home'
      response.should have_selector('h3', :content => "Welcome #{user.name}")
    end

  end
end
