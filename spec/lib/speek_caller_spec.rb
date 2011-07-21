require 'spec_helper'

describe SpeekCaller do
  
  before(:each) do
    @sc = SpeekCaller.new
  end

  describe "speek variables" do

    it "should have the right api_key" do
      @sc.api_key.should == 'r7442fvnyvyhrpf7b7j5gmx9'    
    end

    it "should have a base_url" do
      @sc.base_url.should == 'http://api.speek.com'
    end
  end
  
  describe "post_to_speek" do

    it "sends a post to speek" do
      url = 'http://example.org'
      args = {'foo' => 'bar'}
      Net::HTTP.should_receive(:post_form).with(URI.parse(url), args)
      @sc.post_to_speek(url, args)
    end
  end

  describe "start_call_for_event" do
    it "should start a call" do
      event = Factory(:event)
      @sc.should_receive(:post_to_speek).with('http://api.speek.com/calls/callNow', {
        :api_key => "r7442fvnyvyhrpf7b7j5gmx9", 
        :description => event.name, 
        :numbers => event.user.primary_phone.number_plain, 
        :format => "json",
      })
      @sc.start_call_for_event(event)
    end
  end
end
