require 'spec_helper'

describe TropoCaller do
  before(:each) do
    @tc = TropoCaller.new
  end

  describe "post_to_tropo" do

    it "sends a post to tropo" do
      url = 'http://example.org'
      args = {'foo' => 'bar'}
      Net::HTTP.should_receive(:post_form).with(URI.parse(url), args)
      @tc.post_to_tropo(url, args)
    end
  end
  
  describe "start_call_for_event" do
    it "should start a call" do
      event = Factory(:event)
      @tc.should_receive(:post_to_tropo).with('http://api.tropo.com/1.0/sessions', {
        :action   => "create", 
        :token    => "04387300635ebe4cbc820020e5354055a8c4e24f72e407d1159abc03aa6a2a88896146fb9131e1804bae5736", 
        :event_id => event.id,
      })
      @tc.start_call_for_event(event)
    end
  end
  
  describe "place_participant_in_conference" do
    it "should update the call_session and put a participant into a conference" do
      event = Factory(:event)
      call_session = CallSession.create(
        :session_id => 'session_1_id',
        :event_id => event.id,
        :user_id => event.user_id,
        :pool_id => event.pool_id,
        :call_state => 'on_hold',
      )
      @tc.should_receive(:post_to_tropo).with('http://api.tropo.com/1.0/sessions/session_1_id/signals', {
        :value=>"placed"
      })
      @tc.place_participant_in_conference(
        call_session.session_id,
        "ConferenceName",
        900,
        event.id,
        [6, 7, 8],
      )
      call_session.reload
      call_session.conference_name.should == 'ConferenceName'
      call_session.timelimit.should == 900
      call_session.event_ids.should == '6,7,8'
      call_session.call_state.should == 'placing'
    end
  end
