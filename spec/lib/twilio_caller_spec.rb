require 'spec_helper'

describe TwilioCaller do
  before(:each) do
    @tc = TwilioCaller.new
  end

  it "should have a start_call_uri" do
    @tc.start_call_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls"
  end
  
  it "should use Twilio::RestAccount to make a call" do
    user = Factory(:user)
    event = Factory(:event, :user_id => user.id)  
    response = mock('HTTPResponse', :body => successful_response)
    account = mock('TwilioAccount', :request => response)
    account.should_receive(:request).with(
      "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls",
      "POST", 
      {"From" => "415-314-1222", 
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
    call.From.should == '+14153141222'
    call.PhoneNumberSid.should == 'PN7bc59ac941fb55880733ef2fe6295477'
    call.Uri.should == '/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CAd2cccd39bdc7f1b06250c4771a78bf4a'
    call.event_id.should == event.id
  end
end

def successful_response
  '<TwilioResponse><Call><Sid>CAd2cccd39bdc7f1b06250c4771a78bf4a</Sid><DateCreated>Mon, 04 Apr 2011 08:10:37 +0000</DateCreated><DateUpdated>' +
  'Mon, 04 Apr 2011 08:10:37 +0000</DateUpdated><ParentCallSid/><AccountSid>AC2e57bf710b77d765d280786bc07dbacc</AccountSid><To>+14153141222</To>' +
  '<From>+14153141222</From><PhoneNumberSid>PN7bc59ac941fb55880733ef2fe6295477</PhoneNumberSid><Status>queued</Status><StartTime/><EndTime/>' +
  '<Duration/><Price/><Direction>outbound-api</Direction><AnsweredBy/><ApiVersion>2010-04-01</ApiVersion><Annotation/><ForwardedFrom/><GroupSid/>' +
  '<CallerName/><Uri>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CAd2cccd39bdc7f1b06250c4771a78bf4a</Uri><SubresourceUris>' +
  '<Notifications>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CAd2cccd39bdc7f1b06250c4771a78bf4a/Notifications</Notifications>' +
  '<Recordings>/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CAd2cccd39bdc7f1b06250c4771a78bf4a/Recordings</Recordings>' +
  '</SubresourceUris></Call></TwilioResponse>'
end