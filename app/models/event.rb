# == Schema Information
# Schema version: 20110418153156
#
# Table name: events
#
#  id                :integer         not null, primary key
#  name              :string(255)
#  schedule_yaml     :text
#  user_id           :integer         not null
#  created_at        :datetime
#  updated_at        :datetime
#  pool_id           :integer         not null
#  send_sms_reminder :boolean         default(TRUE)
#

class Event < ActiveRecord::Base
  belongs_to :user
  belongs_to :pool

  validates_presence_of :name

  before_validation do
    if self.name.blank?
      self.name = (self.user.first_name + "'s " + self.time + " Call")
    end
  end
  
  def schedule
    days.empty? ? empty_schedule : schedule_actual
  end
  
  def time
    ampm_format(hour_of_day, minute_of_hour)
  end

  def time=(string)
    string =~ /^(\d+):(\d+)(\w+)$/
    hour = $1
    minute = $2
    ampm = $3
    hour = hour.to_i
    minute = minute.to_i
    hour += 12 if ampm =~ /^pm$/i and hour != 12
    hour = 0 if hour == 12 and ampm =~ /^am$/i
    self.alter_schedule(:hour_of_day => [hour], :minute_of_hour => [minute])
  end
  
  def minute_of_hour
    schedule_validations[:minute_of_hour][0]
  end

  def hour_of_day
    schedule_validations[:hour_of_day][0]
  end

  def minute_of_day
    return hour_of_day*60 + minute_of_hour
  end

  def days
    schedule_validations[:day]
  end

  def days=(day_list)
    self.alter_schedule(:day => day_list)
  end
  
  def schedule_str
    return self.time + ", but No Days Selected!" if days.empty?
    hash =  {
      0 => 'Sundays',
      1 => 'Mondays',
      2 => 'Tuesdays',
      3 => 'Wednesdays',
      4 => 'Thursdays',
      5 => 'Fridays',
      6 => 'Saturdays'
    }
    if days == [0,1,2,3,4,5,6]
      day_string = 'Everyday'
    elsif days == [1,2,3,4,5]
      day_string = 'on Weekdays'
    elsif days == [0,6]
      day_string = 'on Weekends'
    else
      day_string = 'on ' + days.sort.map { |k| hash[k] }.to_sentence
    end
    return self.time + ' ' + day_string
  end
  
  def alter_schedule(args)
    sched_hash = schedule_actual.to_hash
    sched_hash[:start_date] = args.delete(:start_date) if args[:start_date]
    sched_hash[:rrules][0][:validations].merge!(args)
    self.schedule_yaml = IceCube::Schedule.from_hash(sched_hash).to_yaml
  end
  
  def on_day(int)
    days.include?(int)
  end

  def name_in_second_person
    name.sub(/#{user.first_name}'s\s+/, '')
  end

  def make_call
    TwilioCaller.new.start_call_for_event(self)
  end

  def destroy
    destroy_delayed_jobs
    super
  end

  def save(*args)
    return super(*args) unless self.schedule_yaml_changed? or self.new_record?
    destroy_delayed_jobs
    return false unless super(*args)
    EventQueuer.new.queue_event(self)
    return true
  end
  
  def self.available_hours
    (1..11).to_a.map { |h| "#{h}:00am"} + ["12:00pm"] + (1..11).to_a.map { |h| "#{h}:00pm" } + ["12:00am"]
  end
  
  private
    def schedule_validations
      sched_hash = schedule_actual.to_hash
      validations = sched_hash[:rrules][0][:validations]
    end

    def default_schedule
      sched = empty_schedule
      sched.add_recurrence_rule IceCube::Rule.weekly(1).day(:monday, :tuesday, :wednesday, :thursday, :friday).hour_of_day(8).minute_of_hour(0)
      sched
    end
    
    def empty_schedule
      time_zone = self.user ? self.user.time_zone : 'Pacific Time (US & Canada)'
      IceCube::Schedule.new(Time.now.in_time_zone(time_zone).beginning_of_day)
    end
    
    def schedule_actual
      IceCube::Schedule.from_yaml(self.schedule_yaml ||= default_schedule.to_yaml)
    end

    def ampm_format(hour, minute)
      ampm = 'am'
      if hour.to_i >= 12
        hour = (hour.to_i - 12).to_s
        ampm = 'pm'
      end
      hour = '12' if hour.to_i == 0
      "#{hour}:" + sprintf('%02i', minute) + ampm
    end

    def destroy_delayed_jobs
      DelayedJob.where(:obj_type => 'Event', :obj_id => self.id).each { |dj| dj.destroy }
      sched = schedule_yaml_was && schedule_yaml_changed? ? IceCube::Schedule.from_yaml(schedule_yaml_was) : schedule
      next_run_time = sched.next_occurrence
      return unless next_run_time
      next_run_time = next_run_time.utc
      scheduled_events = DelayedJob.where(
        :obj_type    => 'Event',
        :obj_jobtype => 'make_call',
        :run_at      => next_run_time,
        :pool_id     => self.pool_id
      )
      PoolQueuer.new.dequeue_pool(self.pool_id, next_run_time) if scheduled_events.empty?
    end
end
