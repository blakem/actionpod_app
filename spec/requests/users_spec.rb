require 'spec_helper'

describe "Users" do
  
  describe "signup" do
    
    describe "failure" do
      it "should not make a new user" do
        lambda do
          visit new_user_registration_path
          fill_in "Invite Code",            :with => ""
          fill_in "Full Name",              :with => ""
          fill_in "Email",                  :with => ""
          fill_in "Primary Phone",          :with => ""
          fill_in "Title",                  :with => ""
          fill_in "Time Zone",              :with => ""
          fill_in "Password",               :with => ""
          fill_in "Password Confirmation",  :with => ""
          click_button
          response.should render_template('registrations/new')
          response.should have_selector('div.flash.alert', :content => 'error')
        end.should_not change(User, :count)
      end
    end
    
    describe "success" do
      it "should make a new user" do
        expect { expect {
          visit new_user_registration_path
          fill_in "Invite Code",            :with => " xYzZy "
          fill_in "Full Name",              :with => "Example User"
          fill_in "Email",                  :with => "newuserpurple@example.org"
          fill_in "Primary Phone",          :with => "415 111 2222"
          fill_in "Title",                  :with => 'mytitle'
          fill_in "Location",               :with => 'mylocation'
          fill_in "A brief introduction",   :with => 'Some jellybeans.'
          fill_in "Time Zone",              :with => "Pacific Time (US & Canada)"
          fill_in "Password",               :with => "a"*10
          fill_in "Password Confirmation",  :with => "a"*10
          click_button
          response.should have_selector('div.flash.notice', :content => 'You have signed up successfully')
          response.should render_template('sessions/new')
        }.should change(User, :count).by(1)}.should change(Phone, :count).by(1)
        user = User.find_by_email('newuserpurple@example.org')
        user.name.should == "Example User"
        user.phonetic_name.should == "Example User"
        user.email.should == "newuserpurple@example.org"
        user.primary_phone.number.should == '+14151112222'
        user.title.should == 'mytitle'
        user.location.should == 'mylocation'
        user.about.should == 'Some jellybeans.'
        user.time_zone.should == 'Pacific Time (US & Canada)'
        user.hide_email.should be_false
        user.use_ifmachine.should be_false
        user.handle.should == 'newuserpurple'
        user.multi_phones.should be_false
      end

      it "should handle an invited user" do
        user1 = Factory(:user)
        pool = Factory(:pool, :hide_optional_fields => 'true')
        event1 = Factory(:event, :pool_id => pool.id)
        event2 = Factory(:event, :pool_id => pool.id)
        event3 = Factory(:event, :pool_id => pool.id, :pool_event => true, :auto_subscribe => true)
        event1.time = '7:00am'
        event1.days = [3,5,6]
        event1.save
        event2.time = '5:00pm'
        event2.save
        event3.time = '9:00am'
        event3.days = [2,5,6]
        event3.save
        invite_code = 'random_invite_code'

        invite_email = 'invite_example@example.org'
        invite = MemberInvite.create(
          :sender_id => user1.id,
          :pool_id => pool.id,
          :email => invite_email,
          :invite_code => invite_code,
        )
        expect { expect {
          visit new_user_registration_path(:invite_code => invite_code)
          fill_in "Full Name",              :with => "Example User"
          fill_in "Primary Phone",          :with => "415 111 2222"
          fill_in "Time Zone",              :with => "Pacific Time (US & Canada)"
          fill_in "Password",               :with => "a"*10
          fill_in "Password Confirmation",  :with => "a"*10
          click_button
          response.should have_selector('div.flash.notice', :content => 'You have signed up successfully')
          response.should render_template('pages/my_profile')
        }.should change(User, :count).by(1)}.should change(Phone, :count).by(1)
        user = User.find_by_email(invite_email)
        user.name.should == "Example User"
        user.phonetic_name.should == "Example User"
        user.email.should == invite_email
        user.primary_phone.number.should == '+14151112222'
        user.time_zone.should == 'Pacific Time (US & Canada)'
        user.hide_email.should be_false
        user.use_ifmachine.should be_false
        user.handle.should == 'inviteexample'
        user.multi_phones.should be_false
        pool.reload
        user.reload
        user.pools.map(&:id).should == [pool.id]
        user.events.count.should == 1
        event = user.events.first
        event.time.should == '9:00am'
        event.days.should == [2,5,6]
      end

      it "generic invite to send to a large group" do
        user1 = Factory(:user)
        pool = Factory(:pool, :hide_optional_fields => 'true')
        event1 = Factory(:event, :pool_id => pool.id)
        event2 = Factory(:event, :pool_id => pool.id)
        event3 = Factory(:event, :pool_id => pool.id, :pool_event => true, :auto_subscribe => true)
        event4 = Factory(:event, :pool_id => pool.id, :pool_event => true, :auto_subscribe => true)
        event1.time = '3:15pm'
        event1.days = [3,5,6]
        event1.save
        event2.time = '5:00pm'
        event2.save
        event3.time = '9:00am'
        event3.days = [2,5,6]
        event3.save
        event4.time = '9:15am'
        event4.days = [1,3,5]
        event4.save
        invite_code = 'generic_invite_code'
        invite = MemberInvite.create(
          :sender_id => user1.id,
          :pool_id => pool.id,
          :invite_code => invite_code,
        )
        expect { expect {
          visit new_user_registration_path(:invite_code => invite_code)
          fill_in "Full Name",              :with => "Example Generic User"
          fill_in "Primary Phone",          :with => "415 111 2223"
          fill_in "Email",                  :with => "generic_invite@example.com"
          fill_in "Time Zone",              :with => "Mountain Time (US & Canada)"
          fill_in "Password",               :with => "a"*10
          fill_in "Password Confirmation",  :with => "a"*10
          click_button
          response.should have_selector('div.flash.notice', :content => 'You have signed up successfully')
          response.should render_template('pages/my_profile')
        }.should change(User, :count).by(1)}.should change(Phone, :count).by(1)
        user = User.find_by_email('generic_invite@example.com')
        user.name.should == "Example Generic User"
        user.primary_phone.number.should == '+14151112223'
        user.time_zone.should == 'Mountain Time (US & Canada)'
        user.hide_email.should be_false
        user.use_ifmachine.should be_false
        user.handle.should == 'genericinvite'
        user.multi_phones.should be_false
        pool.reload
        user.reload
        user.pools.map(&:id).should == [pool.id]
        user.events.count.should == 2
        event = user.events.select{ |e| e.time == '10:00am'}.first
        event.time.should == '10:00am'
        event.days.should == [2,5,6]
        event.name.should == "Example's 10:00am Call"
        event = user.events.select{ |e| e.time == '10:15am'}.first
        event.time.should == '10:15am'
        event.days.should == [1,3,5]
        event.name.should == "Example's 10:15am Call"
        event.send_sms_reminder.should be_true
      end
    end
  end
  
  describe "signin" do
  
    describe "failure" do
      it "should not sign a user in" do
        visit new_user_session_path
        fill_in "Email",      :with => ""
        fill_in "Password",   :with => ""
        click_button
        response.should have_selector('div.flash.alert', :content => "Invalid email or password.")
        response.should render_template('sessions/new')
      end
    end    
  
    describe "success" do
      it "should sign a user in and out" do
        user = Factory(:user, :email => 'thisisnewrandomfoo@example.net', :confirmed_at => Time.now)
        visit new_user_session_path
        fill_in "Email",      :with => user.email
        fill_in "Password",   :with => user.password
        click_button
        controller.user_signed_in?.should be_true
        click_link "Logout"
        controller.user_signed_in?.should be_false          
      end        
    end  
  end

  describe "edit" do
    describe "failure" do
      it "should not edit user" do
        user = Factory(:user, :email => 'thisis2newrandomfoo@example.net', :password => 'foobarbaz', :confirmed_at => Time.now)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        visit new_user_session_path
        fill_in "Email",      :with => user.email
        fill_in "Password",   :with => user.password
        click_button
        controller.user_signed_in?.should be_true

        visit edit_user_registration_path
        fill_in "Email",        :with => "newemail@example.com"
        click_button
        response.should have_selector('div.flash.alert', :content => 'error')
        response.should render_template('sessions/new')
        user.reload
        user.email.should == 'thisis2newrandomfoo@example.net'
      end
    end    
  
    describe "success" do
      it "should edit user attributes" do
        user = Factory(:user, :email => 'thisis3newrandomfoo@example.net', :password => 'foobarbaz', :confirmed_at => Time.now)
        phone1 = Factory(:phone, :user_id => user.id, :primary => true)
        phone2 = Factory(:phone, :user_id => user.id, :string => '777 888 9999')
        user.use_ifmachine.should be_false
        user.hide_email.should be_false
        user.multi_phones.should be_false
        user.time_zone.should == 'Pacific Time (US & Canada)'
        visit new_user_session_path
        fill_in "Email",      :with => user.email
        fill_in "Password",   :with => user.password
        click_button
        controller.user_signed_in?.should be_true

        visit edit_user_registration_path
        fill_in "Full Name",          :with => 'Bubby Bob'
        fill_in "Phonetic Name",      :with => 'Buubby Bab'
        fill_in "Email",              :with => "new@example.com"
        fill_in "Phone Number",       :with => '415 222 5555'
        fill_in "Introductory text",  :with => 'I like jellybeans.'
        fill_in "Handle",             :with => 'newhandle'
        fill_in "Title",              :with => 'newtitle'
        fill_in "Location",           :with => 'newlocation'
        fill_in "Time Zone",          :with => 'Mountain Time (US & Canada)'
        check   "Hide my email address from other members"
        check   "Go directly to conference"
        check   "Call all my phones for the calls"
        fill_in "Current Password",   :with => user.password
        click_button

        response.should_not have_selector('div.flash.alert', :content => 'error')
        user.reload
        user.name.should == 'Bubby Bob'
        user.phonetic_name.should == 'Buubby Bab'
        user.email.should == "new@example.com"
        user.primary_phone.number.should == '+14152225555'
        user.about.should == 'I like jellybeans.'
        user.handle.should == 'newhandle'
        user.title.should == 'newtitle'
        user.location.should == 'newlocation'
        user.time_zone.should == 'Mountain Time (US & Canada)'
        user.hide_email.should be_true
        user.multi_phones.should be_true
        user.use_ifmachine.should be_true
        phone1.reload
        phone2.reload
        phone1.number.should == '+14152225555'
        phone2.number.should == '+17778889999'
      end        
    end  
  end
end
