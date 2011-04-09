require 'spec_helper'

describe TwilioCaller do
  before(:each) do
    @tc = TwilioCaller.new
  end

  describe "Initiating a call" do
    it "should have a start_call_uri" do
      @tc.start_call_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls.json"
    end
  
    it "should use Twilio::RestAccount to make a call" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id)  
      response = mock('HTTPResponse', :body => successful_start_call_response)
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(
        "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls.json",
        "POST", 
        {"From"           => "+14157669865",
         "To"             => user.primary_phone, 
         "Url"            => "http://www.15minutecalls.com/twilio/greeting.xml",
         "FallbackUrl"    => "http://www.15minutecalls.com/twilio/greeting_fallback.xml", 
         "StatusCallback" => "http://www.15minutecalls.com/twilio/callback.xml"
        })
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      expect {
        @tc.start_call_for_event(event)
      }.to change(Call, :count).by(1)
      call = Call.find_by_event_id(event.id)
      call.Sid.should == 'CA6be8176371a8a7a096207feff1044b3e'
      call.DateCreated.should == 'Thu, 07 Apr 2011 01:10:50 +0000'
      call.DateUpdated.should == 'Thu, 07 Apr 2011 01:10:50 +0000'
      call.To.should == '+14153141222'
      call.From.should == '+14157669865'
      call.PhoneNumberSid.should == 'PN435c6e6362839f82d08fb3e6848cab84'
      call.Uri.should == '/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CA6be8176371a8a7a096207feff1044b3e.json'
      call.Direction.should == 'outbound-api'
      call.event_id.should == event.id
    end

    it "should go straight to put_on_hold if user has use_ifmachine set" do
      user = Factory(:user)
      user.use_ifmachine = true
      user.save
      event = Factory(:event, :user_id => user.id)  
      response = mock('HTTPResponse', :body => successful_start_call_response)
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(
        "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls.json",
        "POST", 
        {"From"           => "+14157669865",
         "To"             => user.primary_phone, 
         "Url"            => "http://www.15minutecalls.com/twilio/put_on_hold.xml",
         "IfMachine"      => "Hangup",
         "FallbackUrl"    => "http://www.15minutecalls.com/twilio/greeting_fallback.xml", 
         "StatusCallback" => "http://www.15minutecalls.com/twilio/callback.xml"
        })
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      expect {
        @tc.start_call_for_event(event)
      }.to change(Call, :count).by(1)
    end
  end

  describe "Getting information about conferences" do
    it "should have a conferences_in_progress_uri" do
      @tc.conferences_in_progress_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences.json?Status=in-progress"
    end
  
    it "conferences_in_progress" do
      response = mock('HTTPResponse', :body => conference_response)
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      conferences = @tc.conferences_in_progress
      conferences.should == [{
        "sid"=>"CFd69aa0e4fe673292932492f68ba94d3f",
        "account_sid"=>"AC2e57bf710b77d765d280786bc07dbacc",
        "friendly_name"=>"HoldEvent4Pool1",
        "status"=>"in-progress",
        "date_created"=>"Thu, 07 Apr 2011 00:02:16 +0000",
        "api_version"=>"Thu, 01 Apr 2010".to_date,
        "date_updated"=>"Thu, 07 Apr 2011 00:02:17 +0000",
        "uri"=>
         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFd69aa0e4fe673292932492f68ba94d3f.json",
        "subresource_uris"=>
         {"participants"=>
           "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFd69aa0e4fe673292932492f68ba94d3f/Participants.json"
           }
      }]
    end

    it "conferences_on_hold_for_pool" do
      response = mock('HTTPResponse', :body => two_conference_response)
      account = mock('TwilioAccount', :request => response)
      pool = mock('Pool', :id => 123)
      account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      conferences = @tc.conferences_on_hold_for_pool(pool)
      conferences.should == [{
        "sid"=>"CFXXXaa0e4fe673292932492f68ba94d3f",
        "account_sid"=>"AC2e57bf710b77d765d280786bc07dbacc",
        "friendly_name"=>"HoldEvent4Pool123",
        "status"=>"in-progress",
        "date_created"=>"Thu, 07 Apr 2011 00:02:16 +0000",
        "api_version"=>"Thu, 01 Apr 2010".to_date,
        "date_updated"=>"Thu, 07 Apr 2011 00:02:17 +0000",
        "uri"=>
         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFXXXaa0e4fe673292932492f68ba94d3f.json",
        "subresource_uris"=>
         {"participants"=>
           "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFXXXaa0e4fe673292932492f68ba94d3f/Participants.json"
           }
      }]
    end
    
    describe "participants_on_hold_for_pool" do
      it "works for one participant" do
        response = mock('HTTPResponse')
        response.should_receive(:body).twice.and_return(two_conference_response, participant_response)
        account = mock('TwilioAccount', :request => response)
        pool = mock('Pool', :id => 123)
        participant_url = '/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFXXXaa0e4fe673292932492f68ba94d3f/Participants.json'
        account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
        account.should_receive(:request).with(participant_url, 'GET')
        Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
        participants = @tc.participants_on_hold_for_pool(pool)
        participants.should == [{
          "conference_sid"=>"CF0cb07a25bdaf64828850b784ea2d1aa7",
          "account_sid"=>"AC2e57bf710b77d765d280786bc07dbacc",
          "call_sid"=>"CA9fa67e8696b60ee1ca1e75ec81ef85e7",
          "muted"=>false,
          "end_conference_on_exit"=>false,
          "start_conference_on_enter"=>true,
          "date_created"=>"Wed, 06 Apr 2011 19:10:13 +0000",
          "date_updated"=>"Wed, 06 Apr 2011 19:10:13 +0000",
          "uri"=>
            "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CF0cb07a25bdaf64828850b784ea2d1aa7/Participants/CA9fa67e8696b60ee1ca1e75ec81ef85e7.json"
        }]
      end
    end
  end
  
  describe "place_participant_in_conference" do
    it "has a caller_uri" do
      @tc.caller_uri("Foo").should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/Foo.json"
    end
    
    it "sends the right request" do
      tc = TwilioCaller.new
      tc.should_receive(:twilio_request).with(@tc.caller_uri('CA9fa67e8696b60ee1ca1e75ec81ef85e7'), 'POST', {
        "Url" => "http://www.15minutecalls.com/twilio/place_in_conference.xml?conference=Pool456Room8&timeout=22"
      })
      tc.place_participant_in_conference('CA9fa67e8696b60ee1ca1e75ec81ef85e7', "Pool456Room8", 22)
    end
  end
  
  describe "SMS" do
    it "should have the right URI" do
      @tc.sms_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/SMS/Messages.json"
    end

    it "send_sms" do
      phone_number = '+12223334444'
      text = 'Some random SMS Text'
      response = mock('HTTPResponse')
      response.should_receive(:body).and_return(sms_response)
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(@tc.sms_uri, 'POST', {
        :From => "+14157669865",
        :To   => phone_number,
        :Body => text,
      })
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      rv = @tc.send_sms(phone_number, text)
      rv.should == {
        "dont" => "currently handle this"
      }
    end
  end
