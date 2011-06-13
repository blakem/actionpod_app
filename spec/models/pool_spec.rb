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
end
