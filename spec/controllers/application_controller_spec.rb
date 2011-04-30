require 'spec_helper'

describe ApplicationController do
  before(:each) do
    @pool1 = Pool.default_pool
    @pool2 = Factory(:pool)
    @user1 = Factory(:user, :time_zone => 'Pacific Time (US & Canada)')      
    @user2 = Factory(:user, :time_zone => 'Pacific Time (US & Canada)')
    @user3 = Factory(:user, :time_zone => 'Mountain Time (US & Canada)')
    @event21 = Factory(:event, :user_id => @user2.id, :pool_id => @pool1.id)
    @event31 = Factory(:event, :user_id => @user3.id, :pool_id => @pool1.id)
    @event21.time = '8:00am'
    @event31.time = '9:00am'
    @event22 = Factory(:event, :user_id => @user2.id, :pool_id => @pool1.id)
    @event32 = Factory(:event, :user_id => @user3.id, :pool_id => @pool1.id)
    @event22.time = '11:00am'
    @event32.time = '12:00pm'
    @event23 = Factory(:event, :user_id => @user3.id, :pool_id => @pool1.id)
    @event23.days = []
    @event33 = Factory(:event, :user_id => @user3.id, :pool_id => @pool1.id)
    @event33.time = '9:00pm'
    @event24 = Factory(:event, :user_id => @user2.id, :pool_id => @pool1.id)
    @event34 = Factory(:event, :user_id => @user3.id, :pool_id => @pool1.id)
    @event24.time = '2:00pm'
    @event34.time = '3:00pm'
    @event35 = Factory(:event, :user_id => @user3.id, :pool_id => @pool2.id)
    @event25 = Factory(:event, :user_id => @user2.id, :pool_id => @pool1.id)
    @event35.time = '3:01pm'
    @event25.time = '2:01pm'
    @event36 = Factory(:event, :user_id => @user3.id, :pool_id => @pool2.id)
    @event26 = Factory(:event, :user_id => @user2.id, :pool_id => @pool2.id)
    @event36.time = '4:05pm'
    @event26.time = '3:05pm'
    @events = [@event21, @event31, @event22, @event32, @event23, @event33, @event24, @event34, @event35, @event25, @event36, @event26]
    @events.each { |e| e.save }
    @ac = ApplicationController.new
    @ac.stub(:current_user).and_return(@user2)
    Event.stub(:all).and_return(@events.shuffle)
    now = Time.now.beginning_of_week + 7.days
    Time.stub(:now).and_return(now)
  end

  describe "build_call_groups" do
    
    it "should return [] if a user has no events" do
      @ac.send(:build_call_groups, @user1).should == []
    end

    it "returns a list of call_groups sorted by time and sorted by user_id" do
      @ac.send(:build_call_groups, @user2).should == [{
        :time=>"8:00am",
        :pool=>1,
        :events=> [ 
          [@event31.id, @user3.id],
          [@event21.id, @user2.id], 
      ]}, {
        :time=>"11:00am", 
        :pool=>1,
        :events=> [ 
          [@event32.id, @user3.id],
          [@event22.id, @user2.id], 
      ]}, {
        :time=>"2:00pm", 
        :pool=>1,
        :events=> [ 
          [@event34.id, @user3.id],
          [@event24.id, @user2.id], 
      ]}, {
        :time=>"2:01pm", 
        :pool=>1,
        :events=> [ 
          [@event25.id, @user2.id], 
      ]}]
    end

    it "shows all pools for admin users" do
      @user2.toggle!(:admin)
      @ac.send(:build_call_groups, @user2).should == [{
        :time=>"8:00am", 
        :pool=>1,
        :events=> [ 
          [@event31.id, @user3.id],
          [@event21.id, @user2.id], 
      ]}, {
        :time=>"11:00am", 
        :pool=>1,
        :events=> [ 
          [@event32.id, @user3.id],
          [@event22.id, @user2.id], 
      ]}, {
        :time=>"2:00pm", 
        :pool=>1,
        :events=> [ 
          [@event34.id, @user3.id],
          [@event24.id, @user2.id], 
      ]}, {
        :time=>"2:01pm", 
        :pool=>1,
        :events=> [ 
          [@event25.id, @user2.id], 
      ]}, {
        :time=>"3:05pm", 
        :pool=>@pool2.id,
        :events=> [ 
          [@event36.id, @user3.id], 
          [@event26.id, @user2.id], 
      ]}]
    end
  end

  describe "build_nextcalls" do
    
    it "should return [] if a user has no events" do
      @ac.send(:build_nextcalls, @user1).should == []
    end

    it "should return a list of the users next 5 calls" do
      @ac.send(:build_nextcalls, @user2).should == [
        "8:00am on Monday",
        "11:00am on Monday",
        "2:00pm on Monday",
        "2:01pm on Monday",
        "3:05pm on Monday",
      ]
    end

    it "should display in the current_users time_zone" do
      @ac.send(:build_nextcalls, @user3).should == [
        "8:00am on Monday",
        "11:00am on Monday",
        "2:00pm on Monday",
        "2:01pm on Monday",
        "3:05pm on Monday",
      ]
    end
  end
  
  describe "build_timeslots" do
    
    it "should return an ordered list of existing time-slots that the user is not currently subscribed to" do
      @ac.stub(:current_user).and_return(@user1)
      @ac.send(:build_timeslots).should == [
        {:time =>  "8:00am", :string =>  "8:00am on Weekdays"}, 
        {:time => "11:00am", :string => "11:00am on Weekdays"}, 
        {:time =>  "2:00pm", :string =>  "2:00pm on Weekdays"}, 
        {:time =>  "8:00pm", :string =>  "8:00pm on Weekdays"},
      ]

      @user1.toggle!(:admin)
      @ac.send(:build_timeslots).should == [
        {:time =>  "8:00am", :string =>  "8:00am on Weekdays"}, 
        {:time => "11:00am", :string => "11:00am on Weekdays"}, 
        {:time =>  "2:00pm", :string =>  "2:00pm on Weekdays"},
        {:time =>  "2:01pm", :string =>  "2:01pm on Weekdays"},
        {:time =>  "3:05pm", :string =>  "3:05pm on Weekdays"},
        {:time =>  "8:00pm", :string =>  "8:00pm on Weekdays"},
      ]

      @ac.stub(:current_user).and_return(@user2)
      @ac.send(:build_timeslots).should == [
        {:time =>  "8:00pm", :string =>  "8:00pm on Weekdays"},
      ]

      @ac.stub(:current_user).and_return(@user3)
      @ac.send(:build_timeslots).should == []
    end
  end

  describe "build_scheduled_events" do
    
    it "should return an ordered list of all the events scheduled" do
      got = @ac.send(:build_scheduled_events)
      got.map { |data| [data[:occurrence].to_s.sub(/^.+? /, ''), data[:count], data[:pool_id]] }.should == [
        ["08:00:00 -0700", 2, 1],
        ["11:00:00 -0700", 2, 1],
        ["14:00:00 -0700", 2, 1],
        ["20:00:00 -0700", 1, 1]
      ] * 5

      @user2.toggle!(:admin)
      got = @ac.send(:build_scheduled_events)
      got.map { |data| [data[:occurrence].to_s.sub(/^.+? /, ''), data[:count], data[:pool_id]] }.should == [
        ["08:00:00 -0700", 2, 1],
        ["11:00:00 -0700", 2, 1],
        ["14:00:00 -0700", 2, 1],
        ["14:01:00 -0700", 1, 1],
        ["14:01:00 -0700", 1, @pool2.id],
        ["15:05:00 -0700", 2, @pool2.id],
        ["20:00:00 -0700", 1, 1]
      ] * 5
    end
  end
end
