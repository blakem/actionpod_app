# == Schema Information
# Schema version: 20110613233304
#
# Table name: pools
#
#  id                   :integer         not null, primary key
#  name                 :string(255)
#  admin_id             :integer         not null
#  created_at           :datetime
#  updated_at           :datetime
#  timelimit            :integer         not null
#  hide_optional_fields :boolean
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

  def self.default_pool
    self.where(:name => 'Default Group').sort_by(&:id).first  
  end  
  
end
