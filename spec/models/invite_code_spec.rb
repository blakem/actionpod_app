require 'spec_helper'

describe InviteCode do
  it "has a name" do
    invite_code = InviteCode.create(:name => 'foo')
    invite_code.name.should == 'foo'
  end
end
