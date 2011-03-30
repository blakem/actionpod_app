# == Schema Information
# Schema version: 20110329225808
#
# Table name: events
#
#  id            :integer         not null, primary key
#  name          :string(255)
#  schedule_yaml :text
#  user_id       :integer         not null
#  created_at    :datetime
#  updated_at    :datetime
#

class Event < ActiveRecord::Base
  include ScheduleAttributes

  belongs_to :user

  after_initialize :init

  def init
    self.schedule_yaml = default_schedule.to_yaml
  end
  
  private
    def default_schedule
      sched = IceCube::Schedule.new(Time.zone.now)
      sched.add_recurrence_rule IceCube::Rule.weekly(1).day(:monday, :tuesday, :wednesday, :thursday, :friday).hour_of_day(8).minute_of_hour(0)
      sched
    end
end
