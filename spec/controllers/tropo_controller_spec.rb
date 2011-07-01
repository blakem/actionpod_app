require 'spec_helper'

describe TropoController do

  describe "tropo" do
    it "should initiate a call" do
      post :tropo, :session => tropo_session_data['session']
      parse_response(response).should == {
        "tropo" => [{
          "on" => {"event" => "hangup", "next" => "/tropo/callback.json"},
        }, {
          "on" => {"event" => "continue", "next"=> "/tropo/greeting?event_id=13657"},
        }, {
          "call" => {"to"=>"+14153141222", "from"=>"+14157660881"}
        }]
      }
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

    it "Should appologize if it can't match an event" do
      event = Factory(:event)
      post :greeting, :event_id => event.id
      parse_response(response).should == {
        "tropo" => [{
          "on"  => {"event" => "hangup",     "next" => "/tropo/callback.json"},
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
              "value" => "Welcome to your TestEvent2. Press 1 to join the conference.",
              "voice" => "dave"
            }],
          }
        }]
      }
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
end

def parse_response(resp)
  ActiveSupport::JSON.decode(resp.body).with_indifferent_access
end

def tropo_session_data
  {
    "session" => {
      "id"          => "cde357ff7d80d615ba65c421b4df6323", 
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
        "id"      => "4153141222", 
        "name"    => "+14153141222", 
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
  