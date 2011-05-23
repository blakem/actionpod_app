require 'spec_helper'

describe MemberTracker do
  before(:each) do
    @mt = MemberTracker.new
  end

  describe "contact_stranded_members" do
    it "should email members that have not signed up for an event after 48 hours" do
      user1 = Factory(:user, :answered_count => 0) # not old enough
      user2 = Factory(:user, :answered_count => 0)
      user3 = Factory(:user, :placed_count   => 1) # has received a call
      user4 = Factory(:user, :answered_count => 0) # has a scheduled event 
      ActiveRecord::Base.record_timestamps = false
      [user2, user3, user4].each do |user|
        user.created_at = user.updated_at = Time.now - 50.hours
        user.save
      end
      event = Factory(:event, :user_id => user4.id)
      ActiveRecord::Base.record_timestamps = true
      User.stub(:all => [user1, user2])
      deliver = mock('Deliver')
      deliver.should_receive(:deliver)
      UserMailer.should_receive(:member_next_steps).with(user2).and_return(deliver)
      expect {
        @mt.contact_stranded_members
      }.should change(MemberMail, :count).by(1)
      MemberMail.where(
        :user_id => user2.id,
        :email_type => 'next_steps' 
      ).count.should == 1

      expect {
        @mt.contact_stranded_members
      }.should_not change(MemberMail, :count)
    end
  end
end
