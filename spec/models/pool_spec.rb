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

  it "has a default timelimit of 15" do
    user = Factory(:user)
    pool1 = Pool.create(:admin_id => user.id)
    pool1.timelimit.should == 15

    pool2 = Pool.create(:admin_id => user.id, :timelimit => 30)
    pool2.timelimit.should == 30
  end
  
  it "computes whether we are currently in the call window" do
    pool = Factory(:pool, :timelimit => 12)
    now = Time.now.utc
    pool.after_call_window(now).should == false
    pool.after_call_window(now - 10.minutes).should == false
    pool.after_call_window(now - 13.minutes).should == true
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
