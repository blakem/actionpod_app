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
    event1 = Factory(:event, :user_id => user.id)
    event2 = Factory(:event, :user_id => user.id)
    event3 = Factory(:event)
    user.events.should include(event1, event2)
    user.events.should_not include(event3)
  end

  it "regular users belong to one pool.  Admin users belong to all pools" do
    pool1 = Pool.default_pool
    pool2 = Factory(:pool)
    user = Factory(:user)
    user.memberships.should include(pool1)
    user.memberships.should_not include(pool2)

    user.toggle!(:admin)
    user.memberships.should include(pool1, pool2)    
  end

  it "can have zero or more pools" do
    user = Factory(:user)
    user.pools.count.should == 0
    pool1 = Factory(:pool, :user_id => user.id)
    pool2 = Factory(:pool, :user_id => user.id)
    pool3 = Factory(:pool)
    user.pools.should include(pool1, pool2)
    user.pools.should_not include(pool3)
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
  end
  
  it "has many conferences" do
    conference1 = Conference.create
    conference2 = Conference.create
    user = Factory(:user)
    user.conferences = [conference1, conference2]
    user.conferences.should include(conference1, conference2)
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

      event1 = Factory(:event, :user_id => user.id)
      event1.days = []
      event1.save
      user.reload
      user.next_call_time.should be_nil
      user.next_call_time_string.should == ''

      event1.days = [0,1,2,3,4,5,6]
      event1.time = '1:00pm'
      event1.save
      user.reload
      user.next_call_time.strftime("%A at %I:%M%P").sub(/ 0/,' ').humanize.should == "Tuesday at 1:00pm"
      user.next_call_time_string.should == "Tomorrow at 1:00pm"

      event2 = Factory(:event, :user_id => user.id)
      event2.days = [0,1,2,3,4,5,6]
      event2.time = '4:00pm'
      event2.save
      user.reload
      user.next_call_time.strftime("%A at %I:%M%P").sub(/ 0/,' ').humanize.should == "Monday at 4:00pm"
      user.next_call_time_string.should == "Today at 4:00pm"

      event1.days = [5,6]
      event1.save
      event2.days = [5,6]
      event2.save
      user.reload
      user.next_call_time.strftime("%A at %I:%M%P").sub(/ 0/,' ').humanize.should == "Friday at 1:00pm"
      user.next_call_time_string.should == "Friday at 1:00pm"
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
      user.profile_path.should == '/u/' + user.handle
      user.remote_profile_path.should == 'http://www.15minutecalls.com/u/' + user.handle
    end
  end
end
