require 'spec_helper'

describe InviteCode do
  it "Stores its name in lowercase" do
    invite_code = InviteCode.create(:name => 'FooBarBaz')
    invite_code.name.should == 'foobarbaz'
  end
end
