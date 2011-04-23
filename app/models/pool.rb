# == Schema Information
# Schema version: 20110404182851
#
# Table name: pools
#
#  id         :integer         not null, primary key
#  name       :string(255)
#  user_id    :integer         not null
#  created_at :datetime
#  updated_at :datetime
#  timelimit  :integer         not null
#

class Pool < ActiveRecord::Base
  belongs_to :user

  after_initialize :init

  def init
    self.timelimit ||= 15
  end
  
  def after_call_window(time)
    Time.now.utc > time + self.timelimit.minutes
  end

  def self.default_pool
    self.where(:name => 'Default Pool').sort{ |a,b| a.id <=> b.id }.first  
  end
  
end
