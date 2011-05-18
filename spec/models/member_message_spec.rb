require 'spec_helper'

describe MemberMessage do
  it "can save to the database" do
    MemberMessage.create!
  end
end
