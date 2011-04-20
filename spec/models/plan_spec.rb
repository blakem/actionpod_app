require 'spec_helper'

describe Plan do
  it "has a body" do
    plan = Factory(:plan)
    plan.body.should_not be_blank    
  end

  it "has a user" do
    plan = Factory(:plan)
    plan.user.should be_a_kind_of(User)    
  end
end
