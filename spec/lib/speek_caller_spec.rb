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
      string = 'FooBar'
      args = {'foo' => 'bar'}
      Net::HTTP.should_receive(:post_form).with(URI.parse(@sc.base_url + '/calls/' + string), {
        'foo' => 'bar',
        :api_key => @sc.api_key,
      })
      @sc.post_to_speek(string, args)
    end
  end

  describe "start_call_for_event" do
    it "should start a call" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id, :primary => true)
      event = Factory(:event, :user_id => user.id)
      @sc.should_receive(:post_to_speek).with('callNow', {
        :description => event.name, 
        :numbers => event.user.primary_phone.number_plain, 
        :format => "json",
      })
      @sc.start_call_for_event(event)
    end
  end

  describe "start_call_for_events" do
    it "should start a call for each event" do
      user1 = Factory(:user)
      phone1 = Factory(:phone, :user_id => user1.id, :primary => true, :string => '+13334445555')
      event1 = Factory(:event, :user_id => user1.id)
      user2 = Factory(:user, :multi_phones => true)
      phone2 = Factory(:phone, :user_id => user2.id, :primary => true, :string => '+14567778888')
      phone3 = Factory(:phone, :user_id => user2.id, :primary => false, :string => '+19998887777')
      event2 = Factory(:event, :user_id => user2.id)
      @sc.should_receive(:post_to_speek).with('callNow', {
        :description => event1.name, 
        :numbers => "13334445555,#{phone2.number_plain},#{phone3.number_plain}",
        :format => "json",
      })
      @sc.start_call_for_events([event1, event2])
    end
  end

  describe "add_event_to_call" do
    it "should add and event to the call" do
      user = Factory(:user)
      phone = Factory(:phone, :user_id => user.id, :primary => true)
      event = Factory(:event, :user_id => user.id)
      call_id = 'foobar'
      @sc.should_receive(:post_to_speek).with('addParticipant', {
        :numbers => event.user.primary_phone.number_plain, 
        :format => "json",
        :call_id => call_id,
      })
      @sc.add_event_to_call(event, call_id)
    end
  end
end
