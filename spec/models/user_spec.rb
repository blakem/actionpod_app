require 'spec_helper'

describe User do
  it "Should have a secret invite code" do
    User.secret_invite_code.should_not be_empty
  end

  it "has many phones and a primary_phone" do
    user = Factory(:user)
    phone1 = Factory(:phone, :user_id => user.id)
    phone2 = Factory(:phone, :user_id => user.id, :primary => true)
    user.phones.should include(phone1, phone2)
    user.primary_phone.should == phone2
    user.primary_phone.number.should == phone2.number
    user.primary_phone.string.should == phone2.string

    # Should delete phones on user destroy
    phone1_id = phone1.id
    phone2_id = phone2.id
    user.destroy
    Phone.find_by_id(phone1_id).should be_nil
    Phone.find_by_id(phone2_id).should be_nil    
  end

  it "can confirm" do
    user = Factory(:user)
    user.confirmed_at = nil
    user.confirmation_token = 'foo'
    user.save
    user.confirmed_at.should be_nil
    user.confirmation_token.should_not be_nil

    user.confirm!

    user.reload
    user.confirmed_at.should_not be_nil
    user.confirmation_token.should be_nil
  end

  it "has many plans and a current_plan" do
    user = Factory(:user)
    plan1 = Factory(:plan, :user_id => user.id)
    plan2 = Factory(:plan, :user_id => user.id)
    user.plans.should include(plan1, plan2)
    user.current_plan.should == plan2

    # Should delete phones on user destroy
    plan1_id = plan1.id
    plan2_id = plan2.id
    user.destroy
    Plan.find_by_id(plan1_id).should be_nil
    Plan.find_by_id(plan2_id).should be_nil    
  end
  
  it "has with_phone" do
    user = Factory(:user)
    user.phones.should be_empty
    user = user.with_phone
    user.phones[0].kind_of?(Phone)
    user.phones[0].user_id.should == user.id
  end

  it "requires a name" do
    user = User.new
    user.valid?
    user.errors[:name].should include("can't be blank")
  end
  
  it "should have an admin attribute" do
    user = Factory(:user)
    user.admin?.should be_false
    user.admin = true
    user.admin?.should be_true
  end

  it "should have a soft delete" do
    user = Factory(:user)
    user.deleted_at.should     be_nil
    user.soft_delete
    user.deleted_at.should_not be_nil
  end
  
  it "should have many events" do
    user = Factory(:user)
    event1 = Factory(:event, :user_id => user.id, :pool_event => false)
    event2 = Factory(:event, :user_id => user.id, :pool_event => true)
    event3 = Factory(:event)
    user.events.should include(event1, event2)
    user.events.should_not include(event3)
    
    user.normal_events.should include(event1)
    user.normal_events.should_not include(event2)
    user.normal_events.should_not include(event3)
  end

  it "can belong to zero or many pools" do
    user = Factory(:user)
    user.pools.count.should == 1 # Default pool
    pool1 = Factory(:pool)
    pool2 = Factory(:pool)
    pool3 = Factory(:pool)
    user.pools.should include(Pool.default_pool)
    user.pools = [pool1, pool2]
    user.pools.should include(pool1, pool2)
    user.pools.should_not include(pool3)
    user.pools.should_not include(Pool.default_pool)
  end
  
  it "belongs to the default pool at creation" do
    user = Factory(:user)
    user.pools.should == [Pool.default_pool]
  end

  it "can be the admin for zero or many pools" do
    user = Factory(:user)
    user.admin_pools.count.should == 0
    pool1 = Factory(:pool, :admin_id => user.id)
    pool2 = Factory(:pool, :admin_id => user.id)
    pool3 = Factory(:pool)
    user.admin_pools.should include(pool1, pool2)
    user.admin_pools.should_not include(pool3)
  end
  
  it "should have a time_zone that defaults to 'Pacific Time (US & Canada)'" do
    user1 = User.create()
    user1.time_zone.should == 'Pacific Time (US & Canada)'
    user2 = User.create(:time_zone => 'Mountain Time (US & Canada)')
    user2.time_zone.should == 'Mountain Time (US & Canada)'
  end
  
  it "should have a name" do
    user = Factory(:user, :name => 'Bob Jones')
    user.name.should == 'Bob Jones'
  end

  it "starts with counts of 0" do
    user = Factory(:user)
    user.placed_count == 0
    user.incoming_count == 0
    user.answered_count == 0
    user.called_count == 0
    user.missed_in_a_row == 0
    user.made_in_a_row == 0
  end

  it "should have a title" do
    user = Factory(:user, :title => 'Software Developer')
    user.title.should == 'Software Developer'
  end

  it "updates it's events timezones when the user.time_zone is changes" do
    pacific_time_zone = 'Pacific Time (US & Canada)'
    mountain_time_zone = 'Mountain Time (US & Canada)'
    user = Factory(:user, :time_zone => pacific_time_zone, :name => "Robb Jones")
    event = Factory(:event, :user_id => user.id, :pool_id => Factory(:pool).id, :name => "Robb's 8:00am Call")
    event.skip_dates = Time.now.tomorrow.strftime("%m/%d/%Y")
    event.schedule
    event.save
    event.reload
    event.time.should == '8:00am'
    event.name.should == "Robb's 8:00am Call"

    event.schedule.start_time.time_zone.to_s.should == "(GMT-08:00) " + pacific_time_zone
    event.schedule.exdates[0].time_zone.to_s.should == "(GMT-08:00) " + pacific_time_zone
    event.schedule.exdates[0].hour.should == 8
    user.time_zone = mountain_time_zone
    user.save
    event.reload
    event.schedule.start_time.time_zone.to_s.should == "(GMT-07:00) " + mountain_time_zone
    event.schedule.exdates[0].time_zone.to_s.should == "(GMT-07:00) " + mountain_time_zone
    event.schedule.exdates[0].hour.should == 9
    event.time.should == '9:00am'
    event.name.should == "Robb's 9:00am Call"

    event.schedule.start_time.time_zone.to_s.should == "(GMT-07:00) " + mountain_time_zone
    event.schedule.exdates[0].time_zone.to_s.should == "(GMT-07:00) " + mountain_time_zone
    user.time_zone = pacific_time_zone
    user.save
    event.reload
    event.schedule.start_time.time_zone.to_s.should == "(GMT-08:00) " + pacific_time_zone
    event.schedule.exdates[0].time_zone.to_s.should == "(GMT-08:00) " + pacific_time_zone
    event.schedule.exdates[0].hour.should == 8
    event.time.should == '8:00am'
    event.name.should == "Robb's 8:00am Call"
  end
  
  it "has a first_name" do
    user = Factory(:user, :name => "Bob Jones", :email => 'abc@123.com')
    user.first_name.should == 'Bob'
    user.name = 'Sally'
    user.first_name.should == 'Sally'
    user.name = ' sally smith'
    user.first_name.should == 'Sally'
    user.name = nil
    user.first_name.should == 'abc'
    user.name = ''
    user.first_name.should == 'abc'
    user.email.should == 'abc@123.com'
    user.name = 'H. Paul Hammann'
    user.first_name.should == 'Paul'
    user.name = 'Dr. paul Hammann'
    user.first_name.should == 'Paul'
    user.name = 'dr.'
    user.first_name.should == 'Dr.'
  end
  
  it "has many conferences" do
    conference1 = Conference.create
    conference2 = Conference.create
    user = Factory(:user)
    user.conferences = [conference1, conference2]
    user.conferences.should include(conference1, conference2)
  end
  
  it "has a last_successful_call_time" do
    user = Factory(:user)
    user.last_successful_call_time.should == nil
    conference1 = Conference.create(:status => 'only_one_answered')
    conference2 = Conference.create(:status => 'only_one_scheduled')
    conference3 = Conference.create(:status => 'in_progress')
    conference4 = Conference.create(:status => 'completed')
    conference5 = Conference.create(:status => 'completed')
    user.conferences = [conference1, conference2, conference3, conference4, conference5]
    user.last_successful_call_time.should == conference4.created_at
  end

  it "has a member_status" do
    user = Factory(:user)
    user.member_status.should == 'Has never been called'
    user.made_in_a_row = 3
    user.missed_in_a_row = 0
    user.member_status.should == 'Made 3 calls in a row'
    user.missed_in_a_row = 3
    user.made_in_a_row = 0
    user.member_status.should == 'Missed 3 calls in a row'
    user.made_in_a_row = 1
    user.missed_in_a_row = 0
    user.member_status.should == 'Made last call'
    user.missed_in_a_row = 1
    user.made_in_a_row = 0
    user.member_status.should == 'Missed last call'
    user.confirmed_at = nil
    user.member_status.should == "Hasn't confirmed email"
  end
  
  describe "handle" do
    it "can be generated from the email address" do
      user1 = Factory(:user, :email => 'foobar@example.com')
      user1.handle.should == 'foobar'
      user2 = Factory(:user, :email => 'foobar@example.net')
      user2.handle.should == 'foobar2'
    end

    it "doesn't get overwritten when they change their email" do
      user1 = Factory(:user, :email => 'foo-Bar@example.com')
      user1.handle.should == 'foobar'
      user1.email = 'bob@example.com'
      user1.save
      user1.reload
      user1.handle.should == 'foobar'
      user2 = Factory(:user, :email => 'foo-Bar@example.net')
      user2.handle.should == 'foobar2'      
      user2.email = 'sally@example.com'
      user2.save
      user2.reload
      user2.handle.should == 'foobar2'
      user2.handle = ''
      user2.save
      user2.reload
      user2.handle.should == 'foobar2'
    end
  end
  
  describe "next_call_time" do
    it "should return the next call time of your events" do
      now = Time.now.beginning_of_week + 7.days + 13.hours
      Time.stub(:now).and_return(now)
      user = Factory(:user)
      user.next_call_time.should be_nil
      user.next_call_time_string.should == ''
      user.event_with_next_call_time.should be_nil

      event1 = Factory(:event, :user_id => user.id)
      event1.days = []
      event1.save
      user.reload
      user.next_call_time.should be_nil
      user.next_call_time_string.should == ''
      user.event_with_next_call_time.should be_nil

      event1.pool_event = true
      event1.days = [0,1,2,3,4,5,6]
      event1.time = '1:00pm'
      event1.save
      user.reload
      user.next_call_time.should be_nil
      user.next_call_time_string.should == ''
      user.event_with_next_call_time.should be_nil

      event1.pool_event = false
      event1.save
      user.reload
      user.next_call_time.strftime("%A at %I:%M%P").sub(/ 0/,' ').humanize.should == "Tuesday at 1:00pm"
      user.next_call_time_string.should == "Tomorrow at 1:00pm"
      user.event_with_next_call_time.should == event1

      event2 = Factory(:event, :user_id => user.id)
      event2.days = [0,1,2,3,4,5,6]
      event2.time = '4:00pm'
      event2.save
      user.reload
      user.next_call_time.strftime("%A at %I:%M%P").sub(/ 0/,' ').humanize.should == "Monday at 4:00pm"
      user.next_call_time_string.should == "Today at 4:00pm"
      user.event_with_next_call_time.should == event2

      event1.days = [5,6]
      event1.save
      event2.days = [5,6]
      event2.save
      user.reload
      user.next_call_time.strftime("%A at %I:%M%P").sub(/ 0/,' ').humanize.should == "Friday at 1:00pm"
      user.next_call_time_string.should == "Friday at 1:00pm"
      user.event_with_next_call_time.should == event1

      event1.days = [5,6]
      event1.save
      event2.days = []
      event2.save
      user.reload
      user.next_call_time.strftime("%A at %I:%M%P").sub(/ 0/,' ').humanize.should == "Friday at 1:00pm"
      user.next_call_time_string.should == "Friday at 1:00pm"
      user.event_with_next_call_time.should == event1

      event1.days = []
      event1.save
      event2.days = [5,6]
      event2.save
      user.reload
      user.next_call_time.strftime("%A at %I:%M%P").sub(/ 0/,' ').humanize.should == "Friday at 4:00pm"
      user.next_call_time_string.should == "Friday at 4:00pm"
      user.event_with_next_call_time.should == event2
    end    
  end

  describe "preferences" do
    it "should be able to prefer another user" do
      user = Factory(:user)
      other_user = Factory(:user)
      other_user2 = Factory(:user)
      user.prefer!(other_user)
      user.preferred_members.should include(other_user)
      user.preferred_members.should_not include(other_user2)
      user.avoided_members.should == []
      user.prefers?(other_user).should be_true
      user.avoids?(other_user).should be_false
      
      user.unprefer!(other_user)
      user.reload
      user.preferred_members.should == []
      user.avoided_members.should == []
      user.prefers?(other_user).should be_false
      user.avoids?(other_user).should be_false
    end

    it "should be able to avoid another user" do
      user = Factory(:user)
      other_user = Factory(:user)
      other_user2 = Factory(:user)
      user.avoid!(other_user)
      user.avoided_members.should include(other_user)
      user.avoided_members.should_not include(other_user2)
      user.preferred_members.should == []
      user.avoids?(other_user).should be_true
      user.prefers?(other_user).should be_false
      
      user.unprefer!(other_user)
      user.reload
      user.avoided_members.should == []
      user.preferred_members.should == []
      user.prefers?(other_user).should be_false
      user.avoids?(other_user).should be_false
    end

    it "user cannot prefer or avoid himself" do
      user = Factory(:user)
      user.avoid!(user)
      user.preferences.count.should == 0
      user.avoids?(user).should be_false
      user.prefers?(user).should be_false

      user.prefer!(user)
      user.preferences.count.should == 0
      user.avoids?(user).should be_false
      user.prefers?(user).should be_false
    end

    it "should delete existing preferences for a user when prefer! or avoid! is called" do
      user = Factory(:user)
      other_user = Factory(:user)
      other_user2 = Factory(:user)
      user.avoid!(other_user)
      user.prefer!(other_user)
      user.preferences.count.should == 1

      user.unprefer!(other_user)
      user.reload
      user.prefer!(other_user)
      user.avoid!(other_user)
      user.preferences.count.should == 1
    end
    
    it "should have a profile_path and remote_profile_path" do
      user = Factory(:user)
      user.profile_path.should == '/member/' + user.handle
      user.remote_profile_path.should == 'http://www.15minutecalls.com/member/' + user.handle
    end
  end
  
  describe "timeslots" do
    it "should build timeslots from its groups" do
      user = Factory(:user)
      user2 = Factory(:user, :admin => true)
      pool1 = Factory(:pool)
      pool2 = Factory(:pool)
      user.pools = [pool1, pool2]
      event1 = Factory(:event, :user_id => user.id, :time => '7:00am', :pool_id => pool1.id)
      event2 = Factory(:event, :user_id => user.id, :time => '7:00am', :pool_id => pool2.id)
      event3 = Factory(:event, :user_id => user.id, :time => '8:00am', :pool_id => pool2.id)
      user.timeslots.should == [{
        :time      => "7:00am",
        :string    => "7:00am on selected Weekdays",
        :minute    => 420,
        :days      => [1, 2, 3, 4, 5],
        :event_ids => [event1.id],
        :pool_id   => pool1.id,
      }, {
        :time      => "7:00am",
        :string    => "7:00am on selected Weekdays",
        :minute    => 420,
        :days      => [1, 2, 3, 4, 5],
        :event_ids => [event2.id],
        :pool_id   => pool2.id,
      }, {
        :time      => "8:00am",
        :string    => "8:00am on selected Weekdays",
        :minute    => 480,
        :days      => [1, 2, 3, 4, 5],
        :event_ids => [event3.id],
        :pool_id   => pool2.id,
      }]

      # Admin sees all
      user2.timeslots.should include({
        :time      => "7:00am",
        :string    => "7:00am on selected Weekdays",
        :minute    => 420,
        :days      => [1, 2, 3, 4, 5],
        :event_ids => [event1.id],
        :pool_id   => pool1.id,
      }, {
        :time      => "7:00am",
        :string    => "7:00am on selected Weekdays",
        :minute    => 420,
        :days      => [1, 2, 3, 4, 5],
        :event_ids => [event2.id],
        :pool_id   => pool2.id,
      }, {
        :time      => "8:00am",
        :string    => "8:00am on selected Weekdays",
        :minute    => 480,
        :days      => [1, 2, 3, 4, 5],
        :event_ids => [event3.id],
        :pool_id   => pool2.id,
      })
    end
  end
  
  describe "destroy" do
    it "should delete its events" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id)
      event_id = event.id
      user.destroy
      Event.find_by_id(event_id).should be_nil      
    end
  end
end
