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
  
end
