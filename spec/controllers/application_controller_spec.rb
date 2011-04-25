require 'spec_helper'

describe ApplicationController do
  before(:each) do
    @user1 = Factory(:user, :time_zone => 'Pacific Time (US & Canada)')      
    @user2 = Factory(:user, :time_zone => 'Pacific Time (US & Canada)')
    @user3 = Factory(:user, :time_zone => 'Mountain Time (US & Canada)')
    @event21 = Factory(:event, :user_id => @user2.id)
    @event31 = Factory(:event, :user_id => @user3.id)
    @event21.time = '8:00am'
    @event31.time = '9:00am'
    @event22 = Factory(:event, :user_id => @user2.id)
    @event32 = Factory(:event, :user_id => @user3.id)
    @event22.time = '11:00am'
    @event32.time = '12:00pm'
    @event23 = Factory(:event, :user_id => @user3.id)
    @event23.days = []
    @event33 = Factory(:event, :user_id => @user3.id)
    @event33.time = '9:00pm'
    @event24 = Factory(:event, :user_id => @user2.id)
    @event34 = Factory(:event, :user_id => @user3.id)
    @event24.time = '2:00pm'
    @event34.time = '3:00pm'
    @event35 = Factory(:event, :user_id => @user3.id)
    @event25 = Factory(:event, :user_id => @user2.id)
    @event35.time = '3:01pm'
    @event25.time = '2:01pm'
    @events = [@event21, @event31, @event22, @event32, @event23, @event33, @event24, @event34, @event35, @event25]
    @events.each { |e| e.save }
    @ac = ApplicationController.new
    @ac.stub(:current_user).and_return(@user2)
    Event.stub(:all).and_return(@events.shuffle)
    now = Time.now.beginning_of_week
    Time.stub(:now).and_return(now)
  end

  describe "build_call_groups" do
    
    it "should return [] if a user has no events" do
      @ac.send(:build_call_groups, @user1).should == []
    end

    it "returns a list of call_groups sorted by time and sorted by user_id" do
      @ac.send(:build_call_groups, @user2).should == [{
        :time=>"8:00am", 
        :events=> [ 
          [@event31.id, @user3.id],
          [@event21.id, @user2.id], 
      ]}, {
        :time=>"11:00am", 
        :events=> [ 
          [@event32.id, @user3.id],
          [@event22.id, @user2.id], 
      ]}, {
        :time=>"2:00pm", 
        :events=> [ 
          [@event34.id, @user3.id],
          [@event24.id, @user2.id], 
      ]}, {
        :time=>"2:01pm", 
        :events=> [ 
          [@event35.id, @user3.id],
          [@event25.id, @user2.id], 
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
        "8:00am on Tuesday",
      ]
    end

    it "should display in the current_users time_zone" do
      @ac.send(:build_nextcalls, @user3).should == [
        "8:00am on Monday",
        "11:00am on Monday",
        "2:00pm on Monday",
        "2:01pm on Monday",
        "8:00pm on Monday",
      ]
    end
  end
end
