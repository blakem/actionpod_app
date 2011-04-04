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
  
end
