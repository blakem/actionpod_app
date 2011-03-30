require 'spec_helper'

describe User do
  it "Should have a secret invite code" do
    User.secret_invite_code.should_not be_empty
  end
  
  it "should have an admin attribute" do
    user = Factory(:user)
    user.admin?.should be_false
    user.admin = true
    user.admin?.should be_true
  end
  
  it "should have many events" do
    user = Factory(:user)
    event1 = Factory(:event, :user_id => user.id)
    event2 = Factory(:event, :user_id => user.id)
    event3 = Factory(:event)
    user.events.should include(event1, event2)
    user.events.should_not include(event3)
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
    user = User.create()
    user.time_zone.should == 'Pacific Time (US & Canada)'
  end
  
  it "should have a name" do
    user = Factory(:user, :name => 'Bob Jones')
    user.name.should == 'Bob Jones'
  end

  it "should have a primary_phone" do
    user = Factory(:user, :primary_phone => '415-444-1234')
    user.primary_phone.should == '415-444-1234'
  end

  it "should have a title" do
    user = Factory(:user, :title => 'Software Developer')
    user.title.should == 'Software Developer'
  end
end
