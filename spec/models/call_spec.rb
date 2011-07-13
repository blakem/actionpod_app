require 'spec_helper'

describe Call do
  it "categorizes it's status into status_category" do
    call = Factory(:call)
    call.status = 'outgoing'
    call.status_category.should == 'Out InProgress'
    call.status = 'outgoing-greeting-callback'
    call.status_category.should == 'NoAnswer'
    call.status = 'outgoing-greeting-nokeypress-callback'
    call.status_category.should == 'NoAnswer'
    call.status = 'outgoing-greeting-onhold-apologized-onhold-apologized-onhold-callback'
    call.status_category.should == 'Apology'
    call.status = 'outgoing-greeting-onhold-placed:15mcPool11Room1-callback'
    call.status_category.should == 'Placed'
    call.status = 'foobarbaz'
    call.status_category.should == '???'
    call.status = 'inbound-onhold-callback'
    call.status_category.should == 'Inbound Notplaced'
  end
  
  it "can compute it's cost" do
    call = Factory(:call)
    call.Duration = nil
    call.cost.should == 0.00
    call.Duration = 15*60
    call.Direction = 'inbound'
    call.cost.should == 0.15
    call.Direction = 'outbound-api'
    call.cost.should == 0.30
    pool = Factory(:pool, :timelimit => 24) # 0.5 per hour for heroku dynos
    event = Factory(:event, :pool_id => pool.id)
    call.event_id = event.id
    event.send_sms_reminder = false
    event.save
    call.cost.should == 0.32
    event.send_sms_reminder = true
    event.save
    call.cost.should == 0.34
  end
end
