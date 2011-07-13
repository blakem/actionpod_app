require 'spec_helper'

describe TropoController do

  describe "tropo" do
    describe "outgoing calls" do
      it "should initiate a call" do
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        event = Factory(:event, :user_id => user.id)
        post :tropo, tropo_outgoing_session_data(event)
        parse_response(response).should == {
          "tropo" => [{
            "on" => {"event" => "hangup", "next" => "/tropo/callback.json"},
          }, {
            "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
          }, {
            "on" => {"event" => "continue", "next"=> "/tropo/greeting.json"},
          }, {
            "call" => {"to" => user.primary_phone.number , "from" => "+14157660881"}
          }]
        }
        call_session = CallSession.where(
          :user_id => user.id,
          :event_id => event.id,
          :pool_id => event.pool_id,
        ).first
        call_session.direction.should == 'outbound'
        call_session.call_id.should be_nil
        call_session.session_id.should == tropo_session_id
        call_session.call_state.should == 'calling'
        call = Call.where(
          :event_id => event.id,
          :user_id => user.id,
        ).first
        call.Direction.should == 'outbound'
        call.status.should == 'outgoing'
        call.session_id.should == tropo_session_id
        call.From.should == '+14157660881'
        call.To.should == phone.number
        call.DateCreated.should =~ /^201\d-/
        call.DateUpdated.should =~ /^201\d-/
      end

      it "Don't crash on empty data" do
        post :tropo
        response.should be_success
        parse_response(response).should == {
          "tropo" => [{
            "on" => {"event" => "hangup", "next" => "/tropo/callback.json"}
          }, {
            "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
          }]
        }
      end
    end
    
    describe "incoming calls" do
      it "should send them to put_on_hold" do
        user = Factory(:user, :incoming_count => 7)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        event = Factory(:event, :user_id => user.id)
        post :tropo, tropo_incoming_session_data(event)
        parse_response(response).should == {
          "tropo" => [{
            "on" => {"event" => "hangup", "next" => "/tropo/callback.json"},
          }, {
            "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
          }, {
            "say" => [{
              "value"=>"Welcome to your #{event.name_in_second_person}.", "voice"=>"dave"
            }]
          }, {
            "on" => {"event"=>"continue", "next"=>"/tropo/put_on_hold.json"}
          }]
        }
        call_session = CallSession.where(
          :user_id => user.id,
          :event_id => event.id,
          :pool_id => event.pool_id,
        ).first
        call_session.direction.should == 'inbound'
        call_session.call_id.should == 'fad6a6decb25ebee3bf508fb1c05813d'
        call_session.session_id.should == tropo_session_id
        call_session.call_state.should == 'inbound'
        call = Call.where(
          :event_id => event.id,
          :user_id => user.id,
        ).first
        call.Direction.should == 'inbound'
        call.Sid.should == tropo_call_id
        call.DateCreated.should == '2011-06-23 23:41:29 UTC'
        call.DateUpdated.should == '2011-06-23 23:41:29 UTC'
        call.To.should == '+14157660881'
        call.From.should == phone.number
        call.AnsweredBy.should == 'HUMAN'
        call.session_id.should == tropo_session_id
        call.status.should == 'inbound'
        user.reload
        user.incoming_count.should == 8
      end      

      it "should match up with the event being called" do
        CallSession.all.each {|cs| cs.destroy}
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)

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

        post :tropo, tropo_incoming_session_data(event1)
        parse_response(response).should == {
          "tropo" => [
            { "on"  => {"event"  => "hangup", "next" => "/tropo/callback.json"}},
            { "on"  => {"event"  => "error",  "next" => "/tropo/callback.json"}},
            { "say" => [{"value" => "Welcome to your Bit After Morning Call.", "voice"=>"dave"}]},
            { "on"  => {"event"  => "continue", "next" => "/tropo/put_on_hold.json"}}
          ]
        }

        CallSession.all.each {|cs| cs.destroy}
        event2.time = (now + 13.minutes).strftime("%I:%M%p")
        event2.save
        post :tropo, tropo_incoming_session_data(event1)
        parse_response(response).should == {
          "tropo" => [
            { "on"  => {"event"  => "hangup", "next" => "/tropo/callback.json"}},
            { "on"  => {"event"  => "error",  "next" => "/tropo/callback.json"}},
            { "say" => [{"value" => "Welcome to your Bit Before Morning Call.", "voice"=>"dave"}]},
            { "on"  => {"event"  => "continue", "next" => "/tropo/put_on_hold.json"}}
          ]
        }
      end

      it "should match up with a previous (i.e. one that's schedule every week on yesterday) call if he's not schedule for one today" do
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)

        now = Time.now.in_time_zone(user.time_zone)
        event1 = Factory(:event, :user_id => user.id, :name => 'Yesterdays Call', :pool_id => Factory(:pool).id)
        event1.days = [ (now.strftime("%w").to_i + 8) % 7 ] 
        event1.time = '8am'
        event1.save

        post :tropo, tropo_incoming_session_data(event1)
        parse_response(response).should == {
          "tropo" => [
            { "on"  => {"event"  => "hangup", "next" => "/tropo/callback.json"}},
            { "on"  => {"event"  => "error",  "next" => "/tropo/callback.json"}},
            { "say" => [{"value" => "Welcome to your Yesterdays Call.", "voice"=>"dave"}]},
            { "on"  => {"event"  => "continue", "next" => "/tropo/put_on_hold.json"}}
          ]
        }
      end

    end
  end

  describe "greeting" do
 
    it "Should put the user on hold" do
      event = Factory(:event)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :event_id => event.id,
        :user_id => event.user_id,
        :pool_id => event.pool_id,
        :call_state => 'calling'
      )
      call = Call.create(
        :session_id => tropo_session_id,
        :status => 'foo',
      )
      post :greeting, tropo_greeting_session_data(event)
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup",     "next" => "/tropo/callback.json"},
        }, {
          "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
        }, {
          "on"  => {"event" => "continue",   "next" => "/tropo/put_on_hold.json"},
        }, {
          "on"  => {"event" => "incomplete", "next" => "/tropo/no_keypress.json"},
        }, {
          "ask" => {
            "name"    => "signin",
            "bargein" => true,
            "timeout" => 8,
            "required" => "true",
            "voice"   => "dave",
            "choices" => {"value"=>"[1 DIGIT]", "mode" => "dtmf"},
            "say" => [{
              "value" => "Welcome to your #{event.name_in_second_person}. Press 1 to join the conference.",
              "voice" => "dave"
            }],
          }
        }]
      }
      call_session.reload
      call_session.call_state.should == 'waiting_for_input'
      call.reload
      call.status.should == 'foo-greeting'
      call.Sid.should == '05d684fae36493f9ecb452c85e90b369'
    end
  end

  describe "no_keypress" do
    it "Should tell them to call back" do
      call = Call.create(
        :session_id => tropo_session_id,
        :status => 'foo',
      )
      post :no_keypress, tropo_no_keypress_data
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"}
          }, {
            "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
          }, {
          "say" => [{
            "value" => "Sorry, We didn't receive any input. Call this number back to join the conference.",
            "voice" => "dave",
          }]
        }]
      }
      call.reload
      call.status.should == 'foo-nokeypress'
    end
  end

  describe "callback" do
    it "Should delete the call_session" do
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
      )
      call_session_id = call_session.id
      post :callback, tropo_callback_session_data
      CallSession.find_by_id(call_session_id).should be_nil
    end
    
    it "should set the duration of the call" do
      call = Call.create(:session_id => tropo_session_id, :status => 'foo')
      post :callback, tropo_callback_session_data
      response.content_type.should =~ /^text\/html/
      call.reload
      call.status.should == 'foo-callback'
      call.Duration.should == 4
    end

    it "should update the missed count on a missed call" do
      user = Factory(:user, :answered_count => 1, :made_in_a_row => 3, :missed_in_a_row => 0)
      event = Factory(:event, :user_id => user.id)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :event_id => event.id,
      )
      call = Call.create(
        :session_id => tropo_session_id,
        :status => 'foo-nokeypress',
        :Direction => 'outbound',
      )
      post :callback, tropo_callback_session_data
      user.reload
      user.missed_in_a_row.should == 1
      user.made_in_a_row.should == 0
    end

    it "should not update the missed count on a made call" do
      user = Factory(:user, :answered_count => 1, :made_in_a_row => 3, :missed_in_a_row => 0)
      event = Factory(:event, :user_id => user.id)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :event_id => event.id,
      )
      call = Call.create(
        :session_id => tropo_session_id,
        :status => 'foo-onhold',
        :Direction => 'outbound',
      )
      post :callback, tropo_callback_session_data
      user.reload
      user.missed_in_a_row.should == 0
      user.made_in_a_row.should == 3
    end

    it "should not update the missed count on an inbound call" do
      user = Factory(:user, :answered_count => 1, :made_in_a_row => 3, :missed_in_a_row => 0)
      event = Factory(:event, :user_id => user.id)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :event_id => event.id,
      )
      call = Call.create(
        :session_id => tropo_session_id,
        :status => 'foo-bar-baz',
        :Direction => 'inbound',
      )
      post :callback, tropo_callback_session_data
      user.reload
      user.missed_in_a_row.should == 0
      user.made_in_a_row.should == 3
    end
    
  end
  
  describe "put_on_hold" do
    it "should play some hold music" do
      user = Factory(:user, :answered_count => 1, :made_in_a_row => 0, :missed_in_a_row => 3)
      event = Factory(:event, :user_id => user.id)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :event_id => event.id,
      )
      call = Call.create(:session_id => tropo_session_id, :status => 'foo')
      post :put_on_hold, tropo_onhold_success_data
      parse_response(response).should == {
        "tropo" => [{
          "on" => {"event" => "hangup",   "next" => "/tropo/callback.json"},
        }, {
          "on" => {"event" => "error",    "next" => "/tropo/callback.json"}
        }, {
          "on" => {"event" => "continue", "next" => "/tropo/put_on_hold.json"}
        }, {
          "on" => {"event" => "placed",   "next" => "/tropo/place_in_conference.json"}
        }, {
          "on" => {"event" => "apologize", "next" => "/tropo/apologize_no_other_participants.json"}
        }, {
          "say" => [{"value"=>"Waiting for the other participants.", "voice"=>"dave"}]
        }, {
          "say" => [{"value"=>"http://hosting.tropo.com/69721/www/audio/jazz_planet.mp3", "voice"=>"dave"}]
        }]
      }
      call_session.reload
      call_session.call_state.should == 'onhold'
      call.reload
      call.status.should == 'foo-onhold'
      user.reload
      user.answered_count.should == 2
      user.made_in_a_row.should == 1
      user.missed_in_a_row.should == 0
    end
  end

  describe "place_in_conference" do
    it "should place participant into a conference" do
      event = Factory(:event)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :call_state => 'placing',
        :event_ids => event.id,
        :conference_name => 'FancyGoodConference',
        :timelimit => 700,
        :event_id => event.id,
        :user_id => event.user_id,
      )
      call = Call.create(:session_id => tropo_session_id, :status => 'foo')
      post :place_in_conference, tropo_place_in_conference_data
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"},
        }, {
          "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
        },  {
          "say" => [{"value"=>"Welcome.  On the call today we have Blake Mills", "voice"=>"dave"}]
        }, {
          "conference" => {
            "id"         => "FancyGoodConference", 
            "playTones"  => true, 
            "terminator" => "#", 
            "name"       => "FancyGoodConference_name"
          }
        }, {
          "on" => {"event"=>"onemin", "next"=>"/tropo/one_minute_warning.json"}
        }]
      }
      call_session.reload
      call_session.call_state.should == 'placed'
      call.reload
      call.status.should == "foo-placed:#{call_session.conference_name}"
    end
  end

  describe "one_minute_warning" do
    it "should give a one minute warning and put them back in the conference" do
      event = Factory(:event)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :call_state => 'placed',
        :event_ids => event.id,
        :conference_name => 'FancyGoodConference',
        :timelimit => 700,
        :event_id => event.id,
        :user_id => event.user_id,
      )
      call = Call.create(:session_id => tropo_session_id, :status => 'foo')
      post :one_minute_warning, tropo_one_minute_warning_data
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"},
        }, {
          "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
        },  {
          "say" => [{"value"=>"One minute remaining.", "voice"=>"dave"}]
        }, {
          "conference" => {
            "id"         => "FancyGoodConference", 
            "playTones"  => true, 
            "terminator" => "#", 
            "name"       => "FancyGoodConference_name"
          }
        }, {
          "on" => {"event"=>"awesome", "next"=>"/tropo/awesome_day.json"}
        }]
      }
      call_session.reload
      call_session.call_state.should == 'lastminute'
      call.reload
      call.status.should == 'foo-lastminute'
    end
  end

  describe "awesome_day" do
    it "should say goodbye and tell them when their next call is" do
      event = Factory(:event)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :call_state => 'lastminute',
        :event_ids => event.id,
        :conference_name => 'FancyGoodConference',
        :timelimit => 700,
        :event_id => event.id,
        :user_id => event.user_id,
      )
      call = Call.create(:session_id => tropo_session_id, :status => 'foo')
      post :awesome_day, tropo_awesome_day_data
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"},
        }, {
          "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
        },  {
          "say" => [{"value"=> "Time is up. Your next call is #{event.user.next_call_time_string}. Have an Awesome day!", "voice"=>"dave"}]
        }]
      }
      call_session.reload
      call_session.call_state.should == 'complete'
      call.reload
      call.status.should == 'foo-awesome'
    end
  end

  describe "apologize_no_other_participants" do
    it "should apologize" do
      event = Factory(:event)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
        :call_state => 'onhold',
        :event_id => event.id,
        :user_id => event.user_id,
        :participant_count => 3,
      )
      call = Call.create(:session_id => tropo_session_id, :status => 'foo')
      post :apologize_no_other_participants, tropo_apologize_data
      parse_response(response).should == {
        "tropo" => [{
            "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"},
          }, {
            "on" => {"event" => "error",  "next" => "/tropo/callback.json"}
          }, {
            "on" => {"event" => "continue",  "next" => "/tropo/put_on_hold.json"}
          }, {
            "say" => [{"value" => "I'm sorry. I called 2 other people but they didn't answer.", 
                       "voice"=>"dave"}]
          }, {
            "say" => [{"value"=> "You may stay on the line, for one of them to call in. Or wait for your next call, #{event.user.next_call_time_string}.",
                       "voice"=>"dave"}]
        }]
      }
      call_session.reload
      call_session.call_state.should == 'onhold'
      call.reload
      call.status.should == 'foo-apologized'
    end
  end
  
  describe "build_intro_string" do
    it "builds nice strings" do
      tc = TropoController.new
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
end

