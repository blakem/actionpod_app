require 'spec_helper'

describe Event do

  describe "skip_dates" do
    it "is ok blank" do
      event = Factory(:event)
      event.skip_dates.should == ''
      event.valid?
      event.errors[:skip_dates].should == []
    end    

    it "is ok with one date" do
      event = Factory(:event)
      event.skip_dates = '5/10/2011'
      event.valid?
      event.errors[:skip_dates].should == []
    end    

    it "is ok with two dates" do
      event = Factory(:event)
      event.skip_dates = '5/10/2011,5/11/2011'
      event.valid?
      event.errors[:skip_dates].should == []
    end    

    it "is ok with three dates" do
      event = Factory(:event)
      event.skip_dates = '5/10/2011,5/11/2011,10/9/2011'
      event.valid?
      event.errors[:skip_dates].should == []
    end    

    it "is not ok with two digit years" do
      event = Factory(:event)
      event.skip_dates = '5/10/11'
      event.valid?
      event.errors[:skip_dates].should include("must be comma separated in mm/dd/yyyy format. i.e '5/10/2011,5/11/2011'")
    end    
  end

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

  describe "it's sms_reminder_text" do
    it "shouldn't duplicate the time" do
      user = Factory(:user, :name => 'Bob Smith')
      event = Factory(:event, :user_id => user.id, :name => '')
      event.name.should == "Bob's 8:00am Call"
      event.sms_reminder_text.should ==
       "Your 8:00am Call is about to begin. Expect a call in 10 minutes."
      event.name = "Morning Accountability Call"
      event.sms_reminder_text.should ==
        "Your Morning Accountability Call will begin at 8:00am. Expect a call in 10 minutes."
        event.name = "Something Cool"
        event.sms_reminder_text.should ==
          "Your Something Cool Call will begin at 8:00am. Expect a call in 10 minutes."
    end
  end

  it "has a name_with_pool" do
    pool1 = Pool.default_pool
    event = Factory(:event, :name => 'My Event Name')
    event.name_with_pool.should == 'My Event Name'
    pool2 = Factory(:pool, :name => 'PoolName')
    event.pool_id = pool2.id
    event.save
    event.name_with_pool.should == 'PoolName: My Event Name'
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
        '12:15am on Tu, W, and Th'
      @event.alter_schedule(:day => [2], :minute_of_hour => [15])
      @event.schedule_str.should == '12:15am on Tuesdays'
      @event.alter_schedule(:day => [2,3], :minute_of_hour => [15])
      @event.schedule_str.should == '12:15am on Tu and W'
      @event.alter_schedule(:day => [], :minute_of_hour => [15])
      @event.schedule_str.should == '12:15am, but No Days Selected!'
      @event.alter_schedule(:day => [0,1,2,3,4,5,6], :minute_of_hour => [15])
      @event.schedule_str.should == '12:15am Everyday'
      @event.alter_schedule(:day => [0,6], :minute_of_hour => [15])
      @event.schedule_str.should == '12:15am on Weekends'
      @event.schedule_day_string.should == 'Weekends'
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
    
    it "should have a skip_dates accessor and skip_dates setter to it's schedule" do
      @event.skip_dates.should == ''
      @event.skip_dates = '5/10/2020'
      @event.skip_dates.should == '5/10/2020'
      @event.days = [0,1,2,3,4,5,6]
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 7
      next_occur = @event.next_occurrence
      @event.skip_dates = next_occur.strftime("%m/%d/%Y")
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 6
    end

    it "should have a skip_dates accessor and skip_dates setter to it's schedule" do
      @event.days = [0,1,2,3,4,5,6]
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 7
      next_occur = @event.next_occurrence
      @event.skip_dates = next_occur.strftime("%m/%d/%Y") + ',' + (next_occur + 1.day).strftime("%m/%d/%Y")
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 5
      @event.save
      @event.reload
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 5
      user = @event.user
      user.time_zone.should == 'Mountain Time (US & Canada)'
      user.time_zone = 'Pacific Time (US & Canada)'
      user.save
      @event.reload
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 5
      user.time_zone = 'Mountain Time (US & Canada)'
      user.save
      @event.reload
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 5
    end

    it "should have a next_occurrence that respects exdates" do
      @event.days = [0,1,2,3,4,5,6]
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 7
      next_occur = @event.schedule.next_occurrence
      @event.next_occurrence.should == next_occur
      @event.skip_dates = next_occur.strftime("%m/%d/%Y")
      @event.schedule.occurrences_between(Time.now, Time.now + 7.days).count.should == 6
      @event.schedule.next_occurrence.should == nil # <----- This is the buggy behavior we're working around
      @event.next_occurrence.should == next_occur + 1.day
      @event.days = []
      @event.next_occurrence.should be_nil
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
      it "should not have occurrences if it has no days" do
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

  describe "make calls" do
    before(:each) do
      @pool = Factory(:pool, :timelimit => 10)
      @event = Factory(:event, :pool_id => @pool.id)
      @tc = mock('TwilioCaller')
      TwilioCaller.stub(:new).and_return(@tc)  
      @now = Time.now.utc
    end

    it "makes calls with the twilio caller" do
      @tc.should_receive(:start_call_for_event).with(@event)      
      @event.make_call(@now)
      @event.reload
      @event.user.called_count.should == 1
    end
    
    it "makes calls with the twilio caller in the middle of the call window" do
      @tc.should_receive(:start_call_for_event).with(@event)      
      @event.make_call(@now - 5.minutes)
      @event.reload
      @event.user.called_count.should == 1
    end

    it "does not make calls after the call window" do
      @tc.should_not_receive(:start_call_for_event).with(@event)      
      @event.make_call(@now - 12.minutes)
      @event.reload
      @event.user.called_count.should == 0
    end
  end
end
