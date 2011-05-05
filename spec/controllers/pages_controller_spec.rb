require 'spec_helper'

describe PagesController do
  render_views
  describe "GET /pages/home when not logged in" do
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

  describe "GET /pages/homepage" do
    it "should show a welcome page when not logged in" do
  	  controller.user_signed_in?.should be_false
      get :homepage
      response.should have_selector('h1', :content => 'Welcome')
      response.body.should =~ /Sign up now!/
    end

    it "should show a welcome page when logged in" do
      login_user
  	  controller.user_signed_in?.should be_true
      get :homepage
      response.should have_selector('h1', :content => 'Welcome')
      response.body.should_not =~ /Sign up now!/
    end    
  end
  
  describe "GET /pages/home success" do
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
        response.body.should =~ /Sign up now!/
      end

      it "should be successful when logged in" do
        login_user
        phone = Factory(:phone, :user_id => @current_user.id, :primary => true)
  	    controller.user_signed_in?.should be_true
        get :help
        response.should be_success
        response.body.should_not =~ /Sign up now!/
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
        conference = Conference.create!(:started_at => Time.now - 5.minutes)
        conference.users = [user1, user2]
        get :conference, :id => conference.id
        response.body.should =~ /#{user1.name}/
        response.body.should =~ /#{user2.name}/
      end
    end
  end

  describe "GET /pages/time_slot" do

    describe "success" do
      it "redirect without a proper time" do
        login_user
  	    controller.user_signed_in?.should be_true
        get :time_slot, :time => 'lll'
        flash[:alert].should =~ /There is no call at that time/i
        response.should redirect_to(root_path)
      end

      it "should redirect when not logged in" do
  	    controller.user_signed_in?.should be_false
        get :time_slot, :time => '8:00am'
        response.should redirect_to(new_user_session_path)
      end
      
      it "shows the names of the users in the time_slot" do
        login_user
        user1 = Factory(:user)
        user2 = Factory(:user)
        user3 = Factory(:user)
        event1 = Factory(:event, :user_id => user1.id)
        event2 = Factory(:event, :user_id => user2.id)
        event3 = Factory(:event, :user_id => user3.id)
        event1.time = '10:00pm'
        event2.time = '10:00pm'
        event3.time = '11:00pm'
        event1.save
        event2.save
        event3.save
        get :time_slot, :time => '10:00pm'
        response.body.should     =~ /#{user1.name}/
        response.body.should     =~ /#{user2.name}/
        response.body.should_not =~ /#{user3.name}/
      end

      it "shows the name of the pool if it isn't the default pool" do
        login_admin
        pool = Factory(:pool, :name => 'Not The Default Pool')
        user = Factory(:user)
        event = Factory(:event, :user_id => user.id, :pool_id => pool.id)
        event.time = '4:34pm'
        event.save
        pool.should_not == Pool.default_pool
        get :time_slot, :time => '4:34pm'
        response.body.should =~ /#{pool.name}/
      end
    end
  end

  describe "GET /u/handle" do
    describe "success" do
      it "should be successful when logged in" do
        login_user
  	    controller.user_signed_in?.should be_true
        user2 = Factory(:user)
        phone = Factory(:phone, :user_id => user2.id, :primary => true)
        phone_string = phone.number_pretty.sub(/\(/, "\\(").sub(/\)/, "\\)")
        get :profile, :handle => user2.handle 
        response.should be_success
        response.should have_selector('h1', :content => user2.name )
        response.should have_selector('title', :content => '15 Minute Calls')
        response.body.should =~ /#{user2.email}/
        response.body.should_not =~ /#{phone_string}/
      end

      it "should hide a users email when hide_email is turned on" do
        login_user
        user2 = Factory(:user, :hide_email => true)
        phone = Factory(:phone, :user_id => user2.id, :primary => true)        
        phone_string = phone.number_pretty.sub(/\(/, "\\(").sub(/\)/, "\\)")
        get :profile, :handle => user2.handle 
        response.should be_success
        response.should have_selector('h1', :content => user2.name )
        response.should have_selector('title', :content => '15 Minute Calls')
        response.body.should_not =~ /#{user2.email}/
        response.body.should_not =~ /#{phone_string}/
      end

      it "should show email and phone number if viewed by an admin" do
        login_admin
        user2 = Factory(:user, :hide_email => true)
        phone = Factory(:phone, :user_id => user2.id, :primary => true)        
        phone_string = phone.number_pretty.sub(/\(/, "\\(").sub(/\)/, "\\)")
        get :profile, :handle => user2.handle 
        response.should be_success
        response.should have_selector('h1', :content => user2.name )
        response.should have_selector('title', :content => '15 Minute Calls')
        response.body.should =~ /#{user2.email}/
        response.body.should =~ /#{phone_string}/
      end
    end
    
    describe "failure" do
      it "should redirect if given an incorrect handle" do
        login_user
  	    controller.user_signed_in?.should be_true
        get :profile, :handle => 'somethingthatdoesnotmatch'
        flash[:alert].should =~ /There is no handle by that name/i
        response.should redirect_to(root_path)
      end      
    end
  end

  describe "GET /pages/callcal" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :callcal
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :callcal
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        get :callcal
        response.should be_success
      end
    end
  end

  describe "GET /pages/stranded_users" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :stranded_users
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :stranded_users
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        get :stranded_users
        response.should be_success
      end
    end
  end

  describe "GET /pages/prefer" do
    describe "more" do
      it "should prefer a user" do
        login_user
        other_user = Factory(:user)
        get :prefer, :other_user_id => other_user.id, :prefer => 'more'
        flash[:notice].should =~ /You will be put on more calls with #{other_user.first_name}./
        response.should redirect_to('/u/' + other_user.handle)
        @current_user.reload
        @current_user.prefers?(other_user).should be_true
        @current_user.avoids?(other_user).should be_false
      end
      
      it "should avoid a user" do
        login_user
        other_user = Factory(:user)
        get :prefer, :other_user_id => other_user.id, :prefer => 'less'
        flash[:notice].should =~ /You will be put on fewer calls with #{other_user.first_name}./
        response.should redirect_to('/u/' + other_user.handle)
        @current_user.reload
        @current_user.prefers?(other_user).should be_false
        @current_user.avoids?(other_user).should be_true
      end

      it "should avoid a user" do
        login_user
        other_user = Factory(:user)
        @current_user.prefer!(other_user)
        get :prefer, :other_user_id => other_user.id, :prefer => 'standard'
        flash[:notice].should =~ /You will be teamed with #{other_user.first_name} according to the standard algorithm./
        response.should redirect_to('/u/' + other_user.handle)
        @current_user.reload
        @current_user.prefers?(other_user).should be_false
        @current_user.avoids?(other_user).should be_false
      end
    end

    it "should handle bad other_user_id gracefully" do
      login_user
      other_user = Factory(:user)
      @current_user.prefer!(other_user)
      get :prefer, :other_user_id => other_user.id + 100, :prefer => 'more'
      response.should redirect_to(root_path)
      @current_user.reload
      @current_user.prefers?(other_user).should be_true
      @current_user.avoids?(other_user).should be_false
    end

    it "should handle bad prefer values gracefully" do
      login_user
      other_user = Factory(:user)
      @current_user.prefer!(other_user)
      get :prefer, :other_user_id => other_user.id, :prefer => 'moreorless'
      response.should redirect_to('/u/' + other_user.handle)
      @current_user.reload
      @current_user.prefers?(other_user).should be_true
      @current_user.avoids?(other_user).should be_false
    end
  end
end
