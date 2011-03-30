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
end
