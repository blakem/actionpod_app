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
  include ScheduleAttributes

  belongs_to :user
  belongs_to :pool

  after_initialize :init

  def init
    self.schedule_yaml = default_schedule.to_yaml
  end
  
  def schedule_str
    string = self.schedule.to_s
    string.match(/on the (\d+)\w+ hour of the day/)
    hour = $1
    ampm = hour.to_i >= 12 ? 'pm' : 'am'
    string.match(/on the (\d+)\w+ minute of the hour/)
    minute = $1

    string.gsub!(/ on the (\d+)\w+ hour of the day/, '')
    string.gsub!(/ on the (\d+)\w+ minute of the hour/, '')
    string.gsub!(/Weekly /, '')

    string = "#{hour}:" + sprintf('%02i', minute) + ampm + " #{string}"
  end
  
  private
    def default_schedule
      sched = IceCube::Schedule.new(Time.zone.now)
      sched.add_recurrence_rule IceCube::Rule.weekly(1).day(:monday, :tuesday, :wednesday, :thursday, :friday).hour_of_day(8).minute_of_hour(0)
      sched
    end
end
