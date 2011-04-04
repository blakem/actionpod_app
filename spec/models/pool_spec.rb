require 'spec_helper'

describe Pool do
  it "has a name" do
    pool = Factory(:pool, :name => 'Some Name')
    pool.name.should == 'Some Name'
  end

  it "belongs to a user" do
    user = Factory(:user)
    pool = Factory(:pool, :user_id => user.id)
    pool.user.should == user
  end

  it "has a default timelimit of 15" do
    user = Factory(:user)
    pool1 = Pool.create(:user_id => user.id)
    pool1.timelimit.should == 15

    pool2 = Pool.create(:user_id => user.id, :timelimit => 30)
    pool2.timelimit.should == 30
  end
end
