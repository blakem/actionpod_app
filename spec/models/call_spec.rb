require 'spec_helper'

describe Call do
  it "categorizes it's status into status_category" do
    call = Factory(:call)
    call.status = 'outgoing'
    call.status_category.should == 'Out InProgress'
    call.status = 'outgoing-greeting:match-callback:match-completed'
    call.status_category.should == 'NoAnswer'
    call.status = 'foobarbaz'
    call.status_category.should == '???'
  end
end