def parse_response(resp)
  ActiveSupport::JSON.decode(resp.body).with_indifferent_access
end

def tropo_session_id
  "b606a9d838ac912a84ac7d396b72e499"
end

def tropo_call_id
  "fad6a6decb25ebee3bf508fb1c05813d"
end

def tropo_incoming_session_data(event)
  from_number = event.user.primary_phone.number
  from_id = "#{from_number}"
  from_id.sub!(/\+1/, '')
  {
    "session" => {
      "id"          => tropo_session_id, 
      "accountId"   => "69721", 
      "timestamp"   => '2011-06-23 23:41:29 UTC', 
      "userType"    => "HUMAN", 
      "initialText" => nil, 
      "callId"      => tropo_call_id, 
      "to" => {
        "id"      => "4157660881", 
        "name"    => "+14157660881", 
        "channel" => "VOICE", 
        "network" => "SIP" }, 
      "from" => {
        "id"      => from_id, 
        "name"    => from_number, 
        "channel" => "VOICE", 
        "network" => "SIP"}, 
      "headers" => {
        "x-sbc-from"            => "<sip:+14153141222@192.168.47.68;isup-oli=62>;tag=gK0d7bc0f5", 
        "x-voxeo-sbc-name"      => "10.6.63.201", 
        "x-sbc-contact"         => "<sip:+14153141222@192.168.47.68:5060>", 
        "Content-Length"        => "247", 
        "x-accountid"           => "2", 
        "To"                    => "<sip:4157660881@10.6.61.201:5060>", 
        "x-voxeo-sbc"           => "true", 
        "Contact"               => "<sip:4153141222@10.6.63.201:5060>", 
        "x-sbc-remote-party-id" => "<sip:+14153141222@192.168.47.68:5060>;privacy=off", 
        "x-voxeo-to"            => "<sip:+14157660881@67.231.4.93>", 
        "x-appid"               => "24601", 
        "x-sbc-request-uri"     => "sip:+14157660881@sip.tropo.com", 
        "x-sbc-call-id"         => "1426951374_36863491@192.168.47.68", 
        "x-sid"                 => "07a0cb9e1609b68353684b1bfa2cff6a", 
        "x-sbc-cseq"            => "29996 INVITE", 
        "x-sbc-max-forwards"    => "53", 
        "x-voxeo-sbc-session-id"=> "07a0cb9e1609b68353684b1bfa2cff6a", 
        "CSeq"                  => "2 INVITE", 
        "Via"                   => "SIP/2.0/UDP 66.193.54.6:5060;received=10.6.63.201", 
        "x-sbc-record-route"    => "<sip:216.82.224.202;lr;ftag=gK0d7bc0f5>", 
        "Call-ID"               => "0-13c4-4e03cf28-1d5dd57d-7b1c-1d762270", 
        "Content-Type"          => "application/sdp", 
        "x-sbc-to"              => "<sip:+14157660881@67.231.4.93>", 
        "From"                  => "<sip:4153141222@10.6.63.201:5060>;tag=0-13c4-4e03cf28-1d5dd57d-72d9"}
    }
  }
