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
end
