require 'spec_helper'

describe User do
  it "Should have a secret invite code" do
    User.secret_invite_code.should_not be_empty
  end
end