end



    
#     describe "HTTP Errors" do
# 
#       it "retries after an error from tropo" do
#         response1 = mock('HTTPResponse')
#         response1.should_receive(:kind_of?).twice.and_return(false)
#         response2 = mock('HTTPResponse', :body => '{"foo":"bar"}', :responds_to? => true)
#         response2.should_not_receive(:kind_of?)
#         account = mock('TropoAccount')
#         account.should_receive(:request).with('http://foo.com', 'POST').and_return(response1, response2)
#         Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#         @tc.should_receive('send_error_to_blake').with("Retrying tropo_request: ResponseCode:#{response1.class}")
#         hash = @tc.tropo_request('http://foo.com', 'POST')
#         hash.should == {"foo" =>"bar"}
#       end
# 
#       it "two errors in a row" do
#         response = mock('HTTPResponse')
#         response.should_receive(:kind_of?).twice.and_return(false)
#         account = mock('TropoAccount')
#         account.should_receive(:request).twice.with('http://foo.com', 'POST').and_return(response)
#         Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#         @tc.should_receive('send_error_to_blake').with("Retrying tropo_request: ResponseCode:#{response.class}")
#         @tc.should_receive('send_error_to_blake').with("Fatal tropo_request not retrying: ResponseCode:#{response.class}")
#         hash = @tc.tropo_request('http://foo.com', 'POST')
#         hash.should == {}
#       end
#     end
# 
#     describe "num_pages" do
# 
#       it "no warning if num_pages = 0" do
#         response = mock('HTTPResponse', :body => '{"num_pages":"0"}')
#         response.should_receive(:kind_of?).and_return(true)
#         account = mock('TropoAccount')
#         account.should_receive(:request).with('http://foo.com', 'POST').and_return(response)
#         Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#         @tc.should_not_receive('send_error_to_blake')
#         hash = @tc.tropo_request('http://foo.com', 'POST')
#         hash.should == {"num_pages" => "0"}
#       end
#     
#       it "no warning if num_pages = 1" do
#         response = mock('HTTPResponse', :body => '{"num_pages":"1"}')
#         response.should_receive(:kind_of?).and_return(true)
#         account = mock('TropoAccount')
#         account.should_receive(:request).with('http://foo.com', 'POST').and_return(response)
#         Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#         @tc.should_not_receive('send_error_to_blake')
#         hash = @tc.tropo_request('http://foo.com', 'POST')
#         hash.should == {"num_pages" => "1"}
#       end
# 
#       it "sends me a warning if num_pages > 1" do
#         response = mock('HTTPResponse', :body => '{"num_pages":"2"}')
#         response.should_receive(:kind_of?).and_return(true)
#         account = mock('TropoAccount')
#         account.should_receive(:request).with('http://foo.com', 'POST').and_return(response)
#         Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#         @tc.should_receive('send_error_to_blake').with("WARNING: GOT A RESPONSE THAT NEED TO BE PAGED: 2")
#         hash = @tc.tropo_request('http://foo.com', 'POST')
#         hash.should == {"num_pages" => "2"}
#       end
#     end
#   end
# 
#   describe "Initiating a call" do
#     it "should have a start_call_uri" do
#       @tc.start_call_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls.json"
#     end
#   
#     it "should use Tropo::RestAccount to make a call" do
#       user = Factory(:user)
#       phone = Factory(:phone, :user_id => user.id, :primary => true)
#       event = Factory(:event, :user_id => user.id)  
#       response = mock('HTTPResponse', :body => successful_start_call_response)
#       account = mock('TropoAccount', :request => response)
#       account.should_receive(:request).with(
#         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls.json",
#         "POST", 
#         {"From"           => "+14157669865",
#          "To"             => user.primary_phone.number, 
#          "Url"            => "http://www.15minutecalls.com/tropo/greeting.xml",
#          "FallbackUrl"    => "http://www.15minutecalls.com/tropo/greeting_fallback.xml", 
#          "StatusCallback" => "http://www.15minutecalls.com/tropo/callback.xml",
#         })
#       Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#       expect {
#         @tc.start_call_for_event(event)
#       }.to change(Call, :count).by(1)
#       call = Call.find_by_event_id(event.id)
#       call.Sid.should == 'CA6be8176371a8a7a096207feff1044b3e'
#       call.DateCreated.should == 'Thu, 07 Apr 2011 01:10:50 +0000'
#       call.DateUpdated.should == 'Thu, 07 Apr 2011 01:10:50 +0000'
#       call.To.should == '+14153141222'
#       call.From.should == '+14157669865'
#       call.PhoneNumberSid.should == 'PN435c6e6362839f82d08fb3e6848cab84'
#       call.Uri.should == '/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/CA6be8176371a8a7a096207feff1044b3e.json'
#       call.Direction.should == 'outbound-api'
#       call.event_id.should == event.id
#       call.user_id.should == user.id
#     end
# 
#     it "should go straight to put_on_hold if user has use_ifmachine set" do
#       user = Factory(:user)
#       phone = Factory(:phone, :user_id => user.id, :primary => true)
#       user.use_ifmachine = true
#       user.save
#       event = Factory(:event, :user_id => user.id)  
#       response = mock('HTTPResponse', :body => successful_start_call_response)
#       account = mock('TropoAccount', :request => response)
#       account.should_receive(:request).with(
#         "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls.json",
#         "POST", 
#         {"From"           => "+14157669865",
#          "To"             => user.primary_phone.number, 
#          "Url"            => "http://www.15minutecalls.com/tropo/go_directly_to_conference.xml",
#          "IfMachine"      => "Hangup",
#          "FallbackUrl"    => "http://www.15minutecalls.com/tropo/greeting_fallback.xml", 
#          "StatusCallback" => "http://www.15minutecalls.com/tropo/callback.xml",
#         })
#       Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#       expect {
#         @tc.start_call_for_event(event)
#       }.to change(Call, :count).by(1)
#     end
#   end
# 
#   describe "Getting information about conferences" do
#     it "should have a conferences_in_progress_uri" do
#       @tc.conferences_in_progress_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences.json?Status=in-progress"
#     end
#   
#     it "conferences_in_progress" do
#       response = mock('HTTPResponse', :body => conference_response)
#       account = mock('TropoAccount', :request => response)
#       account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
#       Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#       conferences = @tc.conferences_in_progress
#       conferences.should == [{
#         "sid"=>"CFd69aa0e4fe673292932492f68ba94d3f",
#         "account_sid"=>"AC2e57bf710b77d765d280786bc07dbacc",
#         "friendly_name"=>"15mcHoldEvent4User7Pool1",
#         "status"=>"in-progress",
#         "date_created"=>"Thu, 07 Apr 2011 00:02:16 +0000",
#         "api_version"=>"Thu, 01 Apr 2010".to_date,
#         "date_updated"=>"Thu, 07 Apr 2011 00:02:17 +0000",
#         "uri"=>
#          "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFd69aa0e4fe673292932492f68ba94d3f.json",
#         "subresource_uris"=>
#          {"participants"=>
#            "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFd69aa0e4fe673292932492f68ba94d3f/Participants.json"
#            }
#       }]
#     end
# 
#     it "conferences_on_hold_for_pool" do
#       response = mock('HTTPResponse', :body => four_conference_response)
#       account = mock('TropoAccount', :request => response)
#       pool = mock('Pool', :id => 123)
#       account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
#       Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#       conferences = @tc.conferences_on_hold_for_pool(pool)
#       conferences.should == [{
#         "sid"=>"CFXXXaa0e4fe673292932492f68ba94d3f",
#         "account_sid"=>"AC2e57bf710b77d765d280786bc07dbacc",
#         "friendly_name"=>"15mcHoldEvent4User7Pool123Incoming",
#         "status"=>"in-progress",
#         "date_created"=>"Thu, 07 Apr 2011 00:02:16 +0000",
#         "api_version"=>"Thu, 01 Apr 2010".to_date,
#         "date_updated"=>"Thu, 07 Apr 2011 00:02:17 +0000",
#         "uri"=>
#           "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFXXXaa0e4fe673292932492f68ba94d3f.json",
#         "subresource_uris"=>
#          {"participants"=>
#            "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFXXXaa0e4fe673292932492f68ba94d3f/Participants.json"
#            }
#         },{
#           "sid"=>"CFXXXaa0e4fe673292932492f68ba94d35",
#           "account_sid"=>"AC2e57bf710b77d765d280786bc07dbacc",
#           "friendly_name"=>"15mcHoldEvent5User7Pool123",
#           "status"=>"in-progress",
#           "date_created"=>"Thu, 07 Apr 2011 00:02:16 +0000",
#           "api_version"=>"Thu, 01 Apr 2010".to_date,
#           "date_updated"=>"Thu, 07 Apr 2011 00:02:17 +0000",
#           "uri"=>
#             "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFXXXaa0e4fe673292932492f68ba94d35.json",
#           "subresource_uris"=>
#           {"participants"=>
#             "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFXXXaa0e4fe673292932492f68ba94d35/Participants.json"}
#         }]
#     end
#     
#     describe "participants_on_hold_for_pool" do
#       it "works for one participant" do
#         response = mock('HTTPResponse')
#         response.should_receive(:body).twice.and_return(two_conference_response, participant_response)
#         account = mock('TropoAccount', :request => response)
#         pool = mock('Pool', :id => 123)
#         participant_url = '/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CFXXXaa0e4fe673292932492f68ba94d3f/Participants.json'
#         account.should_receive(:request).with(@tc.conferences_in_progress_uri, 'GET')
#         account.should_receive(:request).with(participant_url, 'GET')
#         Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#         participants = @tc.participants_on_hold_for_pool(pool)
#         participants.should == [{
#           "conference_sid"=>"CF0cb07a25bdaf64828850b784ea2d1aa7",
#           "conference_friendly_name"=>"15mcHoldEvent4User7Pool123Incoming",
#           "account_sid"=>"AC2e57bf710b77d765d280786bc07dbacc",
#           "call_sid"=>"CA9fa67e8696b60ee1ca1e75ec81ef85e7",
#           "muted"=>false,
#           "end_conference_on_exit"=>false,
#           "start_conference_on_enter"=>true,
#           "date_created"=>"Wed, 06 Apr 2011 19:10:13 +0000",
#           "date_updated"=>"Wed, 06 Apr 2011 19:10:13 +0000",
#           "uri"=>
#             "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Conferences/CF0cb07a25bdaf64828850b784ea2d1aa7/Participants/CA9fa67e8696b60ee1ca1e75ec81ef85e7.json"
#         }]
#       end
#     end
#   end
#   
#   describe "place_participant_in_conference" do
#     it "has a caller_uri" do
#       @tc.caller_uri("Foo").should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/Calls/Foo.json"
#     end
#     
#     it "sends the right request" do
#       tc = TropoCaller.new
#       tc.should_receive(:tropo_request).with(@tc.caller_uri('CA9fa67e8696b60ee1ca1e75ec81ef85e7'), 'POST', {
#         "Url" => "http://www.15minutecalls.com/tropo/place_in_conference.xml?conference=15mcPool456Room8&timelimit=22&events=&event=89"
#       })
#       tc.place_participant_in_conference('CA9fa67e8696b60ee1ca1e75ec81ef85e7', "15mcPool456Room8", 22, 89, [])
#     end
# 
#     it "sends the event ids to the url" do
#       call = Call.create(:Sid => 'CA9fa67e8696b60ee1ca1e75ec81ef85e7', :status => 'incoming-onhold')
#       tc = TropoCaller.new
#       tc.should_receive(:tropo_request).with(@tc.caller_uri('CA9fa67e8696b60ee1ca1e75ec81ef85e7'), 'POST', {
#         "Url" => "http://www.15minutecalls.com/tropo/place_in_conference.xml?conference=15mcPool456Room8&timelimit=22&events=3,4,5&event=91"
#       })
#       tc.place_participant_in_conference('CA9fa67e8696b60ee1ca1e75ec81ef85e7', "15mcPool456Room8", 22, 91, [3,4,5])
#       call.reload
#       call.status.should == 'incoming-onhold-placing:15mcPool456Room8'
#     end
#   end
#   
#   describe "apologize_no_other_participants" do
#     it "sends the right request" do
#       call = Call.create(:Sid => 'CA9fa67e8696b60ee1ca1e75ec81ef85e7', :status => 'incoming-onhold')
#       tc = TropoCaller.new
#       tc.should_receive(:tropo_request).with(@tc.caller_uri('CA9fa67e8696b60ee1ca1e75ec81ef85e7'), 'POST', {
#         "Url" => "http://www.15minutecalls.com/tropo/apologize_no_other_participants.xml?participant_count=3&event=223"
#       })
#       tc.apologize_no_other_participants('CA9fa67e8696b60ee1ca1e75ec81ef85e7', 223, 3)
#       call.reload
#       call.status.should == 'incoming-onhold-apologizing'
#     end
#   end
# 
#   describe "SMS" do
#     it "should have the right URI" do
#       @tc.sms_uri.should == "/2010-04-01/Accounts/AC2e57bf710b77d765d280786bc07dbacc/SMS/Messages.json"
#     end
# 
#     it "send_sms" do
#       phone_number = '+12223334444'
#       text = 'Some random SMS Text'
#       response = mock('HTTPResponse')
#       response.should_receive(:body).and_return(sms_response)
#       account = mock('TropoAccount', :request => response)
#       account.should_receive(:request).with(@tc.sms_uri, 'POST', {
#         :From => "+14157669865",
#         :To   => phone_number,
#         :Body => text,
#       })
#       Tropo::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
#       rv = @tc.send_sms(phone_number, text)
#       rv.should == {
#         "dont" => "currently handle this"
#       }
#     end
# 
#     it "send_error_to_blake" do
#       tc = TropoCaller.new
#       tc.should_receive(:send_sms).with('+14153141222', "Error Message")
#       tc.send_error_to_blake("Error Message")
#     end
#   end
# end
# 
# def sms_response
#   '{"dont":"currently handle this"}'
# end
# 
# def successful_start_call_response
#   '{"sid":"CA6be8176371a8a7a096207feff1044b3e","date_created":"Thu, 07 Apr 2011 01:10:50 +0000","date_updated":"Thu, 07 Apr 2011 01:10:50 +0000",' +
#   '"parent_call_sid":null,"account_sid":"AC2e57bf710b77d765d280786bc07dbacc","to":"+14153141222","from":"+14157669865","phone_number_sid":' +
#   '"PN435c6e6362839f82d08fb3e6848cab84","status":"queued","start_time":null,"end_time":null,"duration":null,"price":null,"direction":"outbound-api",' +
#   '"answered_by":null,"api_version":"2010-04-01","annotation":null,"forwarded_from":null,"group_sid":null,"caller_name":null,' + 
#   '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Calls\/CA6be8176371a8a7a096207feff1044b3e.json",' + 
#   '"subresource_uris":{"notifications":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Calls\/CA6be8176371a8a7a096207feff1044b3e\/Notifications.json"' + 
#   ',"recordings":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Calls\/CA6be8176371a8a7a096207feff1044b3e\/Recordings.json"}}'
# end
# 
# def conference_response
#   '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,' +
#   '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Status=in-progress",' +
#   '"first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
#   '"previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
#   '"conferences":[{"sid":"CFd69aa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"15mcHoldEvent4User7Pool1",' +
#   '"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000",' +
#   '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFd69aa0e4fe673292932492f68ba94d3f.json",' +
#   '"subresource_uris":{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
#   'CFd69aa0e4fe673292932492f68ba94d3f\/Participants.json"}}]}'
# end
# 
# def two_conference_response
#   '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,' +
#   '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Status=in-progress",' +
#   '"first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
#   '"previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
#   '"conferences":[{"sid":"CFd69aa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"15mcHoldEvent123User7Pool1234Incoming",' +
#   '"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000",' +
#   '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFd69aa0e4fe673292932492f68ba94d3f.json",' +
#   '"subresource_uris":{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
#   'CFd69aa0e4fe673292932492f68ba94d3f\/Participants.json"}},' +
#   '{"sid":"CFXXXaa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"15mcHoldEvent4User7Pool123Incoming"' +
#   ',"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000"' +
#   ',"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d3f.json"' +
#   ',"subresource_uris":' +
#   '{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d3f\/Participants.json"}}' +
#   ']}'
# end
# 
# def four_conference_response
#   '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,' +
#   '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Status=in-progress",' +
#   '"first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
#   '"previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences.json?Page=0&PageSize=50",' +
#   '"conferences":[{"sid":"CFd69aa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"15mcHoldEvent123User7Pool1234Incoming",' +
#   '"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000",' +
#   '"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFd69aa0e4fe673292932492f68ba94d3f.json",' +
#   '"subresource_uris":{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
#   'CFd69aa0e4fe673292932492f68ba94d3f\/Participants.json"}},' +
#   '{"sid":"CFXXXaa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"15mcHoldEvent4User7Pool123Incoming"' +
#   ',"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000"' +
#   ',"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d3f.json"' +
#   ',"subresource_uris":' +
#   '{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d3f\/Participants.json"}},' +
#   '{"sid":"CFXXXaa0e4fe673292932492f68ba94d3f","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"15mcPool123Room6"' +
#   ',"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000"' +
#   ',"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d3f.json"' +
#   ',"subresource_uris":' +
#   '{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d3f\/Participants.json"}},' +
#   '{"sid":"CFXXXaa0e4fe673292932492f68ba94d35","account_sid":"AC2e57bf710b77d765d280786bc07dbacc","friendly_name":"15mcHoldEvent5User7Pool123"' +
#   ',"status":"in-progress","date_created":"Thu, 07 Apr 2011 00:02:16 +0000","api_version":"2010-04-01","date_updated":"Thu, 07 Apr 2011 00:02:17 +0000"' +
#   ',"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d35.json"' +
#   ',"subresource_uris":' +
#   '{"participants":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CFXXXaa0e4fe673292932492f68ba94d35\/Participants.json"}}' +
#   ']}'
# end
# 
# def participant_response
#   '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
#   'CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json","first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
#   'CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json?Page=0&PageSize=50","previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/' +
#   'Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json?Page=0&PageSize=50",' +
#   '"participants":[{"conference_sid":"CF0cb07a25bdaf64828850b784ea2d1aa7","account_sid":"AC2e57bf710b77d765d280786bc07dbacc",' +
#   '"call_sid":"CA9fa67e8696b60ee1ca1e75ec81ef85e7","muted":false,"end_conference_on_exit":false,"start_conference_on_enter":true,' +
#   '"date_created":"Wed, 06 Apr 2011 19:10:13 +0000","date_updated":"Wed, 06 Apr 2011 19:10:13 +0000","uri":"\/2010-04-01\/Accounts\/' +
#   'AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants\/CA9fa67e8696b60ee1ca1e75ec81ef85e7.json"}]}'
# end