end

def tropo_outgoing_session_data(event)
  { 
    "session" => {
      "id"          => tropo_session_id,
      "accountId"   => "69721", 
      "timestamp"   => '2011-07-06 18:29:53 UTC', 
      "userType"    =>"NONE", 
      "initialText" => nil, 
      "callId"      => nil, 
      "parameters"  => {
        "action"   => "create", 
        "event_id" => event.id,
        "format"   => "form"
      }
    }
  }
end

def tropo_callback_session_data
  {
    "result" => {
      "sessionId" => tropo_session_id, 
      "callId"    => "8d270e56a14e1dc1266f565c28490ac4", 
      "state"     => "DISCONNECTED", 
      "sessionDuration" => 4, 
      "sequence"        => 1, 
      "complete"        => true, 
      "error"           => nil,
    }
  }
end

def tropo_greeting_session_data(event)
  {
    "result" => {
      "sessionId" => tropo_session_id, 
      "callId"    => "05d684fae36493f9ecb452c85e90b369", 
      "state"     => "ANSWERED", 
      "sessionDuration" => 8, 
      "sequence"        => 1, 
      "complete"        => true, 
      "error"           => nil
    }, 
    "event_id" => event.id,
  }
end

def tropo_onhold_session_data(event) # XXX not sure where this came from... doesn't seem correct
  {
    "result" => {
      "sessionId" => tropo_session_id, 
      "callId"    => "1c835a0c9a100dc78c951200a697ce62", 
      "state"     => "ANSWERED", 
      "sessionDuration" => 4, 
      "sequence"        => 1, 
      "complete"        => true, 
      "error"           => nil
    }, 
    "event_id" => event.id
  }
