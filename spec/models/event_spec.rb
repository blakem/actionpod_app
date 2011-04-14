require 'spec_helper'

describe Event do
  
  it "should generate a name if it isn't given one" do
    user = Factory(:user, :name => 'Bob Jones')
    event = Factory(:event, :user_id => user.id, :name => '')
    event.valid?
    event.errors[:name].should be_empty
    event.name.should == "Bob's 8:00am Call"
  end
  
  it "should have a user" do
    user = Factory(:user)
    event = Factory(:event, :user_id => user.id)
    event.user.should == user
  end
  
  it "belongs to a pool" do
    pool = Factory(:pool)
    event = Factory(:event, :pool_id => pool.id)
    event.pool.should == pool    
  end

  it "has a name_in_second_person" do
    user = Factory(:user, :name => 'Bob Jones')
    event = Factory(:event, :user_id => user.id, :name => 'My 8am Event for Bob')
    event.name_in_second_person.should == 'My 8am Event for Bob'
    event.name = "Bob's 8:00am Call"
    event.name_in_second_person.should == "8:00am Call"    
  end

  describe "it's schedule" do
    before(:each) do
      user = Factory(:user, :time_zone => 'Mountain Time (US & Canada)')
      pool = Factory(:pool)
      @event = Event.create(:name => 'NewEvent', :user_id => user.id, :pool_id => pool.id)
    end
    
    it "should have a schedule" do
      @event.schedule.should be_a_kind_of(IceCube::Schedule)
    end
    
    it "should have a default schedule of weekdays at 8am" do
      @event.schedule.to_s.should == 
        'Weekly on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays on the 8th hour of the day on the 0th minute of the hour'
    end

    it "should have a start_date of today" do
      @event.schedule.to_hash[:start_date].to_date.should == Time.now.in_time_zone(@event.user.time_zone).to_date
    end
  
    it "should have a start_time of the beginning of today in the users timezone" do
      @event.schedule.start_time.should == Time.now.in_time_zone(@event.user.time_zone).beginning_of_day
    end

    it "pretty prints with schedule_str and can be modified with alter_schedule" do
      @event.schedule_str.should ==
        '8:00am on Weekdays'
      @event.alter_schedule(:hour_of_day => [10])
      @event.schedule_str.should ==
        '10:00am on Weekdays'
      @event.alter_schedule(:hour_of_day => [14], :minute_of_hour => [15])
      @event.schedule_str.should ==
        '2:15pm on Weekdays'
      @event.alter_schedule(:hour_of_day => [12], :minute_of_hour => [15])
      @event.schedule_str.should ==
        '12:15pm on Weekdays'
      @event.alter_schedule(:hour_of_day => [0], :minute_of_hour => [15])
      @event.schedule_str.should ==
        '12:15am on Weekdays'
      @event.alter_schedule(:day => [2,3,4], :minute_of_hour => [15])
      @event.schedule_str.should ==
        '12:15am on Tuesdays, Wednesdays, and Thursdays'
      @event.alter_schedule(:day => [2,3], :minute_of_hour => [15])
      @event.schedule_str.should == '12:15am on Tuesdays and Wednesdays'
      @event.alter_schedule(:day => [], :minute_of_hour => [15])
      @event.schedule_str.should == '12:15am, but No Days Selected!'
    end
    
    it "should have time a time accessor to it's schedule" do
      @event.time.should == '8:00am'
    end

    it "should have a time setter to it's schedule" do
      @event.time = '9:00am'
      @event.time.should == '9:00am'
      @event.save
      @event.reload
      @event.time.should == '9:00am'
    end
    
    it "should have a minute_of_day accessor to it's schedule" do
      @event.time = '4:07pm'
      @event.minute_of_day.should == (4+12)*60+7
    end

    it "should have an hour_of_day accessor to it's schedule" do
      @event.time = '4:07pm'
      @event.hour_of_day.should == (4+12)
      @event.time = '12:07pm'
      @event.hour_of_day.should == 12
      @event.time = '12:07am'
      @event.hour_of_day.should == 0
    end

    it "should have a minute_of_hour accessor to it's schedule" do
      @event.time = '4:07pm'
      @event.minute_of_hour.should == 7
      @event.time = '4:00pm'
      @event.minute_of_hour.should == 0
    end    

    it "should be able to handle 12:00am" do
      @event.time = '12:00am'
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 0
      @event.time.should == '12:00am'
      @event.save
      @event.reload
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 0
      @event.time.should == '12:00am'
    end

    it "should be able to handle 12:19AM" do
      @event.time = '12:19AM'
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 0
      @event.time.should == '12:19am'
      @event.save
      @event.reload
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 0
      @event.time.should == '12:19am'
    end

    it "should be able to handle 12:19am" do
      @event.time = '12:19am'
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 0
      @event.time.should == '12:19am'
      @event.save
      @event.reload
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 0
      @event.time.should == '12:19am'
    end

    it "should be able to handle 12:00pm" do
      @event.time = '12:00pm'
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 12
      @event.time.should == '12:00pm'
      @event.save
      @event.reload
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 12
      @event.time.should == '12:00pm'
    end

    it "should be able to handle 12:19pm" do
      @event.time = '12:19pm'
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 12
      @event.time.should == '12:19pm'
      @event.save
      @event.reload
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 12
      @event.time.should == '12:19pm'
    end

    it "should be able to handle 12:19PM" do
      @event.time = '12:19PM'
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 12
      @event.time.should == '12:19pm'
      @event.save
      @event.reload
      @event.schedule.to_hash[:rrules][0][:validations][:hour_of_day][0].should == 12
      @event.time.should == '12:19pm'
    end

    it "should have a days setter to it's schedule" do
      @event.days = [2,3,4]
      @event.days.should == [2,3,4]
      @event.save
      @event.reload
      @event.days.should == [2,3,4]
    end

    it "should be able to tell us if it's scheduled on a particular day of the week" do
      @event.on_day(0).should be_false
      @event.on_day(1).should be_true
      @event.on_day(2).should be_true
      @event.on_day(3).should be_true
      @event.on_day(4).should be_true
      @event.on_day(5).should be_true
      @event.on_day(6).should be_false
    end

    describe "empty schedule" do
      it "should not have occurrences if it has not days" do
        @event.days = []
        @event.time = '8:00pm'
        @event.schedule.next_occurrence.should be_nil
        @event.minute_of_day.should == 20*60
        @event.on_day(0).should be_false
        @event.days = [0]
        @event.on_day(0).should be_true
        @event.days = []
        @event.save
        @event.on_day(0).should be_false
        @event.destroy   
      end
      
    end
  end
  
  describe "managing it's scheduled events" do

    it "should delete all scheduled events on destroy" do
      event = Factory(:event)
      dj = Factory(:delayed_job, :obj_type => 'Event', :obj_id => event.id)
      dj_id = dj.id
      event.destroy
      DelayedJob.find_by_id(dj_id).should be_nil
    end

    it "should dequeue the queued check_before_calls_go_out if it's the only one scheduled" do
      event = Factory(:event, :user_id => Factory(:user).id, :pool_id => Factory(:pool).id)
      event.days = [0,1,2,3,4,5,6]
      expect {
        event.save
      }.to change(DelayedJob, :count).by(2)
      expect{
        event.destroy
      }.to change(DelayedJob, :count).by(-2)    
    end

    it "should not dequeue the queued check_before_calls_go_out if it's not the only one scheduled" do
      pool = Factory(:pool)
      event1 = Factory(:event, :user_id => Factory(:user).id, :pool_id => pool.id)
      event1.days = [0,1,2,3,4,5,6]
      event2 = Factory(:event, :user_id => Factory(:user).id, :pool_id => pool.id)
      event2.days = [0,1,2,3,4,5,6]
      expect{ event2.save }.to    change(DelayedJob, :count).by(2)
      expect{ event1.save }.to    change(DelayedJob, :count).by(1)
      expect{ event1.destroy }.to change(DelayedJob, :count).by(-1)    
      expect{ event2.destroy }.to change(DelayedJob, :count).by(-2)    
    end

    it "Pool dequeing on edit is based on the *old* values" do
      pool = Factory(:pool)
      event = Factory(:event, :user_id => Factory(:user).id, :pool_id => pool.id)
      event.days = [0,1,2,3,4,5,6]
      expect{ event.save }.to     change(DelayedJob, :count).by(2)
      event.time = "3:03pm"
      expect{ event.save }.to_not change(DelayedJob, :count)
      expect{ event.destroy }.to  change(DelayedJob, :count).by(-2)
    end

    it "should reschedule itself on edit" do
      event = Factory(:event, :pool_id => Factory(:pool).id)
      dj = Factory(:delayed_job, :obj_type => 'Event', :obj_id => event.id)
      dj_id = dj.id
      event.time = '4:00pm'
      event.days = [0,1,2,3,4,5,6]
      rv = event.save
      rv.should == true
      DelayedJob.find_by_id(dj_id).should be_nil
      DelayedJob.where(:obj_type => 'Event', :obj_id => event.id).count.should == 1
    end
    
    it "should schedule itself on create" do
      user = Factory(:user)
      pool = Factory(:pool)
      event = Event.create(:name => 'TestCreateDJEvent', :user_id => user.id, :pool_id => pool.id, :days => [0,1,2,3,4,5,6])
      DelayedJob.where(:obj_type => 'Event', :obj_id => event.id).count.should == 1
    end
    
  end

end
