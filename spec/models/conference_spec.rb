require 'spec_helper'

describe Conference do
  it "can save to the database" do
    Conference.create!
  end
  
  it "has a pool" do
    pool = Factory(:pool)
    conference = Conference.new(:pool_id => pool.id)
    conference.pool.should == pool
  end
  
end
