# == Schema Information
# Schema version: 20110503212230
#
# Table name: preferences
#
#  id            :integer         not null, primary key
#  user_id       :integer
#  other_user_id :integer
#  prefer_more   :boolean
#  created_at    :datetime
#  updated_at    :datetime
#

class Preference < ActiveRecord::Base
  attr_accessible :other_user_id, :prefer_more
  
  belongs_to :user, :foreign_key => 'user_id', :class_name => "User"
  belongs_to :other_user, :foreign_key => 'other_user_id', :class_name => "User"

  validates :user_id, :presence => true
  validates :other_user_id, :presence => true

  def preference_string
    prefer_more ? 'prefers' : 'avoids'
  end
end
