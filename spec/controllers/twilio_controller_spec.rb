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
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should be_success
    end
  end

  describe "place_test_call" do
    it "should be success" do
  	  controller.user_signed_in?.should be_false
      post :place_test_call
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should be_success
      response.should have_selector('response>gather', :numdigits => '1')
      response.should have_selector('response>gather', :finishonkey => '#')
      response.should have_selector('response>gather', :action => 'http://www.15minutecalls.com/twilio/place_test_call_thanks.xml')
      response.should have_selector('response>gather>say', :content => 'Welcome. Please press 1 on your handset.')
      response.should have_selector('response>say', 
        :content => 'Sorry, We didn\'t receive any input.  For help, please contact support.')
    end
  end

  describe "place_test_call_thanks" do
    it "should be success" do
  	  controller.user_signed_in?.should be_false
      post :place_test_call_thanks
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should be_success
      response.should have_selector('response>say', :content => "Excellent. Your phone is now set up and ready to go.  Thank you and have an awesome day.")
    end
  end
  
  describe "greeting" do
    it "should say can't match this number when it can't find an event" do
      call = Call.create(:Sid => '12345', :status => 'outgoing')
      post :greeting, :CallSid => '12345'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
      call.reload
      call.status.should == 'outgoing-greeting:nomatch'
    end

    it "should match up with the event being called" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call')      
      call = Call.create(:Sid => '12345', :event_id => event.id, :status => 'outgoing')
      post :greeting, :CallSid => '12345'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>gather', :numdigits => '1')
      response.should have_selector('response>gather', :finishonkey => '#')
      response.should have_selector('response>gather', :action => 'http://www.15minutecalls.com/twilio/put_on_hold.xml')
      response.should have_selector('response>gather>say', :content => 'Welcome to your Morning Call. Press 1 to join the conference.')
      response.should have_selector('response>say', 
        :content => 'Sorry, We didn\'t receive any input. You may dial into the conference directly at 4, 1, 5, 7, 6, 6, 9, 8, 6, 5.')
      call.reload
      call.status.should == 'outgoing-greeting:match'
    end
  end

  describe "greeting_fallback" do
    it "should say can't match this number when it can't find an event" do
      tc = mock('TwilioCaller')
      tc.should_receive(:send_error_to_blake).with('Fallback: 12345')
      TwilioCaller.should_receive(:new).and_return(tc)
      call = Call.create(:Sid => '12345', :status => 'outgoing')
      post :greeting_fallback, :CallSid => '12345'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
      call.reload
      call.status.should == 'outgoing-fallback:nomatch'
    end

    it "should put on hold on CallSid" do
      tc = mock('TwilioCaller')
      tc.should_receive(:send_error_to_blake).with('Fallback: 543211')
      TwilioCaller.should_receive(:new).and_return(tc)
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      call = Call.create(:Sid => '543211', :event_id => event.id)
      post :greeting_fallback, :CallSid => '543211'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event.id}User#{user.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
      call.reload
      call.status.should == 'fallback:match-onhold:match'
      user.reload
      user.answered_count.should == 1
      user.missed_in_a_row.should == 0
      user.made_in_a_row.should == 1
    end    
  end

  describe "callback" do
    it "should set the duration of the call" do
      call = Call.create(:Sid => '54321', :status => 'foo')
      post :callback, :CallSid => call.Sid, :CallDuration => 33
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      call.reload
      call.status.should == 'foo-callback:nomatch-completed'
      call.Duration.should == 33
    end

    it "should match up with the event being called" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      call = Call.create(:Sid => '12345', :event_id => event.id, :status => 'foo')
      post :callback, :CallSid => call.Sid, :CallDuration => 23, :AnsweredBy => 'human'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      call.reload
      call.status.should == 'foo-callback:match-completed'
      call.AnsweredBy.should == 'human'
      call.Duration.should == 23
    end

    it "should update the missed count" do
      user = Factory(:user, :made_in_a_row => 3, :missed_in_a_row => 2)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      call = Call.create(:Sid => '12345', :event_id => event.id, :status => 'outgoing-greeting:match', :AnsweredBy => 'human')
      post :callback, :CallSid => call.Sid, :CallDuration => 23
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      call.reload
      call.status.should == 'outgoing-greeting:match-callback:match-completed'
      call.Duration.should == 23
      call.AnsweredBy.should == 'human'
      user.reload
      user.made_in_a_row.should == 0
      user.missed_in_a_row.should == 3
    end

    it "should update the made count for ifmachine direct callers" do
      user = Factory(:user, :made_in_a_row => 3, :missed_in_a_row => 2)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      call = Call.create(:Sid => '12345', :event_id => event.id, :status => 'outgoing-direct:match-placing:15mcPool1Room1-placed:15mcPool1Room1')
      post :callback, :CallSid => call.Sid, :CallDuration => 23
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      call.reload
      call.status.should == 'outgoing-direct:match-placing:15mcPool1Room1-placed:15mcPool1Room1-callback:match-completed'
      call.Duration.should == 23
      user.reload
      user.made_in_a_row.should == 3
      user.missed_in_a_row.should == 2
    end

    it "should not update the missed count if twilio bug hit where we never got to the greeting page" do
      tc = mock('TwilioCaller')
      tc.should_receive(:send_error_to_blake).with('OutgoingBug: 12345')
      TwilioCaller.should_receive(:new).and_return(tc)
      user = Factory(:user, :made_in_a_row => 3, :missed_in_a_row => 2)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      call = Call.create(:Sid => '12345', :event_id => event.id, :status => 'outgoing')
      post :callback, :CallSid => call.Sid, :CallDuration => 23
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      call.reload
      call.status.should == 'outgoing-callback:match-completed'
      call.Duration.should == 23
      user.reload
      user.made_in_a_row.should == 3
      user.missed_in_a_row.should == 2
    end
  end

  describe "go_directly_to_conference" do
    it "should say can't match this number when it can't find an event" do
      call = Call.create(:Sid => '54321', :status => 'foo')
      post :go_directly_to_conference, :CallSid => call.Sid
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
      call.reload
      call.status.should == 'foo-direct:nomatch'
    end

    it "should match up with the event being called" do
      user = Factory(:user, :answered_count => 3, :made_in_a_row => 3, :missed_in_a_row => 2)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      call = Call.create(:Sid => '12345', :event_id => event.id)
      post :go_directly_to_conference, :CallSid => '12345', :AnsweredBy => 'human'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Welcome to your Morning Call.')
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event.id}User#{user.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
      call.reload
      call.status.should == 'direct:match'
      call.AnsweredBy.should == 'human'
      user.reload
      user.answered_count.should == 4
      user.missed_in_a_row.should == 0
      user.made_in_a_row.should == 4
    end
  end

  describe "put_on_hold" do
    it "should say can't match this number when it can't find an event" do
      call = Call.create(:Sid => '54321', :status => 'foo')
      post :put_on_hold, :CallSid => call.Sid
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
      call.reload
      call.status.should == 'foo-onhold:nomatch'
    end

    it "should put on hold on CallSid" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      call = Call.create(:Sid => '54321', :event_id => event.id)
      post :put_on_hold, :CallSid => '54321'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event.id}User#{user.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
      call.reload
      call.status.should == 'onhold:match'
      user.reload
      user.answered_count.should == 1
      user.missed_in_a_row.should == 0
      user.made_in_a_row.should == 1
    end

    it "should put on hold on PhoneNumberSid" do
      user = Factory(:user)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      Call.create(:Sid => '54321', :PhoneNumberSid => 'PN123', :event_id => event.id)
      post :put_on_hold, :PhoneNumberSid => 'PN123'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event.id}User#{user.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end

    it "should put on hold on From" do
      user = Factory(:user)
      phone1 = Factory(:phone, :user_id => user.id, :primary => true)
      phone2 = Factory(:phone, :user_id => user.id, :primary => false)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      post :put_on_hold, :From => phone1.number, :Direction => 'inbound' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event.id}User#{user.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end

    it "should put on hold on From using a non primary phone" do
      user = Factory(:user)
      phone1 = Factory(:phone, :user_id => user.id, :primary => true)
      phone2 = Factory(:phone, :user_id => user.id, :primary => false)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      post :put_on_hold, :From => phone2.number, :Direction => 'inbound' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event.id}User#{user.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end
    
    it "should put on hold on To" do
      user = Factory(:user)
      phone1 = Factory(:phone, :user_id => user.id, :primary => true)
      phone2 = Factory(:phone, :user_id => user.id, :primary => false)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      post :put_on_hold, :To => phone1.number, :Direction => 'outbound-api' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event.id}User#{user.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end

    it "should put on hold on To using a non primary phone" do
      user = Factory(:user)
      phone1 = Factory(:phone, :user_id => user.id, :primary => true)
      phone2 = Factory(:phone, :user_id => user.id, :primary => false)
      pool = Factory(:pool, :timelimit => 23)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => pool.id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      post :put_on_hold, :To => phone2.number, :Direction => 'outbound-api' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event.id}User#{user.id}Pool#{pool.id}")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end
  end
  
  describe "incoming" do
    it "should say can't match this number when it can't find an event" do
      post :incoming
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
    end

    it "should match up with the event being called" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id)

      now = Time.now.in_time_zone(user.time_zone)
      event1 = Factory(:event, :user_id => user.id, :name => 'Second Morning Call', :pool_id => Factory(:pool).id)
      event1.days = [0,1,2,3,4,5,6]
      event1.time = (now - 2.minutes).strftime("%I:%M%p")
      event1.save

      event2 = Factory(:event, :user_id => user.id, :name => 'Bit After Morning Call', :pool_id => Factory(:pool).id)
      event2.days = [0,1,2,3,4,5,6]
      event2.time = (now + 5.minutes).strftime("%I:%M%p")
      event2.save

      event3 = Factory(:event, :user_id => user.id, :name => 'First Morning Call', :pool_id => Factory(:pool).id)
      event3.days = [0,1,2,3,4,5,6]
      event3.time = (now - 3.minutes).strftime("%I:%M%p")
      event3.save

      event4 = Factory(:event, :user_id => user.id, :name => 'Fourth Morning Call', :pool_id => Factory(:pool).id)
      event4.days = [0,1,2,3,4,5,6]
      event4.time = (now + 14.minutes).strftime("%I:%M%p")
      event4.save

      event5 = Factory(:event, :user_id => user.id, :name => 'Bit Before Morning Call', :pool_id => Factory(:pool).id)
      event5.days = [0,1,2,3,4,5,6]
      event5.time = (now - 1.minutes).strftime("%I:%M%p")
      event5.save

      event6 = Factory(:event, :user_id => user.id, :name => 'No Days Scheduled', :pool_id => Factory(:pool).id)
      event6.days = []
      event6.save

      post :incoming, :From => phone.number, :Direction => 'inbound' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Hello, welcome to your Bit After Morning Call.')
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (event2.pool.timelimit * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event2.id}User#{user.id}Pool#{event2.pool.id}Incoming")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
      
      event2.time = (now + 13.minutes).strftime("%I:%M%p")
      event2.save
      post :incoming, :From => phone.number, :Direction => 'inbound' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Hello, welcome to your Bit Before Morning Call.')
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (event5.pool.timelimit * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event5.id}User#{user.id}Pool#{event5.pool.id}Incoming")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end

    it "should match up with a previous (i.e. one that's schedule every week on yesterday) call if he's not schedule for one today" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id)

      now = Time.now.in_time_zone(user.time_zone)
      event1 = Factory(:event, :user_id => user.id, :name => 'Yesterdays Call', :pool_id => Factory(:pool).id)
      event1.days = [ (now.strftime("%w").to_i + 8) % 7 ] 
      event1.time = '8am'
      event1.save

      post :incoming, :From => phone.number, :Direction => 'inbound' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Hello, welcome to your Yesterdays Call.')
      response.should have_selector('response>say', :content => 'Waiting for the other participants')
      response.should have_selector('response>dial', :timelimit => (event1.pool.timelimit * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{event1.id}User#{user.id}Pool#{event1.pool.id}Incoming")
      response.should have_selector('response>say', :content => 'Time is up. Goodbye.')
    end

    it "should not match up with a user without a primary phone" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id)
      phone.number = nil
      phone.save(false)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => Factory(:pool).id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      post :incoming, :From => nil, :Direction => 'inbound' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
    end

    it "should not match up on calls with a null PhoneNumberSid or null Sid" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => Factory(:pool).id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      Call.create(:event_id => event.id, :PhoneNumberSid => nil, :Sid => nil)
      post :incoming, :From => 'SomeOtherPhone', :Direction => 'inbound' 
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry")
      user.reload
      user.incoming_count.should == 0
    end
    
    it "should create a call record and upate the incoming_count" do
      user = Factory(:user, :incoming_count => 5)
      phone = Factory(:phone, :user_id => user.id, :primary => true)
      event = Factory(:event, :user_id => user.id, :name => 'Morning Call', :pool_id => Factory(:pool).id)
      event.days = [0,1,2,3,4,5,6]
      event.save
      expect {
        post :incoming, :From => phone.number, :Direction => 'inbound', :CallSid => "CA462"
      }.to change(Call, :count).by(1)
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      call = Call.find_by_Sid('CA462')
      call.Direction.should == 'inbound'
      call.From.should == user.primary_phone.number
      call.event_id.should == event.id
      call.status.should == 'incoming-onhold'
      call.user_id.should == user.id
      user.reload
      user.incoming_count.should == 6
    end

    it "should create a call record even when it can't match an event" do
      phone_number = '+14345459122'
      expect {
        post :incoming, :From => phone_number, :Direction => 'inbound', :CallSid => "CA463"
      }.to change(Call, :count).by(1)
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      call = Call.find_by_Sid('CA463')
      call.Direction.should == 'inbound'
      call.From.should == phone_number
      call.event_id.should be_nil
      call.status.should == 'incoming-nomatch'
    end
  end
  
  describe "place_in_conference" do
    it "should put the user into the conference room when it knows the other callers" do
      call = Call.create(:Sid => '5566', :status => 'outgoing-matched')
      user1 = Factory(:user, :name => 'Bobby')
      user2 = Factory(:user, :name => 'Sally')
      event1 = Factory(:event, :user_id => user1.id)
      event2 = Factory(:event, :user_id => user2.id)
      post :place_in_conference, :conference => 'FooBar', :timelimit => (24 * 60).to_s, :event => event1.id, 
        :events => [event1.id, event2.id].join(','), :CallSid => '5566'
      intro_string = TwilioController.new.send(:build_intro_string, "#{event1.id},#{event2.id}")
      response.content_type.should =~ /^application\/xml/
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response][:Say].count.should == 3
      hash[:Response][:Dial].count.should == 2
      response.should have_selector('response>say', :content => "Welcome. On the call today we have #{intro_string}")
      response.should_not have_selector('response>say', :content => 'Welcome. Joining a conference already in progress.')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "FooBar")
      response.should have_selector('response>say', :content => '1 Minute Remaining.')      
      response.should have_selector('response>dial', :timelimit => 60.to_s)
      response.should have_selector('response>say', :content => "Time is up. Your next call is #{user1.next_call_time_string}. Have an Awesome day!")      
      call.reload
      call.status.should == 'outgoing-matched-placed:FooBar'
    end

    it "should put the user into the conference after the 60 second warning if he has less than 60 seconds left" do
      user = Factory(:user, :name => 'Bobby')
      event = Factory(:event, :user_id => user.id)
      post :place_in_conference, :conference => 'FooBar', :timelimit => '59', :event => event.id, :events => "#{event.id}"
      intro_string = TwilioController.new.send(:build_intro_string, "#{event.id}")
      response.content_type.should =~ /^application\/xml/
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response][:Say].count.should == 2
      hash[:Response][:Dial].should be_a_kind_of(Hash)
      response.should have_selector('response>say', :content => "Welcome. On the call today we have #{intro_string}")
      response.should have_selector('response>dial', :timelimit => '59')
      response.should have_selector('response>dial>conference', :content => "FooBar")
      response.should have_selector('response>say', :content => "Time is up. Your next call is #{user.next_call_time_string}. Have an Awesome day!")      
      response.should_not have_selector('response>say', :content => 'Welcome. Joining a conference already in progress.')
      response.should_not have_selector('response>say', :content => '1 Minute Remaining.')      
    end

    it "should put the user into the conference room when it doesn't know the other callers" do
      post :place_in_conference, :conference => 'FooBar', :timelimit => (24 *60).to_s, :events => ''
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => 'Welcome. Joining a conference already in progress.')
      response.should_not have_selector('response>say', :content => 'Welcome. On the call today we have')
      response.should have_selector('response>dial', :timelimit => (23 * 60).to_s)
      response.should have_selector('response>dial>conference', :content => "FooBar")
      response.should have_selector('response>say', :content => '1 Minute Remaining.')      
      response.should have_selector('response>dial', :timelimit => 60.to_s)
      response.should have_selector('response>say', :content => "Time is up. Have an Awesome day!")      
    end

    it "should default to a time limit of 15 and a room of DefaultConference" do
      post :place_in_conference
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>dial', :timelimit => (14 * 60).to_s)
      response.should have_selector('response>say', :content => '1 Minute Remaining.')      
      response.should have_selector('response>dial', :timelimit => 60.to_s)
      response.should have_selector('response>dial>conference', :content => "DefaultConference")
    end
  end
  
  describe "build_intro_string" do
    it "builds nice strings" do
      tc = TwilioController.new
      tc.send(:build_intro_string, '').should == ''

      pool = Factory(:pool)
      user1 = Factory(:user, :name => 'Bobby', :title => '', :location => '')
      user2 = Factory(:user, :name => 'Sally', :title => '', :location => '')
      user3 = Factory(:user, :name => 'Jane', :title => '', :location => '', :phonetic_name => 'Jaaane')
      event1 = Factory(:event, :user_id => user1.id, :pool_id => pool.id)
      event2 = Factory(:event, :user_id => user2.id, :pool_id => pool.id)
      event3 = Factory(:event, :user_id => user3.id, :pool_id => pool.id)
      tc.send(:build_intro_string, "#{event1.id}").should == 'Bobby'
      tc.send(:build_intro_string, "#{event1.id},#{event2.id}").should == 'Bobby, and Sally'
      tc.send(:build_intro_string, "#{event1.id},#{event2.id},#{event3.id}").should == 'Bobby, Sally, and Jaaane'
      
      user1.title = 'Software Developer'
      user1.save
      tc.send(:build_intro_string, "#{event1.id},#{event2.id}").should == 'Bobby a Software Developer, and Sally'

      user1.location = 'San Francisco'
      user1.save

      user2.location = 'Seattle'
      user2.save
      tc.send(:build_intro_string, "#{event1.id},#{event2.id}").should == 'Bobby a Software Developer from San Francisco, and Sally from Seattle'

      tc.send(:build_intro_string, "0,888,44466,33377,,xyzzy,#{event1.id},#{event2.id}").should == 'Bobby a Software Developer from San Francisco, and Sally from Seattle'
    end
  end

  describe "apologize_no_other_participants" do
    before(:each) do
      @user = Factory(:user)
      @event = Factory(:event, :user_id => @user.id)
    end

    it "should say sorry and give the number of total participants called" do
      call = Call.create(:Sid => '3333', :status => 'foo')
      post :apologize_no_other_participants, :participant_count => '2', :event => @event.id, :CallSid => '3333'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry. I called 1 other person but they didn't answer.")
      response.should have_selector('response>say', :content => 
        "You may stay on the line, for one of them to call in. Or wait for your next call, #{@user.next_call_time_string}.")
      response.should have_selector('response>say', :content => "Waiting for another participant.")
      response.should have_selector('response>dial', :timelimit => @event.pool.timelimit.minutes.to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{@event.id}User#{@user.id}Pool#{@event.pool.id}")
      call.reload
      call.status.should == 'foo-apologized'
    end

    it "should say sorry and give the number of total participants called" do
      post :apologize_no_other_participants, :participant_count => '3', :event => @event.id
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>say', :content => "I'm sorry. I called 2 other people but they didn't answer.")
      response.should have_selector('response>say', :content => 
        "You may stay on the line, for one of them to call in. Or wait for your next call, #{@user.next_call_time_string}.")
      response.should have_selector('response>say', :content => "Waiting for another participant.")
      response.should have_selector('response>dial', :timelimit => @event.pool.timelimit.minutes.to_s)
      response.should have_selector('response>dial>conference', :content => "15mcHoldEvent#{@event.id}User#{@user.id}Pool#{@event.pool.id}")
    end
  end

  describe "sms" do
    it "should send back a welcome message" do
      post :sms, :Body => "Foo", :From => '+12223334444'
      hash = (Hash.from_xml response.body).with_indifferent_access
      hash[:Response].should be_true
      response.content_type.should =~ /^application\/xml/
      response.should have_selector('response>sms', :content => "Welcome to 15 Minute Calls.  See 15minutecalls.com for more information.")
    end
  end
end
