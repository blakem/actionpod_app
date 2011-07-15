require 'spec_helper'

describe SmsHandler do

  describe "process_sms" do

    it "should return a welcome message on random input" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id)
      response = SmsHandler.new.process_sms("Random Text", phone.number)
      response.should == 'Welcome to 15 Minute Calls.  See 15minutecalls.com for more information.'
    end

    it "should return a welcome message on random input" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id)
      response = SmsHandler.new.process_sms("Random Text", phone.number)
      response.should == 'Welcome to 15 Minute Calls.  See 15minutecalls.com for more information.'
    end

    it "should cancel next event if it receives 'Busy'" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id)
      event = Factory(:event, :user_id => user.id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      next_occurrence = event.next_occurrence
      response = SmsHandler.new.process_sms("Busy", phone.number)
      user.reload
      event.reload
      response.should == "Ok, call cancelled. Your next call is at: #{user.next_call_time_string}."
      event.next_occurrence.should == next_occurrence + 24.hours
    end

    it "should return next call time if it receives 'next'" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id)
      event = Factory(:event, :user_id => user.id)
      response = SmsHandler.new.process_sms(" NeXt ", phone.number)
      response.should == "Your next call is at: #{user.next_call_time_string}."
    end
  end
end