end

def tropo_onhold_success_data
  {
    "result" => {
      "sessionId"       => tropo_session_id,
      "callId"          => "1e9013804c661c8858f04ac34b809b2b",
      "state"           => "ANSWERED",
      "sessionDuration" => 14,
      "sequence"        => 2,
      "complete"        => true,
      "error"           => nil,
      "actions"         => {
        "name"     => "signin",
        "attempts" => 1,
        "disposition" => "SUCCESS",
        "confidence"  => 100,
        "interpretation" => "1",
        "utterance"      => "1",
        "value"          => "1",
        "xml"            => "<?xml version=\"1.0\"?>\r\n<result grammar=\"0@61edd852.vxmlgrammar\">\r\n <interpretation grammar=\"0@61edd852.vxmlgrammar\" confidence=\"100\">\r\n \r\n <input mode=\"dtmf\">dtmf-1<\/input>\r\n <\/interpretation>\r\n<\/result>\r\n"
      }
    }
  }
end

def tropo_place_in_conference_data
  {
    "result" => {
      "sessionId"       => tropo_session_id, 
      "callId"          => "25352ccd4aa88652659bef53f08f554d", 
      "state"           => "ANSWERED", 
      "sessionDuration" => 30, 
      "sequence"        => 3, 
      "complete"        => true, 
      "error"           => nil,
    }
  }
