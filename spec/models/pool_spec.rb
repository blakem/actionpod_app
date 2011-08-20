require 'spec_helper'

describe Pool do
  it "has a name" do
    pool = Factory(:pool, :name => 'Some Name')
    pool.name.should == 'Some Name'
  end

  it "requires a name" do
    pool = Factory(:pool)
    pool.name = ''
    pool.valid?
    pool.errors[:name].should include("can't be blank")
  end

  it "requires an integer timelimit" do
    pool = Factory(:pool)
    pool.timelimit = 'foo'
    pool.valid?
    pool.errors[:timelimit].should include("is not a number")
    pool.timelimit = ''
    pool.valid?
    pool.errors[:timelimit].should include("is not a number")
    pool.timelimit = 1
    pool.valid?
    pool.errors[:timelimit].should include("must be greater than 1")
    pool.timelimit = 31
    pool.valid?
    pool.errors[:timelimit].should include("must be less than or equal to 30")
  end

  it "belongs to a user" do
    user = Factory(:user)
    pool = Factory(:pool, :admin_id => user.id)
    pool.user.should == user
  end

  it "has many events" do
    pool = Factory(:pool)
    event1 = Factory(:event, :pool_id => pool.id)
    event2 = Factory(:event, :pool_id => pool.id)
    event3 = Factory(:event)
    pool.events.should include(event1, event2)
    pool.events.should_not include(event3)
    pool.events.count.should == 2
  end

  it "has normal_events that excludes pool_events" do
    pool = Factory(:pool)
    event1 = Factory(:event, :pool_id => pool.id, :pool_event => true)
    event2 = Factory(:event, :pool_id => pool.id, :pool_event => false)
    event3 = Factory(:event)
    pool.normal_events.should include(event2)
    pool.normal_events.should_not include(event1)
    pool.normal_events.should_not include(event3)
    pool.normal_events.count.should == 1
  end

  it "has pool_events that excludes normal_events" do
    pool = Factory(:pool)
    event1 = Factory(:event, :pool_id => pool.id, :pool_event => true)
    event2 = Factory(:event, :pool_id => pool.id, :pool_event => false)
    event3 = Factory(:event)
    pool.pool_events.should include(event1)
    pool.pool_events.should_not include(event2)
    pool.pool_events.should_not include(event3)
    pool.pool_events.count.should == 1
  end

  it "has default values" do
    user = Factory(:user)
    pool1 = Pool.create(:admin_id => user.id)
    pool1.timelimit.should == 15
    pool1.public_group.should == false
    pool1.allow_others_to_invite.should == false

    pool2 = Pool.create(:admin_id => user.id, :timelimit => 30, :public_group => true, :allow_others_to_invite => true)
    pool2.timelimit.should == 30
    pool2.public_group.should == true
    pool2.allow_others_to_invite.should == true
  end
  
  it "computes whether we are currently in the call window" do
    pool = Factory(:pool, :timelimit => 12)
    now = Time.now.utc
    pool.after_call_window(now).should == false
    pool.after_call_window(now - 10.minutes).should == false
    pool.after_call_window(now - 13.minutes).should == true
  end
  
  it "has participating_users" do
    pool = Factory(:pool)
    user1 = Factory(:user)
    user2 = Factory(:user)
    user3 = Factory(:user)
    user4 = Factory(:user)
    event = Factory(:event, :pool_id => pool.id, :user_id => user1.id)
    pool.users = [user1, user2, user3, user4]
    conference1 = Conference.create!(:pool_id => pool.id)
    conference2 = Conference.create!(:pool_id => pool.id)
    conference1.users = [user1, user2]
    conference2.users = [user3]
    pool.participating_users.should include(user1, user2)
    pool.participating_users.count.should == 2
    pool.participating_users(2).count.should == 2
    pool.participating_users(1).count.should == 3
    pool.nonparticipating_users.should include(user3, user4)
    pool.nonparticipating_users.count.should == 2
    pool.nonparticipating_users(2).count.should == 2
    pool.nonparticipating_users(1).count.should == 1
    pool.users_with_events.should == [user1]
    pool.users_without_events.should include(user2, user3, user4)
    pool.users_without_events.count.should == 3
  end
  
  it "can have zero or more users" do
    pool = Factory(:pool)
    pool.users.should be_empty
    user1 = Factory(:user)
    user2 = Factory(:user)
    user3 = Factory(:user)
    pool.users = [user1, user2]
    pool.users.should include(user1, user2)
    pool.users.should_not include(user3)
  end
  
  it "has name_plus_group" do
    pool = Factory(:pool, :name => 'Foo')
    pool.name_plus_group.should == 'Foo group'

    pool = Factory(:pool, :name => 'Foo Group')
    pool.name_plus_group.should == 'Foo Group'

    pool = Factory(:pool, :name => 'Foo group')
    pool.name_plus_group.should == 'Foo group'

    pool = Factory(:pool, :name => 'Foo GROUp')
    pool.name_plus_group.should == 'Foo GROUp'

    pool = Factory(:pool, :name => 'Foogroup')
    pool.name_plus_group.should == 'Foogroup group'

    pool = Factory(:pool, :name => 'Foogroup yo')
    pool.name_plus_group.should == 'Foogroup yo group'

    pool = Factory(:pool, :name => '    Foo GROUp     ')
    pool.name_plus_group.should == 'Foo GROUp'

    pool = Factory(:pool, :name => '   Foo   ')
    pool.name_plus_group.should == 'Foo group'
  end
  
  it "has available times" do
    pool = Factory(:pool)
    pool.available_time_mode = '60'
    pool.available_times.should ==
      (1..11).to_a.map { |h| "#{h}:00am"} + ["12:00pm"] + 
      (1..11).to_a.map { |h| "#{h}:00pm" } + ["12:00am"]
    pool.available_time_mode = '30'
    pool.available_times.should ==
      (["12:30am"] + (1..11).to_a.map { |h| ["#{h}:00am", "#{h}:30am"]} + ["12:00pm", "12:30pm"] + 
      (1..11).to_a.map { |h| ["#{h}:00pm", "#{h}:30pm"] } + ["12:00am"]).flatten
    pool.available_time_mode = '15'
    pool.available_times.should ==
      (["12:15am", "12:30am", "12:45am"] + 
       (1..11).to_a.map { |h| ["#{h}:00am", "#{h}:15am", "#{h}:30am", "#{h}:45am"]} + 
       ["12:00pm", "12:15pm", "12:30pm", "12:45pm"] + 
       (1..11).to_a.map { |h| ["#{h}:00pm", "#{h}:15pm", "#{h}:30pm", "#{h}:45pm"] } + 
       ["12:00am"]).flatten
    pool.available_time_mode = '20'
    pool.available_times.should ==
      (["12:20am", "12:40am"] + 
       (1..11).to_a.map { |h| ["#{h}:00am", "#{h}:20am", "#{h}:40am"]} + 
       ["12:00pm", "12:20pm", "12:40pm"] + 
       (1..11).to_a.map { |h| ["#{h}:00pm", "#{h}:20pm", "#{h}:40pm"] } + 
       ["12:00am"]).flatten
  end
  
  it "deletes invites when the pool is deleted" do
    pool = Factory(:pool)
    user = Factory(:user)
    invite_id = MemberInvite.create!(
      :sender_id => user.id,
      :pool_id => pool.id,
      :invite_code => 'abcdef'
    ).id
    expect {
      pool.destroy
    }.to change(MemberInvite, :count).by(-1)
    MemberInvite.find_by_id(invite_id).should be_nil
  end
  
  it "has a merge_type_string" do
    pool = Factory(:pool, :merge_type => 1)
    pool.merge_type_string.should == 'Consistently'
    pool.merge_type = 2
    pool.merge_type_string.should == 'Randomly'
    pool.merge_type = 3
    pool.merge_type_string.should == 'One Big Group'    
  end
  
  describe "add_member" do
    it "adds itself to a users pools" do
      pool = Factory(:pool)
      pool2 = Factory(:pool)
      user = Factory(:user)
      pool.add_member(user)
      user.pools.should include(pool)
      user.pools.should_not include(pool2)
      pool2.add_member(user)
      user.pools.should include(pool)
      user.pools.should include(pool2)
      user.pools.count.should == 3
      pool2.add_member(user)
      user.pools.count.should == 3
    end
  end
  
  describe "can_invite?" do
    it "handles invites properly" do
      user1 = Factory(:user)
      user2 = Factory(:user)
      public_group = Factory(:pool, :public_group => true )
      private_group = Factory(:pool, :public_group => false)
      admin_public_group = Factory(:pool, :public_group => true, :admin_id => user1.id)
      admin_private_group = Factory(:pool, :public_group => false, :admin_id => user1.id)
      public_group.users = [user1, user2]
      private_group.users = [user1, user2]
      admin_public_group.users = [user1, user2]
      admin_private_group.users = [user1, user2]

      public_group.can_invite?(user1).should be_true
      private_group.can_invite?(user1).should be_false
      admin_public_group.can_invite?(user1).should be_true
      admin_private_group.can_invite?(user1).should be_true

      public_group.can_invite?(user2).should be_true
      private_group.can_invite?(user2).should be_false
      admin_public_group.can_invite?(user2).should be_true
      admin_private_group.can_invite?(user2).should be_false

      private_group.allow_others_to_invite = true
      public_group.allow_others_to_invite = true
      admin_private_group.allow_others_to_invite = true
      admin_public_group.allow_others_to_invite = true

      public_group.can_invite?(user1).should be_true
      private_group.can_invite?(user1).should be_true
      admin_public_group.can_invite?(user1).should be_true
      admin_private_group.can_invite?(user1).should be_true

      public_group.can_invite?(user2).should be_true
      private_group.can_invite?(user2).should be_true
      admin_public_group.can_invite?(user2).should be_true
      admin_private_group.can_invite?(user2).should be_true

      public_group.users = []
      private_group.users = []
      admin_public_group.users = []
      admin_private_group.users = []

      public_group.can_invite?(user1).should be_false
      private_group.can_invite?(user1).should be_false
      admin_public_group.can_invite?(user1).should be_true
      admin_private_group.can_invite?(user1).should be_true

      public_group.can_invite?(user2).should be_false
      private_group.can_invite?(user2).should be_false
      admin_public_group.can_invite?(user2).should be_false
      admin_private_group.can_invite?(user2).should be_false
    end
  end
  
  describe "timeslots" do
    it "knows its own timeslots" do
      pool = Factory(:pool)
      user1 = Factory(:user, :time_zone => 'Pacific Time (US & Canada)')
      user2 = Factory(:user, :time_zone => 'Mountain Time (US & Canada)')
      user1.pools = [pool]
      user2.pools = [pool]

      pool.timeslots(user1).should == []

      event1 = Factory(:event, :user_id => user1.id, :pool_id => pool.id)
      event1.time = '8:04am'
      event1.days = [3]
      event1.save
      
      pool.timeslots(user1).should == [{
        :time =>  "8:04am",
        :string =>  "8:04am on Wednesdays",
        :minute => 8*60 + 4,
        :days => [3],
        :event_ids => [event1.id],
        :pool_id => pool.id,
      }]

      event1.days = [2,3,4]
      event1.save      
      pool.timeslots(user1).should == [{
        :time =>  "8:04am",
        :string =>  "8:04am on selected Weekdays",
        :minute => 8*60 + 4,
        :days => [2,3,4],
        :event_ids => [event1.id],
        :pool_id => pool.id,
      }]

      event2 = Factory(:event, :user_id => user2.id, :pool_id => pool.id)
      event2.time = '8:04am'
      event2.days = [1,4,5]
      event2.save

      pool.timeslots(user1).should == [{
        :time =>  "7:04am",
        :string =>  "7:04am on selected Weekdays",
        :minute => 7*60 + 4,
        :days => [1,4,5],
        :event_ids => [event2.id],
        :pool_id => pool.id,
      }, {
        :time =>  "8:04am",
        :string =>  "8:04am on selected Weekdays",
        :minute => 8*60 + 4,
        :days => [2,3,4],
        :event_ids => [event1.id],
        :pool_id => pool.id,
      }]

      pool.timeslots(user2).should == [{
        :time =>  "8:04am",
        :string =>  "8:04am on selected Weekdays",
        :minute => 8*60 + 4,
        :days => [1,4,5],
        :event_ids => [event2.id],
        :pool_id => pool.id,
      }, {
        :time =>  "9:04am",
        :string =>  "9:04am on selected Weekdays",
        :minute => 9*60 + 4,
        :days => [2,3,4],
        :event_ids => [event1.id],
        :pool_id => pool.id,
      }]

      event3 = Factory(:event, :user_id => user2.id, :pool_id => pool.id)
      event3.time = '9:04am'
      event3.days = [1,4,5]
      event3.save

      pool.timeslots(user1).should == [{
        :time =>  "7:04am",
        :string =>  "7:04am on selected Weekdays",
        :minute => 7*60 + 4,
        :days => [1,4,5],
        :event_ids => [event2.id],
        :pool_id => pool.id,
      }, {
        :time =>  "8:04am",
        :string =>  "8:04am on selected Weekdays",
        :minute => 8*60 + 4,
        :days => [1,2,3,4,5],
        :event_ids => [event1.id, event3.id],
        :pool_id => pool.id,
      }]

      pool.timeslots(user2).should == [{
        :time =>  "8:04am",
        :string =>  "8:04am on selected Weekdays",
        :minute => 8*60 + 4,
        :days => [1,4,5],
        :event_ids => [event2.id],
        :pool_id => pool.id,
      }, {
        :time =>  "9:04am",
        :string =>  "9:04am on selected Weekdays",
        :minute => 9*60 + 4,
        :days => [1,2,3,4,5],
        :event_ids => [event1.id, event3.id],
        :pool_id => pool.id,
      }]
      
      # honor the skip_mine flag
      pool3 = Factory(:pool)
      event4 = Factory(:event, :user_id => user1.id, :pool_id => pool3.id)
      event4.time = '7:04am'
      event4.save
      
      pool.timeslots(user1, true).should == [{
        :time =>  "7:04am",
        :string =>  "7:04am on selected Weekdays",
        :minute => 7*60 + 4,
        :days => [1,4,5],
        :event_ids => [event2.id],
        :pool_id => pool.id,
      }]

      # don't choke on events with no days
      event3.days = []
      event3.save
      pool.timeslots(user2).should == [{
        :time =>  "8:04am",
        :string =>  "8:04am on selected Weekdays",
        :minute => 8*60 + 4,
        :days => [1,4,5],
        :event_ids => [event2.id],
        :pool_id => pool.id,
      }, {
        :time =>  "9:04am",
        :string =>  "9:04am on selected Weekdays",
        :minute => 9*60 + 4,
        :days => [2,3,4],
        :event_ids => [event1.id],
        :pool_id => pool.id,
      }]

      # don't look at events that aren't in our pool      
      pool2 = Factory(:pool)
      event1.pool_id = pool2.id
      event1.save
      pool.timeslots(user2).should == [{
        :time =>  "8:04am",
        :string =>  "8:04am on selected Weekdays",
        :minute => 8*60 + 4,
        :days => [1,4,5],
        :event_ids => [event2.id],
        :pool_id => pool.id,
      }]
    end
  end
end
