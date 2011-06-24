require 'spec_helper'

describe TropoController do
  describe "greeting" do
    it "should 'say'" do
      post :greeting
      puts response.body
      response.body.should =~ /say/
    end
  end

  describe "incoming" do
    it "should 'say'" do
      post :incoming, :session => tropo_session_data['session']
      puts response.body
      response.body.should =~ /say/
    end
  end
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
  