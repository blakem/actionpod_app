require 'spec_helper'

describe MemberInvite do
  it "can save to the database" do
    MemberInvite.create!
  end
  
  describe "tokens" do
    it "can create a token" do
      token = MemberInvite.generate_token
      token.length.should == 20
      token.class.should == String
    end
    
    it "Should ensure uniqueness among invite_codes and other member_invites" do
      MemberInvite.create(:invite_code => 'abc')
      InviteCode.create(:name => 'def')
      Devise.should_receive(:friendly_token).exactly(4).times.and_return('abc','def', 'acti0np0duser', 'ghi')
      token = MemberInvite.generate_token
      token.should == 'ghi'
    end
  end
end
