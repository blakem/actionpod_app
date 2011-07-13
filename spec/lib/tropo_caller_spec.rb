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

  describe "start_call_for_user" do
    it "should start a call" do
      user = Factory(:user)
      @tc.should_receive(:post_to_tropo).with('http://api.tropo.com/1.0/sessions', {
        :action   => "create", 
        :token    => "04387300635ebe4cbc820020e5354055a8c4e24f72e407d1159abc03aa6a2a88896146fb9131e1804bae5736", 
        :user_id => user.id,
      })
      @tc.start_call_for_user(user)
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
        :call_state => 'onhold',
      )
      @tc.should_receive(:post_to_tropo).with('http://api.tropo.com/1.0/sessions/session_1_id/signals', {
        :value => "placed"
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

  describe "place_participant_in_conference" do
    it "should update the call and call_session and apologize to the participant" do
      event = Factory(:event)
      call = Call.create(
        :status => 'foo',
        :Sid => 'xyabc',
      )
      call_session = CallSession.create(
        :session_id => 'session_1_id',
        :event_id => event.id,
        :user_id => event.user_id,
        :pool_id => event.pool_id,
        :call_state => 'onhold',
        :call_id => call.Sid,
      )
      @tc.should_receive(:post_to_tropo).with('http://api.tropo.com/1.0/sessions/session_1_id/signals', {
        :value => "apologize"
      })
      @tc.apologize_no_other_participants(
        call_session.session_id,
        6,
      )
      call_session.reload
      call_session.participant_count.should == 6
      call.reload
      call.status.should == 'foo-apologizing'
    end
  end
end