end

def tropo_one_minute_warning_data
  {
    "result" => {
      "sessionId"       => tropo_session_id,
      "callId"          => "16f84c1252ad8bc94e538217a1d44109",
      "state"           => "ANSWERED",
      "sessionDuration" => 56,
      "sequence"        => 4,
      "complete"        => true,
      "error"           => nil,
      "actions" => {
        "name"        => "15mcPool2Room1_name",
        "duration"    => 28,
        "disposition" => "EXTERNAL_EVENT"
      }
    }
  }
end

def tropo_awesome_day_data
  {
    "result" => {
      "sessionId"       => tropo_session_id,
      "callId"          => "66e5c7e43d8af82a51697a05cf10867e",
      "state"           => "ANSWERED",
      "sessionDuration" => 175,
      "sequence"        => 5,
      "complete"        => true,
      "error"           => nil,
      "actions" => {
        "name"        => "15mcPool2Room1_name",
        "duration"    => 51,
        "disposition" => "EXTERNAL_EVENT",
      }
    }
  }
end

def tropo_no_keypress_data
  {
    "result" => {
      "sessionId"       => tropo_session_id,
      "callId"          => "8e07d497569e6bc5d29ffa99e02308a1",
      "state"           => "ANSWERED",
      "sessionDuration" => 21,
      "sequence"        => 2,
      "complete"        => false,
      "error"           => nil,
      "actions" => {
        "name"        => "signin",
        "attempts"    => 1,
        "disposition" => "TIMEOUT",
      }
    }
  }
end

def tropo_apologize_data
  {
    "result" => {
      "sessionId"       => tropo_session_id,
      "callId"          => "426f5bc1c7b2d5e18fdbcbec8316fc28",
      "state"           => "ANSWERED",
      "sessionDuration" => 57,
      "sequence"        => 3,
      "complete"        => true,
      "error"           => nil,
    }
  }
end

