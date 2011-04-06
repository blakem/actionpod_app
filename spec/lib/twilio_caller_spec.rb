require 'spec_helper'

describe TwilioCaller do
  before(:each) do
    @tc = TwilioCaller.new
  end

  describe "Initiating a call" do
    it "should have a start_call_uri" do
      @tc.start_call_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls"
    end
  
    it "should use Twilio::RestAccount to make a call" do
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id)  
      response = mock('HTTPResponse', :body => successful_start_call_response)
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(
        "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls",
        "POST", 
        {"From" => "+14157669865",
         "To"   => user.primary_phone, 
         "Url"  => "http://actionpods.heroku.com/twilio/greeting.xml"
        })
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      expect {
        @tc.start_call_for_event(event)
      }.to change(Call, :count).by(1)
      call = Call.find_by_event_id(event.id)
      call.Sid.should == 'CAd2cccd39bdc7f1b06250c4771a78bf4a'
      call.DateCreated.should == 'Mon, 04 Apr 2011 08:10:37 +0000'
      call.DateUpdated.should == 'Mon, 04 Apr 2011 08:10:37 +0000'
      call.To.should == '+14153141222'
      call.From.should == '+14157669865'
      call.PhoneNumberSid.should == 'PN7bc59ac941fb55880733ef2fe6295477'
      call.Uri.should == '/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CAd2cccd39bdc7f1b06250c4771a78bf4a'
      call.Direction.should == 'outbound-api'
      call.event_id.should == event.id
    end
  end

  describe "Getting information about conferences" do
    it "should have a conferences_in_progress_uri" do
      @tc.conferences_in_progress_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences?Status=in-progress"
    end
  
    it "Can query for zero conferences in progress" do
      response = mock('HTTPResponse', :body => zero_conferences_response)
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      conferences = @tc.conferences_in_progress
      conferences.should == []
    end

    it "Can query for one conference in progress" do
      response = mock('HTTPResponse', :body => one_conference_response)
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      conferences = @tc.conferences_in_progress
      conferences.should == [{
        "Sid"=>"CFc99129d1af6c8f04aa03962e9f66a0b8",
        "AccountSid"=>"AC2e57bf710b77d765d280786bc07dbacc",
        "FriendlyName"=>"MyRoom",
        "Status"=>"in-progress",
        "DateCreated"=>"Wed, 06 Apr 2011 01:19:54 +0000",
        "ApiVersion"=>"2010-04-01",
        "DateUpdated"=>"Wed, 06 Apr 2011 01:19:54 +0000",
        "Uri"=>
         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8",
        "SubresourceUris"=>
        {"Participants"=>
         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8/Participants"}
      }]
    end

    it "Can query for multiple conference in progress" do
      response = mock('HTTPResponse', :body => two_conference_response)
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      conferences = @tc.conferences_in_progress
      conferences.should == [{
        "Sid"=>"CFc99129d1af6c8f04aa03962e9f66a0b8",
        "AccountSid"=>"AC2e57bf710b77d765d280786bc07dbacc",
        "FriendlyName"=>"HoldEvent345Pool123",
        "Status"=>"completed",
        "DateCreated"=>"Wed, 06 Apr 2011 01:19:54 +0000",
        "ApiVersion"=>"2010-04-01",
        "DateUpdated"=>"Wed, 06 Apr 2011 01:20:01 +0000",
        "Uri"=>
         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8",
        "SubresourceUris"=>
         {"Participants"=>
           "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8/Participants"}},
       {"Sid"=>"CF4216d8a56720d7ad2b8c1f5dde920b06",
        "AccountSid"=>"AC2e57bf710b77d765d280786bc07dbacc",
        "FriendlyName"=>"HoldEvent455Pool1234",
        "Status"=>"completed",
        "DateCreated"=>"Wed, 06 Apr 2011 01:04:24 +0000",
        "ApiVersion"=>"2010-04-01",
        "DateUpdated"=>"Wed, 06 Apr 2011 01:04:38 +0000",
        "Uri"=>
         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CF4216d8a56720d7ad2b8c1f5dde920b06",
        "SubresourceUris"=>
         {"Participants"=>
           "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CF4216d8a56720d7ad2b8c1f5dde920b06/Participants"}
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
        "Sid"=>"CFc99129d1af6c8f04aa03962e9f66a0b8",
        "AccountSid"=>"AC2e57bf710b77d765d280786bc07dbacc",
        "FriendlyName"=>"HoldEvent345Pool123",
        "Status"=>"completed",
        "DateCreated"=>"Wed, 06 Apr 2011 01:19:54 +0000",
        "ApiVersion"=>"2010-04-01",
        "DateUpdated"=>"Wed, 06 Apr 2011 01:20:01 +0000",
        "Uri"=>
         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8",
        "SubresourceUris"=>
         {"Participants"=>
           "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8/Participants"}
      }]
    end
  end
end

def successful_start_call_response
  '<TwilioResponse><Call><Sid>CAd2cccd39bdc7f1b06250c4771a78bf4a</Sid><DateCreated>Mon, 04 Apr 2011 08:10:37 +0000</DateCreated><DateUpdated>' +
  'Mon, 04 Apr 2011 08:10:37 +0000</DateUpdated><ParentCallSid/><AccountSid>AC2e57bf710b77d765d280786bc07dbacc</AccountSid><To>+14153141222</To>' +
  '<From>+14157669865</From><PhoneNumberSid>PN7bc59ac941fb55880733ef2fe6295477</PhoneNumberSid><Status>queued</Status><StartTime/><EndTime/>' +
  '<Duration/><Price/><Direction>outbound-api</Direction><AnsweredBy/><ApiVersion>2010-04-01</ApiVersion><Annotation/><ForwardedFrom/><GroupSid/>' +
  '<CallerName/><Uri>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CAd2cccd39bdc7f1b06250c4771a78bf4a</Uri><SubresourceUris>' +
  '<Notifications>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CAd2cccd39bdc7f1b06250c4771a78bf4a/Notifications</Notifications>' +
  '<Recordings>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CAd2cccd39bdc7f1b06250c4771a78bf4a/Recordings</Recordings>' +
  '</SubresourceUris></Call></TwilioResponse>'
end

def zero_conferences_response
  '<?xml version="1.0"?>
  <TwilioResponse><Conferences page="0" numpages="0" pagesize="50" total="0" start="0" end="0" ' +
  'uri="/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences?Status=in-progress" firstpageuri="" previouspageuri=""' +
  ' nextpageuri="" lastpageuri=""/></TwilioResponse>'
end

def one_conference_response
  '<?xml version="1.0"?>
  <TwilioResponse><Conferences page="0" numpages="1" pagesize="50" total="1" start="0" end="0" ' + 
  'uri="/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences?Status=in-progress" ' +
  'firstpageuri="/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences?Page=0&amp;PageSize=50" previouspageuri="" nextpageuri="" ' +
  'lastpageuri="/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences?Page=0&amp;PageSize=50">' + 
  '<Conference><Sid>CFc99129d1af6c8f04aa03962e9f66a0b8</Sid><AccountSid>AC2e57bf710b77d765d280786bc07dbacc</AccountSid>' + 
  '<FriendlyName>MyRoom</FriendlyName><Status>in-progress</Status><DateCreated>Wed, 06 Apr 2011 01:19:54 +0000</DateCreated>' +
  '<ApiVersion>2010-04-01</ApiVersion><DateUpdated>Wed, 06 Apr 2011 01:19:54 +0000</DateUpdated>' + 
  '<Uri>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8</Uri>' +
  '<SubresourceUris><Participants>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8/Participants' +
  '</Participants></SubresourceUris></Conference></Conferences></TwilioResponse>'
end

def two_conference_response
  '<?xml version="1.0"?>' +
  '<TwilioResponse><Conferences page="0" numpages="1" pagesize="50" total="27" start="0" end="26" ' +
  'uri="/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences" ' +
  'firstpageuri="/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences?Page=0&amp;PageSize=50" ' +
  'previouspageuri="" nextpageuri="" lastpageuri="/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences?Page=0&amp;PageSize=50">' +
  '<Conference><Sid>CFc99129d1af6c8f04aa03962e9f66a0b8</Sid><AccountSid>AC2e57bf710b77d765d280786bc07dbacc</AccountSid><FriendlyName>HoldEvent345Pool123</FriendlyName>' + 
  '<Status>completed</Status><DateCreated>Wed, 06 Apr 2011 01:19:54 +0000</DateCreated><ApiVersion>2010-04-01</ApiVersion><DateUpdated>' +
  'Wed, 06 Apr 2011 01:20:01 +0000</DateUpdated><Uri>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8' +
  '</Uri><SubresourceUris><Participants>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFc99129d1af6c8f04aa03962e9f66a0b8/Participants' +
  '</Participants></SubresourceUris></Conference><Conference><Sid>CF4216d8a56720d7ad2b8c1f5dde920b06</Sid><AccountSid>AC2e57bf710b77d765d280786bc07dbacc' + 
  '</AccountSid><FriendlyName>HoldEvent455Pool1234</FriendlyName><Status>completed</Status><DateCreated>Wed, 06 Apr 2011 01:04:24 +0000</DateCreated><ApiVersion>' +
  '2010-04-01</ApiVersion><DateUpdated>Wed, 06 Apr 2011 01:04:38 +0000</DateUpdated><Uri>' +
  '/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CF4216d8a56720d7ad2b8c1f5dde920b06</Uri><SubresourceUris>' +
  '<Participants>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CF4216d8a56720d7ad2b8c1f5dde920b06/Participants' + 
  '</Participants></SubresourceUris></Conference></Conferences></TwilioResponse>'
end