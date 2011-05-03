class Preference < ActiveRecord::Base
  attr_accessible :other_user_id, :prefer_more
  
  belongs_to :user, :foreign_key => 'user_id', :class_name => "User"
  belongs_to :other_user, :foreign_key => 'other_user_id', :class_name => "User"

  validates :user_id, :presence => true
  validates :other_user_id, :presence => true
end
