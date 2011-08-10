# == Schema Information
# Schema version: 20110624231622
#
# Table name: pools
#
#  id                     :integer         not null, primary key
#  name                   :string(255)
#  admin_id               :integer         not null
#  created_at             :datetime
#  updated_at             :datetime
#  timelimit              :integer         not null
#  hide_optional_fields   :boolean
#  public_group           :boolean
#  allow_others_to_invite :boolean
#  description            :text
#  available_time_mode    :string(255)
#  send_conference_email  :boolean
#  merge_type             :integer
#

class Pool < ActiveRecord::Base
  belongs_to :user, :foreign_key => 'admin_id'
  has_and_belongs_to_many :users, :order => 'name asc'
  has_many :events
  validates_presence_of :name
  validates_numericality_of :timelimit, :greater_than => 1, :less_than_or_equal_to => 30
  
  after_initialize :init
  before_destroy :destroy_invites

  def init
    self.timelimit ||= 15
    write_attribute(:public_group, false) unless read_attribute(:public_group)
    write_attribute(:allow_others_to_invite, false) unless read_attribute(:allow_others_to_invite)
  end
  
  def normal_events
    events.where(:pool_event => false)
  end

  def pool_events
    events.where(:pool_event => true)
  end
  
  def after_call_window(time)
    Time.now.utc > time + self.timelimit.minutes
  end

  def available_timelimits
    list = [5, 10, 15, 20, 30]
    list << self.timelimit unless list.include?(timelimit)
    list.sort
  end

  def destroy_invites
    MemberInvite.where(:pool_id => self.id).each { |i| i.destroy }    
  end
  
  def add_member(user)
    user.pools << self unless user.pools.include?(self)
  end

  def self.default_pool
    self.where(:name => 'General Accountability Group').sort_by(&:id).first  
  end
  
  def name_plus_group
    string = self.name.strip
    string += ' group' unless string =~ / group$/i
    string
  end

  def available_times
    if available_time_mode == '30'
      (["12:30am"] + (1..11).to_a.map { |h| ["#{h}:00am", "#{h}:30am"]} + ["12:00pm", "12:30pm"] + 
      (1..11).to_a.map { |h| ["#{h}:00pm", "#{h}:30pm"] } + ["12:00am"]).flatten
    elsif available_time_mode == '15'
      (["12:15am", "12:30am", "12:45am"] + 
       (1..11).to_a.map { |h| ["#{h}:00am", "#{h}:15am", "#{h}:30am", "#{h}:45am"]} + 
       ["12:00pm", "12:15pm", "12:30pm", "12:45pm"] + 
       (1..11).to_a.map { |h| ["#{h}:00pm", "#{h}:15pm", "#{h}:30pm", "#{h}:45pm"] } + 
       ["12:00am"]).flatten
    elsif available_time_mode == '20'
      (["12:20am", "12:40am"] + 
       (1..11).to_a.map { |h| ["#{h}:00am", "#{h}:20am", "#{h}:40am"]} + 
       ["12:00pm", "12:20pm", "12:40pm"] + 
       (1..11).to_a.map { |h| ["#{h}:00pm", "#{h}:20pm", "#{h}:40pm"] } + 
       ["12:00am"]).flatten
    else
      (1..11).to_a.map { |h| "#{h}:00am"} + ["12:00pm"] + (1..11).to_a.map { |h| "#{h}:00pm" } + ["12:00am"]
    end
  end
  
  def timeslots(user, skip_mine = false)
    timeslots = {}
    Event.where(:pool_id => self.id).each do |event|
      occurrence = event.next_occurrence
      next unless occurrence
      occurrence = occurrence.in_time_zone(user.time_zone)
      time = occurrence.strftime('%l:%M%p').downcase.strip
      days = event.days
      event_ids = [event.id]
      if timeslots[time]
        days = (days + timeslots[time][:days]).uniq.sort
        event_ids = (timeslots[time][:event_ids] + event_ids).sort
      end
      
      if days.count == 1
        hash =  {
          0 => 'Sundays',
          1 => 'Mondays',
          2 => 'Tuesdays',
          3 => 'Wednesdays',
          4 => 'Thursdays',
          5 => 'Fridays',
          6 => 'Saturdays'
        }
        day_of_week = hash[days.first]
        string = "#{time} on #{day_of_week}"
      else
        string = "#{time} on selected Weekdays"
      end
      
      timeslots[time] = {
         :time => time,
         :string => string,
         :minute => occurrence.hour * 60 + occurrence.min,
         :days => days,
         :event_ids => event_ids,
         :pool_id => self.id,
      }
    end
    if skip_mine
      user.events.select{|e| e.pool_id == self.id}.each do |event|
        timeslots.delete(event.time.downcase.strip)
      end
    end
    timeslots.values.sort{ |a,b| a[:minute] <=> b[:minute] }
  end
  
  def can_invite?(user)
    return true if self.admin_id == user.id
    return false unless user.pools.include?(self)
    return true if self.public_group
    return true if self.allow_others_to_invite
  end
  
end
