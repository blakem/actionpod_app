# == Schema Information
# Schema version: 20110419233934
#
# Table name: plans
#
#  id         :integer         not null, primary key
#  body       :text
#  user_id    :integer         not null
#  created_at :datetime
#  updated_at :datetime
#

class Plan < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :body

  def self.default_body
    "Three Goals I have for this week:\n  1.\n  2.\n  3.\n\n\nWhat I'm going to do today to move closer to those goals:\n" +
    ("  *\n" * 8)
  end

end
