# == Schema Information
# Schema version: 20110330183523
#
# Table name: events
#
#  id            :integer         not null, primary key
#  name          :string(255)
#  schedule_yaml :text
#  user_id       :integer         not null
#  created_at    :datetime
#  updated_at    :datetime
#  pool_id       :integer         not null
#

class Event < ActiveRecord::Base
  # include ScheduleAttributes

  belongs_to :user
  belongs_to :pool

  after_initialize :init

  def init
    self.schedule_yaml ||= default_schedule.to_yaml
  end
  
  def schedule 
    IceCube::Schedule.from_yaml(schedule_yaml)
  end
  
  def time
    sched_hash = schedule.to_hash
    validations = sched_hash[:rrules][0][:validations]
    hour = validations[:hour_of_day][0]
    minute = validations[:minute_of_hour][0]
    ampm_format(hour, minute)
  end

  def time=(string)
    string =~ /^(\d+):(\d+)(\w+)$/
    hour = $1
    minute = $2
    ampm = $3
    hour = hour.to_i
    minute = minute.to_i
    hour += 12 if ampm =~ /^pm$/i
    self.alter_schedule(:hour_of_day => [hour], :minute_of_hour => [minute])
  end
  
  def schedule_str(string = self.schedule.to_s)
    string.sub!(/Weekly/, '')
    string.sub!(/on the (\d+)\w+ minute of the hour/, '')
    minute = $1
    string.sub!(/on the (\d+)\w+ hour of the day/, '')
    hour = $1
    string.strip!.gsub!(/\s+/, ' ')
    ampm_format(hour, minute) + " #{string}"
  end
  
  def alter_schedule(args)
    sched_hash = schedule.to_hash
    sched_hash[:start_date] = args.delete(:start_date) if args[:start_date]
    sched_hash[:rrules][0][:validations].merge!(args)
    self.schedule_yaml = IceCube::Schedule.from_hash(sched_hash).to_yaml
  end

  def make_call
    TwilioCaller.new.start_call_for_event(self)
  end
    
  def self.available_hours
    (1..11).to_a.map { |h| "#{h}:00am"} + ["12:00pm"] + (1..11).to_a.map { |h| "#{h}:00pm" }
  end
  
  private
    def default_schedule
      time_zone = self.user ? self.user.time_zone : 'Pacific Time (US & Canada)'
      sched = IceCube::Schedule.new(Time.now.in_time_zone(time_zone).beginning_of_day)
      sched.add_recurrence_rule IceCube::Rule.weekly(1).day(:monday, :tuesday, :wednesday, :thursday, :friday).hour_of_day(8).minute_of_hour(0)
      sched
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
end
