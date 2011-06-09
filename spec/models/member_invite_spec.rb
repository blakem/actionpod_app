require 'spec_helper'

describe MemberInvite do
  it "can save to the database" do
    MemberInvite.create!
  end
end
