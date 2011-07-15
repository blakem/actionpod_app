require 'spec_helper'

describe SmsHandler do
  it "should return a welcome message on random input" do
    user = Factory(:user)
    phone = Factory(:phone, :user_id => user.id)
    response = SmsHandler.new.process_sms("Random Text", phone.number)
    response.should == 'Welcome to 15 Minute Calls.  See 15minutecalls.com for more information.'
  end
end
