require 'spec_helper'

describe Event do
  it "should have a user" do
    user = Factory(:user)
    event = Factory(:event, :user_id => user.id)
    event.user.should == user
  end
end
