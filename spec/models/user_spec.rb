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
end
