require 'spec_helper'

describe Phone do
  it "should have a user" do
    phone = Factory(:phone)
    phone.user.should be_a_kind_of(User)    
  end
end
