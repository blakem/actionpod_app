require "spec_helper"

describe UserMailer do
  describe "conference_email" do
    it "shouldn't crash" do
      UserMailer.stub(:mail => true)
      user1 = Factory(:user)
      user2 = Factory(:user)
      UserMailer.deliver_conference_email(user1, [user1, user2])
      event = Factory(:event, :user_id => user1.id)
      UserMailer.deliver_conference_email(user1, [user1, user2])
    end
  end

  describe "member_message" do
    it "shouldn't crash" do
      UserMailer.stub(:mail => true)
      user1 = Factory(:user)
      user2 = Factory(:user)
      UserMailer.deliver_member_message(user1, user2, 'Test Message')
    end
  end

  describe "message_to_blake" do
    it "shouldn't crash" do
      UserMailer.stub(:mail => true)
      UserMailer.deliver_message_to_blake("I like jellybeans")
      UserMailer.deliver_message_to_blake("I like jellybeans", "Another cool subject")
    end
  end

  describe "member_next_steps" do
    it "shouldn't crash" do
      user = Factory(:user)
      UserMailer.stub(:mail => true)
      UserMailer.member_next_steps(user)
    end
  end
end