end

def sms_response
  '{"dont":"currently handle this"}'
end

def successful_start_call_response
  '{"sid":"CA6be8176371a8a7a096207feff1044b3e","date_created":"Thu, 07 Apr 2011 01:10:50 +0000","date_updated":"Thu, 07 Apr 2011 01:10:50 +0000",' +
  '"parent_call_sid":null,"account_sid":"AC2e57bf710b77d765d280786bc07dbacc","to":"+14153141222","from":"+14157669865","phone_number_sid":' +
  '"PN435c6e6362839f82d08fb3e6848cab84","status":"queued","start_time":null,"end_time":null,"duration":null,"price":null,"direction":"outbound-api",' +
  '"answered_by":null,"api_version":"2010-04-01","annotation":null,"forwarded_from":null,"group_sid":null,"caller_name":null,' + 
  '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Calls\/CA6be8176371a8a7a096207feff1044b3e.json",' + 
  '"subresource_uris":{"notifications":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Calls\/CA6be8176371a8a7a096207feff1044b3e\/Notifications.json"' + 
  ',"recordings":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Calls\/CA6be8176371a8a7a096207feff1044b3e\/Recordings.json"}}'
end

def conference_response
  '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,' +
  '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Status=in-progress",' +
  '"first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
  '"previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
  '"conferences":[{"sid":"CFd69aa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"HoldEvent4Pool1",' +
  '"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000",' +
  '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFd69aa0e4fe673292932492f68ba94d3f.json",' +
  '"subresource_uris":{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
  'CFd69aa0e4fe673292932492f68ba94d3f\/Participants.json"}}]}'
end

def two_conference_response
  '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,' +
  '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Status=in-progress",' +
  '"first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
  '"previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
  '"conferences":[{"sid":"CFd69aa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"HoldEvent123Pool1234",' +
  '"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000",' +
  '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFd69aa0e4fe673292932492f68ba94d3f.json",' +
  '"subresource_uris":{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
  'CFd69aa0e4fe673292932492f68ba94d3f\/Participants.json"}},' +
  '{"sid":"CFXXXaa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"HoldEvent4Pool123"' +
  ',"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000"' +
  ',"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d3f.json"' +
  ',"subresource_uris":' +
  '{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d3f\/Participants.json"}}' +
  ']}'
end

def participant_response
  '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
  'CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json","first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
  'CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json?Page=0&PageSize=50","previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/' +
  'Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json?Page=0&PageSize=50",' +
  '"participants":[{"conference_sid":"CF0cb07a25bdaf64828850b784ea2d1aa7","account_sid":"AC2e57bf710b77d765d280786bc07dbacc",' +
  '"call_sid":"CA9fa67e8696b60ee1ca1e75ec81ef85e7","muted":false,"end_conference_on_exit":false,"start_conference_on_enter":true,' +
  '"date_created":"Wed, 06 Apr 2011 19:10:13 +0000","date_updated":"Wed, 06 Apr 2011 19:10:13 +0000","uri":"\/2010-04-01\/Accounts\/' +
  'AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants\/CA9fa67e8696b60ee1ca1e75ec81ef85e7.json"}]}'
end
