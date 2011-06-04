# == Schema Information
# Schema version: 20110601000355
#
# Table name: pools
#
#  id         :integer         not null, primary key
#  name       :string(255)
#  admin_id   :integer         not null
#  created_at :datetime
#  updated_at :datetime
#  timelimit  :integer         not null
#

class Pool < ActiveRecord::Base
  belongs_to :user, :foreign_key => 'admin_id'
  has_and_belongs_to_many :users
  
  after_initialize :init

  def init
    self.timelimit ||= 15
  end
  
  def after_call_window(time)
    Time.now.utc > time + self.timelimit.minutes
  end

  def self.default_pool
    self.where(:name => 'Default Group').sort_by(&:id).first  
  end
  
end
