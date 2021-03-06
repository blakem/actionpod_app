require 'spec_helper'

describe ApplicationController do
  before(:each) do
    @pool1 = Pool.default_pool
    @pool2 = Factory(:pool)
    @user1 = Factory(:user, :time_zone => 'Pacific Time (US & Canada)')      
    @user2 = Factory(:user, :time_zone => 'Pacific Time (US & Canada)')
    @user3 = Factory(:user, :time_zone => 'Mountain Time (US & Canada)')
    @pool1.users = User.all
    @event11 = Factory(:event, :user_id => @user1.id, :pool_id => @pool1.id, :pool_event => true)
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

  describe "build_nextcalls" do
    
    it "should return [] if a user has no events" do
      @ac.send(:build_nextcalls, @user1).should == []
    end

    it "should return a list of the users next 5 calls" do
      next_calls = @ac.send(:build_nextcalls, @user2)
      next_calls.length.should == 5
      next_calls[0].should =~ /^8:00am on Mon \w+ \d+\w+/
      next_calls[1].should =~ /^11:00am on Mon \w+ \d+\w+/
      next_calls[2].should =~ /^2:00pm on Mon \w+ \d+\w+/
      next_calls[3].should =~ /^2:01pm on Mon \w+ \d+\w+/
      next_calls[4].should =~ /^3:05pm on Mon \w+ \d+\w+/
    end

    it "should display in the current_users time_zone" do
      next_calls = @ac.send(:build_nextcalls, @user3)
      next_calls.length.should == 5
      next_calls[0].should =~ /^8:00am on Mon \w+ \d+\w+/
      next_calls[1].should =~ /^11:00am on Mon \w+ \d+\w+/
      next_calls[2].should =~ /^2:00pm on Mon \w+ \d+\w+/
      next_calls[3].should =~ /^2:01pm on Mon \w+ \d+\w+/
      next_calls[4].should =~ /^3:05pm on Mon \w+ \d+\w+/
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
