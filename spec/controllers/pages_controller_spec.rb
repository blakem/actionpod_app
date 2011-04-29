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
      response.should have_selector('title', :content => '15 Minute Calls')
    end   

    it "should be successful when logged in as admin" do
	    controller.user_signed_in?.should be_true
      controller.admin_signed_in?.should be_false
      controller.current_user.admin = "true"
      controller.current_user.save
      controller.admin_signed_in?.should be_true      
      get :home
      response.should be_success
      response.should have_selector('title', :content => '15 Minute Calls')
    end   

    it "should use the users time_zone" do
      Time.zone.to_s.should == '(GMT-08:00) Pacific Time (US & Canada)'
    end
        
    it "should show a link to your Events" do
      user = controller.current_user
      event = Factory(:event, :user_id => user.id)
      
      get :home
      response.should have_selector('i', :content => event.name)
    end

    it "should show the Users name" do
      user = controller.current_user
      user.name.should_not be_empty
      get :home
      response.should have_selector('h1', :content => user.name )
    end
  end

  describe "GET /pages/help" do

    describe "success" do
      it "should be successful when not logged in" do
  	    controller.user_signed_in?.should be_false
        get :help
        response.should be_success
      end

      it "should be successful when logged in" do
        login_user
  	    controller.user_signed_in?.should be_true
        get :help
        response.should be_success
      end
    end
  end

  describe "GET /pages/call_groups" do

    describe "success" do
      it "should be successful when logged in" do
        login_user
  	    controller.user_signed_in?.should be_true
        get :call_groups
        response.should be_success
      end
    end
  end

  describe "GET /pages/conference" do

    describe "success" do
      it "redirect without a proper id" do
        login_user
  	    controller.user_signed_in?.should be_true
        get :conference, :id => 'lll'
        flash[:alert].should =~ /There is no conference with that id/i
        response.should redirect_to(root_path)
      end

      it "should redirect when not logged in" do
        conference = Conference.create!()
  	    controller.user_signed_in?.should be_false
        get :conference, :id => conference.id
        response.should redirect_to(new_user_session_path)
      end
      
      it "shows the names of the users in the conference" do
        login_user
        user1 = Factory(:user)
        user2 = Factory(:user)
        conference = Conference.create!()
        conference.users = [user1, user2]
        get :conference, :id => conference.id
        response.body.should =~ /#{user1.name}/
        response.body.should =~ /#{user2.name}/
      end
    end
  end

  describe "GET /u/handle" do
    login_user_before_each

    describe "success" do
      it "should be successful when logged in" do
  	    controller.user_signed_in?.should be_true
        user2 = Factory(:user)
        get :profile, :handle => user2.handle 
        response.should be_success
        response.should have_selector('h1', :content => user2.name )
        response.should have_selector('title', :content => '15 Minute Calls')
      end
    end
    
    describe "failure" do
      it "should redirect if given an incorrect handle" do
  	    controller.user_signed_in?.should be_true
        get :profile, :handle => 'somethingthatdoesnotmatch'
        flash[:alert].should =~ /There is no handle by that name/i
        response.should redirect_to(root_path)
      end      
    end
  end

  describe "GET /callcal" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :callcal
        response.should redirect_to(new_user_session_path)
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
