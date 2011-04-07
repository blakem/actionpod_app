require 'spec_helper'

describe TwilioController do
  render_views
  before(:each) do
    @request.env["HTTP_ACCEPT"] = "application/xml"
  end

  describe "when not logged in" do
    it "should be success" do
  	  controller.user_signed_in?.should be_false
      post :greeting
      response.content_type.should =~ /^application\/xml/
      response.should be_success
    end
  end

  describe "greeting" do
    it "should say can't match this number when it can't find an event" do
      post :greeting
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
    end

    it "should match up with the event being called" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call')      
      Call.create(:Sid => '12345', :event_id => event.id)
      post :greeting, :CallSid => '12345'
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>gather', :numdigits => '1')
      response.should have_selector('response>gather', :finishonkey => '#')
      response.should have_selector('response>gather', :action => 'http://www.15minutecalls.com/twilio/put_on_hold.xml')
      response.should have_selector('response>gather>say', :content => 'Welcome to your Morning Call. Press 1 to join the conference.')
      response.should have_selector('response>say', 
        :content => 'Sorry, We didn\'t receive any input. You may dial into the conference directly at 4, 1, 5, 7, 6, 6, 9, 8, 6, 5.')
    end
  end

  describe "greeting_fallback" do
    it "should say can't match this number when it can't find an event" do
      post :greeting_fallback
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
    end

    it "should put on hold on CallSid" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 33)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      Call.create(:Sid => '54321', :event_id => event.id)
      post :greeting_fallback, :CallSid => '54321'
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Joining a conference room')
      response.should have_selector('response>dial', :timelimit => (33 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "HoldEvent#{event.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end    
  end

  describe "callback" do
    it "should set the duration of the call" do
      call = Call.create(:Sid => '54321')
      post :callback, :CallSid => '54321', :CallDuration => 33
      call.reload
      call.Duration.should == 33
    end
  end

  describe "put_on_hold" do
    it "should say can't match this number when it can't find an event" do
      post :put_on_hold
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
    end

    it "should put on hold on CallSid" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 33)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      Call.create(:Sid => '54321', :event_id => event.id)
      post :put_on_hold, :CallSid => '54321'
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Joining a conference room')
      response.should have_selector('response>dial', :timelimit => (33 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "HoldEvent#{event.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end

    it "should put on hold on PhoneNumberSid" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 33)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      Call.create(:Sid => '54321', :PhoneNumberSid => 'PN123', :event_id => event.id)
      post :put_on_hold, :PhoneNumberSid => 'PN123'
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Joining a conference room')
      response.should have_selector('response>dial', :timelimit => (33 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "HoldEvent#{event.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end

    it "should put on hold on From" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 33)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      post :put_on_hold, :From => user.primary_phone, :Direction => 'inbound' 
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Joining a conference room')
      response.should have_selector('response>dial', :timelimit => (33 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "HoldEvent#{event.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end

    it "should put on hold on To" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 33)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      post :put_on_hold, :To => user.primary_phone, :Direction => 'outbound-api' 
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Joining a conference room')
      response.should have_selector('response>dial', :timelimit => (33 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "HoldEvent#{event.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end
  end
  
  describe "incoming" do
    it "should say can't match this number when it can't find an event" do
      post :incoming
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
    end

    it "should match up with the event being called" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => Factory(:pool).id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      post :incoming, :From => user.primary_phone, :Direction => 'inbound' 
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>gather', :numdigits => '1')
      response.should have_selector('response>gather>say', :content => 'Hello, welcome to your Morning Call.')
    end
    
    it "should create a call record" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => Factory(:pool).id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      expect {
        post :incoming, :From => user.primary_phone, :Direction => 'inbound', :CallSid => "CA462"
      }.to change(Call, :count).by(1)
      call = Call.find_by_Sid('CA462')
      call.Direction.should == 'inbound'
      call.From.should == user.primary_phone
      call.event_id.should == event.id
    end
  end
  
  describe "place_in_conference" do
    it "should put the user into the conference room" do
      post :place_in_conference, :conference => 'FooBar', :timelimit => 24
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Welcome')
      response.should have_selector('response>dial', :timelimit => (24 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "FooBar")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')      
    end

    it "should default to a time limit of 15 and a room of DefaultConference" do
      post :place_in_conference
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>dial', :timelimit => (15 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "DefaultConference")
    end
  end

  describe "sms" do
    it "should send back a welcome message" do
      post :sms
      response.should have_selector('response>sms', :content => "Welcome to 15-Minute Calls.  See 15minutecalls.com for more information.")
    end
  end
end
