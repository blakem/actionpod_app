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

  describe "GET /pages/public_groups" do

    describe "success" do
      it "should show public groups" do
        login_user
        pool1 = Factory(:pool, :name => 'MyPublicGroup', :public_group => true)
        pool2 = Factory(:pool, :name => 'MyPrivateGroup', :public_group => false)
  	    controller.user_signed_in?.should be_true
        get :public_groups
        response.should be_success
        response.body.should =~ /MyPublicGroup/
        response.body.should_not =~ /MyPrivateGroup/
      end
    end
  end

  describe "GET /pages/manage_groups" do
    describe "success" do
      it "should be successful when logged in" do
        login_user
        Pool.default_pool.should_not be_nil
  	    controller.user_signed_in?.should be_true
        get :manage_groups
        response.should be_success
      end
    end
  end
  
  describe "GET /pages/remove_from_group" do
    before(:each) do
      login_user
      @other_user = Factory(:user)
      @pool = Factory(:pool, :admin_id => @current_user.id)
      @other_user.pools = [@pool]      
    end

    describe "success" do
      it "should remove a user from a group you are admin of" do
        get :remove_from_group, :member_id => @other_user.id, :group_id => @pool.id
        flash[:notice].should =~ /#{@other_user.name} was removed from the group/
        response.should redirect_to(invite_pool_path(@pool))
        @other_user.reload
        @other_user.pools.should be_empty
      end

      it "should remove yourself from a group you are not admin of" do
        @user2 = Factory(:user)
        @pool2 = Factory(:pool, :admin_id => @user2.id)
        @event = Factory(:event, :user_id => @current_user.id, :pool_id => @pool2.id)
        event_id = @event.id
        @current_user.pools << @pool2
        get :remove_from_group, :member_id => @current_user.id, :group_id => @pool2.id
        response.should redirect_to(:controller => :pages, :action => :manage_groups, :notice => 'You have been removed from the group.')
        @current_user.reload
        @current_user.pools.should_not include(@pool2)
        Event.find_by_id(event_id).should be_nil
      end
    end
    
    describe "failure" do
      it "should redirect to root on bad group id" do
        get :remove_from_group, :member_id => @other_user.id, :group_id => @pool.id + 1
        flash[:alert].should =~ /You don't have access to that page/
        response.should redirect_to(root_path)
      end

      it "should redirect to root on bad member id" do
        get :remove_from_group, :member_id => @other_user.id + 1, :group_id => @pool.id
        flash[:alert].should =~ /You don't have access to that page/
        response.should redirect_to(root_path)
      end

      it "should redirect if you try to delete the admin of a group" do
        get :remove_from_group, :member_id => @pool.admin_id, :group_id => @pool.id
        flash[:alert].should =~ /You cannot remove yourself from this group./
        response.should redirect_to(invite_pool_path(@pool))
      end      

      it "should redirect if you try to delete someone else from a group you aren't admin of" do
        @user2 = Factory(:user)
        @pool2 = Factory(:pool, :admin_id => @user2.id)
        @other_user.pools << @pool2
        get :remove_from_group, :member_id => @other_user, :group_id => @pool2.id
        flash[:alert].should =~ /You don't have access to that page/
        response.should redirect_to(root_path)
      end      
    end
  end

  describe "GET /pages/join" do
    describe "success" do
      before(:each) do
        login_user
        @pool = Factory(:pool, :public_group => false)
        @public_pool = Factory(:pool, :public_group => true)
        @current_user.pools = [@pool]
      end

      it "should create an event" do
        get :join, :time => '7:00am', :group_id => @pool.id
        event = Event.where(
          :user_id => @current_user.id,
          :pool_id => @pool.id,
        )[0]
        event.time.should == '7:00am'
        event.days.should == [1,2,3,4,5]
        expect {
          get :join, :time => '7:00am', :group_id => @pool.id          
        }.should_not change(Event, :count)
      end

      it "should set the days appropriately" do
        get :join, :time => '7:00am', :group_id => @pool.id, :days => '5,2,3'
        event = Event.where(
          :user_id => @current_user.id,
          :pool_id => @pool.id,
        )[0]
        event.time.should == '7:00am'
        event.days.should == [2,3,5]
      end

      it "should set the days appropriately" do
        get :join, :time => '7:00am', :group_id => @pool.id, :days => ''
        event = Event.where(
          :user_id => @current_user.id,
          :pool_id => @pool.id,
        )[0]
        event.time.should == '7:00am'
        event.days.should == [1,2,3,4,5]
      end

      it "should redirect if given a bad pool_id" do
        get :join, :time => '7:00am', :group_id => @pool.id + 10
        response.should redirect_to(root_path)
      end

      it "should work if the pool is public, even if you aren't a member yet" do
        @current_user.pools = [@pool]
        get :join, :time => '7:00am', :group_id => @public_pool.id
        event = Event.where(
          :user_id => @current_user.id,
          :pool_id => @public_pool.id,
        )[0]
        event.time.should == '7:00am'
        @current_user.reload
        @current_user.pools.should include(@public_pool)
        @current_user.pools.should include(@pool)
      end

      it "should redirect if the pool is not public" do
        @current_user.pools = []
        get :join, :time => '7:00am', :group_id => @pool.id
        response.should redirect_to(root_path)
      end
    end
  end

  describe "GET /pages/invite_members" do
    before(:each) do
      login_user
      @other_user = Factory(:user)
      @other_user2 = Factory(:user)
      @other_user3 = Factory(:user)
      @pool = Factory(:pool, :admin_id => @current_user.id)
      @other_pool = Factory(:pool, :admin_id => @other_user.id)
    end

    describe "success" do
      it "should add a user to the group you invite them to" do
        ActionMailer::Base.deliveries = []
        expect {
          get :invite_members, :group_id => @pool.id, :emails => "#{@other_user.email}", :message => 'Foo'
        }.to change(MemberInvite, :count).by(1)
        response.should redirect_to(invite_pool_path(@pool))
        flash[:notice].should =~ /Invites have been sent./
        @other_user.reload
        @other_user.pools.should include(@pool)
  
        invites = MemberInvite.where(
          :sender_id => @current_user.id,
          :to_id => @other_user.id,
          :pool_id => @pool.id,
        )
        invites.count.should == 1
        invites.first.body.should =~ /Foo/
        invites.first.invite_code.length.should == 20
        ActionMailer::Base.deliveries.count.should == 1
        email = ActionMailer::Base.deliveries.first
        email.subject.should =~ /#{@current_user.name} has added you to the: #{@pool.name_plus_group}/
        email.body.should =~ /#{@current_user.name} has added you to the group: #{@pool.name}/
        email.body.should =~ /Foo/
        email.to.should == [@other_user.email]
        email.from.should == [@current_user.email]
      end

      it "should add users to the group you invite them to" do
        get :invite_members, :group_id => @pool.id, :emails => "#{@other_user.email}, #{@other_user2.email}"
        response.should redirect_to(invite_pool_path(@pool))
        flash[:notice].should =~ /Invites have been sent./
        @other_user.reload
        @other_user.pools.should include(@pool)
        @other_user2.reload
        @other_user2.pools.should include(@pool)
      end

      it "should add users to the group you invite them to" do
        get :invite_members, :group_id => @pool.id, :emails => "#{@other_user.email},#{@other_user2.email.upcase}   \n   #{@other_user3.email}   "
        response.should redirect_to(invite_pool_path(@pool))
        flash[:notice].should =~ /Invites have been sent./
        @other_user.reload
        @other_user.pools.should include(@pool)
        @other_user2.reload
        @other_user2.pools.should include(@pool)
        @other_user3.reload
        @other_user3.pools.should include(@pool)
      end

      it "shouldn't add users to the group if they are already members" do
        @other_user.pools = [@pool]
        get :invite_members, :group_id => @pool.id, :emails => "#{@other_user.email}"
        response.should redirect_to(invite_pool_path(@pool))
        flash[:notice].should =~ /Invites have been sent./
        @other_user.reload
        @other_user.pools.should == [@pool]
      end

      it "should email and invite to a non-user" do
        ActionMailer::Base.deliveries = []
        test_email = 'bobby@example.com'
        expect {
          get :invite_members, :group_id => @pool.id, :emails => test_email, :message => 'NewCoolGroup Message'
        }.to change(MemberInvite, :count).by(1)
        response.should redirect_to(invite_pool_path(@pool))
        flash[:notice].should =~ /Invites have been sent./  
        invites = MemberInvite.where(
          :sender_id => @current_user.id,
          :pool_id => @pool.id,
          :to_id => nil,
          :email => test_email,
          :message => 'NewCoolGroup Message'
        )
        invites.count.should == 1
        invites.first.body.should =~ /NewCoolGroup Message/
        invites.first.invite_code.length.should == 20
        ActionMailer::Base.deliveries.count.should == 1

        email = ActionMailer::Base.deliveries.first
        email.subject.should =~ /#{@current_user.name} has invited you to join the #{@pool.name_plus_group}/
        email.body.should =~ /This is an invitation from #{@current_user.name} for you to join the group '#{@pool.name}'/
        email.body.should =~ /NewCoolGroup Message/
        email.to.should == [test_email]
        email.from.should == [@current_user.email]
      end
    end
    
    describe "failure" do
      it "can't invite to someone else's group" do
        get :invite_members, :group_id => @other_pool.id, :emails => "#{@other_user2.email}"
        response.should redirect_to(root_path)
        flash[:alert].should =~ /You don't have access to that page/
        @other_user2.reload
        @other_user2.pools.should_not include(@other_pool)
      end

      it "can't invite to a nonexistant group" do
        get :invite_members, :group_id => @other_pool.id + 10, :emails => "#{@other_user2.email}"
        response.should redirect_to(root_path)
        flash[:alert].should =~ /You don't have access to that page/
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
      it "shows the names of the users in the time_slot" do
        login_user
        user1 = Factory(:user)
        user2 = Factory(:user)
        user3 = Factory(:user)
        pool = Factory(:pool)
        pool.users = User.all
        event1 = Factory(:event, :user_id => user1.id, :pool_id => pool.id)
        event2 = Factory(:event, :user_id => user2.id, :pool_id => pool.id)
        event3 = Factory(:event, :user_id => user3.id, :pool_id => pool.id)
        event1.time = '10:00pm'
        event2.time = '10:00pm'
        event3.time = '11:00pm'
        event1.save
        event2.save
        event3.save
        get :time_slot, :time => '10:00pm', :group_id => pool.id
        response.body.should     =~ /#{user1.name}/
        response.body.should     =~ /#{user2.name}/
        response.body.should_not =~ /#{user3.name}/
      end

      it "shows the name of the pool if it isn't the default group" do
        login_admin
        pool = Factory(:pool, :name => 'Not The Default Group')
        user = Factory(:user)
        pool.users = [@current_user]
        event = Factory(:event, :user_id => user.id, :pool_id => pool.id)
        event.time = '4:34pm'
        event.save
        get :time_slot, :time => '4:34pm', :group_id => pool.id
        response.body.should =~ /#{pool.name}/
      end
    end

    describe "failure" do
      it "redirect without a proper time" do
        login_user
        pool = Factory(:pool)
        @current_user.pools = [pool]
  	    controller.user_signed_in?.should be_true
        get :time_slot, :time => 'lll', :group_id => pool.id
        flash[:alert].should =~ /There is no call at that time/i
        response.should redirect_to(root_path)
      end

      it "should redirect when not logged in" do
        pool = Factory(:pool)
  	    controller.user_signed_in?.should be_false
        get :time_slot, :time => '8:00am', :group_id => pool.id
        response.should redirect_to(new_user_session_path)
      end

      it "should redirect if given a bad pool_id" do
        login_user
        pool = Factory(:pool)
        get :time_slot, :time => '7:00am', :group_id => pool.id + 1
        response.should redirect_to(root_path)
      end

      it "should redirect if you aren't in the pool" do
        login_user
        pool = Factory(:pool)
        @current_user.pools = []
        get :time_slot, :time => '7:00am', :group_id => pool.id
        response.should redirect_to(root_path)
      end
    end
  end

  describe "GET /member/handle" do
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

  describe "GET /pages/member_invite_email" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :member_invite_email
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :member_invite_email
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        user = Factory(:user)
        pool = Factory(:pool)
        MemberInvite.create(
          :sender_id => @current_user.id,
          :to_id => user.id,
          :pool_id => pool.id,
          :invite_code => 'abcdef',
          :body => "Foo",
          :email => user.email,
          :message => 'Blah',
        )
        get :member_invite_email
        response.should be_success
        response.body.should =~ /#{pool.name}/
        response.body.should =~ /#{user.name}/
        response.body.should =~ /Blah/
        response.body.should =~ /#{@current_user.name}/
      end
    end
  end

  describe "GET /pages/nonmember_invite_email" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :nonmember_invite_email
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :nonmember_invite_email
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        pool = Factory(:pool)
        email = 'xyzzyabc@example.com'
        MemberInvite.create(
          :sender_id => @current_user.id,
          :to_id => nil,
          :pool_id => pool.id,
          :invite_code => 'abcdef',
          :body => "Foo",
          :email => email,
          :message => 'Blah',
        )
        get :nonmember_invite_email
        response.should be_success
        response.body.should =~ /#{pool.name}/
        response.body.should =~ /Blah/
        response.body.should =~ /#{@current_user.name}/
      end
    end
  end

  describe "GET /pages/confirmation_email" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :confirmation_email
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :confirmation_email
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        get :confirmation_email
        response.should be_success
        response.body.should =~ /blakem@15minutecalls.com/
      end
    end
  end

  describe "GET /pages/conference_email" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :conference_email
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :conference_email
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        admin_phone = Factory(:phone, :user_id => @current_user.id, :primary => true)
        user1 = Factory(:user)
        phone1 = Factory(:phone, :user_id => user1.id, :primary => true)
        user2 = Factory(:user)
        phone2 = Factory(:phone, :user_id => user2.id, :primary => true)
        conference = Conference.create!(:status => 'completed')
        conference.users = [@current_user, user1, user2]
        get :conference_email
        response.should be_success
        response.body.should =~ /#{@current_user.email}/
        response.body.should =~ /Notes for your 15 Minute Call/
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

  describe "GET /pages/next_steps_email" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :next_steps_email
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :next_steps_email
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        get :next_steps_email
        response.should be_success
      end
    end
  end

  describe "GET /pages/calls" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :calls
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :calls
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        event1 = Factory(:event)
        event2 = Factory(:event)
        call1 = Call.create!(:status => 'outbound', :Duration => 45, :event_id => event1.id)
        call2 = Call.create!(:status => 'outbound', :Duration => nil, :event_id => event2.id)
        get :calls
        response.should be_success
        get :calls, :member_id => event1.user_id
        response.should be_success
        get :calls, :member_id => event1.user_id, :all => 1
        response.should be_success
      end
    end
  end

  describe "GET /pages/emails" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :emails
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when user logged in" do
      it "should redirect to the root path" do
        login_user
        get :emails
        flash[:alert].should =~ /You don't have access to that page/i
        response.should redirect_to(root_path)
      end
    end

    describe "when admin logged in" do
      it "should be a success" do
        login_admin
        user1 = Factory(:user)
        user2 = Factory(:user)
        MemberMessage.create!(:sender_id => user1.id, :to_id => user2.id, :body => 'Show the Message')
        get :emails
        response.should be_success
        response.body.should =~ /#{user1.name}/
        response.body.should =~ /#{user2.name}/
        response.body.should =~ /Show the Message/
      end
    end
  end

  describe "GET /pages/send_member_message" do
    describe "when not logged in" do
      it "should redirect to the root path" do
        controller.user_signed_in?.should be_false
        get :send_member_message
        response.should redirect_to(new_user_session_path)
      end
    end

    describe "when logged in" do
      login_user_before_each
      it "should redirect to the root path if no member_id is given" do
        get :send_member_message
        flash[:alert].should =~ /Sorry, we couldn't find that member./i
        response.should redirect_to(root_path)
      end

      it "should redirect to the user path if no body is given" do
        user = Factory(:user)
        get :send_member_message, :member_id => user.id
        flash[:alert].should =~ /Please enter a message to send./i
        response.should redirect_to(user.profile_path)
      end

      it "should redirect to the user path if the body is all blanks" do
        user = Factory(:user)
        get :send_member_message, :member_id => user.id, :body => '   '
        flash[:alert].should =~ /Please enter a message to send./i
        response.should redirect_to(user.profile_path)
      end

      it "should redirect to the conference page if a conference id is given" do
        user = Factory(:user)
        conference = Conference.create!
        get :send_member_message, :member_id => user.id, :body => 'blah', :conference_id => conference.id
        flash[:notice].should =~ /Thank you.  Your message has been sent to #{user.name}./i
        response.should redirect_to(:controller => :pages, :action => :conference, :id => conference.id)
      end

      it "should redirect to the user path if conference_id is invalid" do
        user = Factory(:user)
        conference = Conference.create!
        get :send_member_message, :member_id => user.id, :body => 'blah', :conference_id => conference.id + 1
        response.should redirect_to(user.profile_path)
      end

      it "should redirect to the root path if both conference_id and user_id are invalid" do
        user = Factory(:user)
        conference = Conference.create!
        get :send_member_message, :member_id => user.id + 1, :body => 'blah', :conference_id => conference.id + 1
        response.should redirect_to(root_path)
      end

      it "should send an email with the body to the member_id" do
        user = Factory(:user)
        UserMailer.should_receive(:deliver_member_message).with(user, @current_user, 'Test Message')
        expect {
          get :send_member_message, :member_id => user.id, :body => 'Test Message'
        }.to change(MemberMessage, :count).by(1)
        flash[:notice].should =~ /Thank you.  Your message has been sent to #{user.name}./i
        response.should redirect_to(user.profile_path)
        MemberMessage.where(
          :sender_id => @current_user.id,
          :to_id => user.id,
          :body => 'Test Message'
        ).length.should == 1
      end
    end
  end

  describe "GET /pages/prefer" do
    describe "more" do
      it "should prefer a user" do
        login_user
        other_user = Factory(:user)
        get :prefer, :other_user_id => other_user.id, :prefer => '3'
        flash[:notice].should =~ /more calls with #{other_user.first_name}./
        response.should redirect_to(other_user.profile_path)
        @current_user.reload
        @current_user.prefers?(other_user).should be_true
        @current_user.avoids?(other_user).should be_false
      end
      
      it "should avoid a user" do
        login_user
        other_user = Factory(:user)
        get :prefer, :other_user_id => other_user.id, :prefer => '1'
        flash[:notice].should =~ /fewer calls with #{other_user.first_name}./
        response.should redirect_to(other_user.profile_path)
        @current_user.reload
        @current_user.prefers?(other_user).should be_false
        @current_user.avoids?(other_user).should be_true
      end

      it "should set a user to standard" do
        login_user
        other_user = Factory(:user)
        @current_user.prefer!(other_user)
        get :prefer, :other_user_id => other_user.id, :prefer => '2'
        flash[:notice].should =~ /#{other_user.first_name} according to the standard algorithm./
        response.should redirect_to(other_user.profile_path)
        @current_user.reload
        @current_user.prefers?(other_user).should be_false
        @current_user.avoids?(other_user).should be_false
      end

      it "should redirect to the conference page if given a conference value" do
        login_user
        other_user = Factory(:user)
        @current_user.prefer!(other_user)
        conference = Conference.first
        get :prefer, :other_user_id => other_user.id, :prefer => '3', :conference => conference.id
        flash[:notice].should =~ /more calls with #{other_user.first_name}./
        response.should redirect_to(:controller => :pages, :action => :conference, :id => conference.id)
        @current_user.reload
        @current_user.prefers?(other_user).should be_true
        @current_user.avoids?(other_user).should be_false
      end
    end

    it "should handle bad other_user_id gracefully" do
      login_user
      other_user = Factory(:user)
      @current_user.prefer!(other_user)
      get :prefer, :other_user_id => other_user.id + 100, :prefer => '1'
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
      flash[:notice].should =~ /We couldn't understand that preference setting/
      response.should redirect_to(other_user.profile_path)
      @current_user.reload
      @current_user.prefers?(other_user).should be_true
      @current_user.avoids?(other_user).should be_false
    end
  end
end
