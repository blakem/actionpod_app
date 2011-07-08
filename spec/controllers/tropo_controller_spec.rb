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
            "on" => {"event" => "continue", "next"=> "/tropo/greeting?event_id=#{event.id}"},
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
        call_session.session_id.should == 'b606a9d838ac912a84ac7d396b72e499'
        call_session.call_state.should == 'calling'
      end

      it "Don't crash on empty data" do
        post :tropo
        response.should be_success
        parse_response(response).should == {
          "tropo" => [{
            "on" => {"event" => "hangup", "next" => "/tropo/callback.json"}
          }]
        }
      end
    end
    
    describe "incoming calls" do
      it "should send them to put_on_hold" do
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        event = Factory(:event, :user_id => user.id)
        post :tropo, tropo_incoming_session_data(event)
        parse_response(response).should == {
          "tropo" => [{
            "on" => {"event" => "hangup", "next" => "/tropo/callback.json"},
          }, {
            "say" => [{
              "value"=>"Welcome to your #{event.name_in_second_person}.", "voice"=>"dave"
            }]
          }, {
            "on" => {"event"=>"continue", "next"=>"/tropo/put_on_hold.json?event_id=#{event.id}"}
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
      end      
    end
  end

  describe "greeting" do
    it "Should appologize if it can't match an event" do
      post :greeting
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"}
          }, {
          "say" => [{
            "value" => "I'm sorry I can't match this number up with a scheduled event. Goodbye.",
            "voice" => "dave",
          }]
        }]
      }
    end

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
      post :greeting, tropo_greeting_session_data(event)
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup",     "next" => "/tropo/callback.json"},
        }, {
          "on"  => {"event" => "continue",   "next" => "/tropo/put_on_hold.json?event_id=#{event.id}"},
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
    end
  end

  describe "no_keypress" do
    it "Should tell them to call back" do
      post :no_keypress
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"}
          }, {
          "say" => [{
            "value" => "Sorry, We didn't receive any input. Call this number back to join the conference.",
            "voice" => "dave",
          }]
        }]
      }
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
  end
  
  describe "put_on_hold" do
    it "should play some hold music" do
      event = Factory(:event)
      CallSession.all.each { |cs| cs.destroy }
      call_session = CallSession.create(
        :session_id => tropo_session_id,
      )
      post :put_on_hold, tropo_onhold_session_data(event)
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"},
        }, {
          "say" => [{"value"=>"Waiting for the other participants.", "voice"=>"dave"}]
        }, {
          "say" => [{"value"=>"http://hosting.tropo.com/69721/www/audio/jazz_planet.mp3", "voice"=>"dave"}]
        }, {
          "on" => {"event"=>"placed", "next"=>"/tropo/place_in_conference.json"}
        }]
      }
      call_session.reload
      call_session.call_state.should == 'on_hold'
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
      post :place_in_conference, tropo_place_in_conference_data
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"},
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
      post :one_minute_warning, tropo_one_minute_warning_data
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"},
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
      post :awesome_day, tropo_awesome_day_data
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup", "next" => "/tropo/callback.json"},
        },  {
          "say" => [{"value"=> "Time is up. Your next call is Today at 7:00pm. Have an Awesome day!", "voice"=>"dave"}]
        }]
      }
      call_session.reload
      call_session.call_state.should == 'complete'
    end
  end
end

def parse_response(resp)
  ActiveSupport::JSON.decode(resp.body).with_indifferent_access
end

def tropo_session_id
  "b606a9d838ac912a84ac7d396b72e499"
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
      "callId"      => "fad6a6decb25ebee3bf508fb1c05813d", 
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

def tropo_onhold_session_data(event)
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