# == Schema Information
# Schema version: 20110616070531
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
#

class Pool < ActiveRecord::Base
  belongs_to :user, :foreign_key => 'admin_id'
  has_and_belongs_to_many :users, :order => 'name asc'
  validates_presence_of :name
  validates_numericality_of :timelimit, :greater_than => 1, :less_than_or_equal_to => 30
  
  after_initialize :init
  before_destroy :destroy_invites

  def init
    self.timelimit ||= 15
    write_attribute(:public_group, false) unless read_attribute(:public_group)
    write_attribute(:allow_others_to_invite, false) unless read_attribute(:allow_others_to_invite)
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
      
      timeslots[time] = {
         :time => time,
         :string => "#{time} on selected Weekdays",
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
  
end
