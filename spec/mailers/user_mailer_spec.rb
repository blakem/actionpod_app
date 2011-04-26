require "spec_helper"

describe UserMailer do
  it "shouldn't crash" do
    user1 = Factory(:user)
    user2 = Factory(:user)
    UserMailer.stub(:mail => true)
    UserMailer.deliver_conference_email(user1, [user1, user2])
  end
end
