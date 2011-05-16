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
    call.status = 'outgoing-greeting:match-onhold:match-placing:15mcPool1Room1-placed:15mcPool1Room1-callback:match-completed'
    call.status_category.should == 'Success'
    call.status = 'outgoing-greeting:match-callback:match'
    call.status_category.should == 'Got CallBack'
    call.status = 'outgoing-greeting:match'
    call.status_category.should == 'Got Greeting'
    call.status = 'incoming-onhold-placing:15mcPool1Room1-placed:15mcPool1Room1-callback:match-completed'
    call.status_category.should == 'InSuccess'
    call.status = 'outgoing-direct:match-placing:15mcPool1Room1-placed:15mcPool1Room1-callback:match-completed'
    call.status_category.should == 'DirSuccess'
    call.status = 'incoming-onhold-apologizing-apologized-callback:match-completed'
    call.status_category.should == 'InOnlyOne'
    call.status = 'outgoing-direct:match-apologizing-apologized-callback:match-completed'
    call.status_category.should == 'DirOnlyOne'
    call.status = 'outgoing-greeting:match-onhold:match-apologizing-apologized-callback:match-completed'
    call.status_category.should == 'OutOnlyOne'
    call.status = 'outgoing-greeting:match-onhold:match-callback:match-completed'
    call.status_category.should == 'OutOnlyOne'
    call.status = 'outgoing-callback:match-completed'
    call.status_category.should == '????'    
    event = Factory(:event)
    user = event.user
    call.event_id = event.id
    call.save
    user.use_ifmachine = true
    user.save
    call.status_category.should == 'DirNoAnswer'
    user.use_ifmachine = false
    user.save
    call.status_category.should == 'PossibleError'
    call.status = 'outgoing-fallback:match-onhold:match-callback:match-completed'
    call.status_category.should == 'FallbackError'
  end
end
