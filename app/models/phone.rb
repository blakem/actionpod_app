# == Schema Information
# Schema version: 20110417055418
#
# Table name: phones
#
#  id         :integer         not null, primary key
#  number     :string(255)
#  string     :string(255)
#  primary    :boolean
#  user_id    :integer         not null
#  created_at :datetime
#  updated_at :datetime
#

class Phone < ActiveRecord::Base
  belongs_to :user
  
  attr_accessible :string, :number, :primary, :user_id

  validates_presence_of :number, :string
  validates_each :number, do |record, attr, value|
     record.errors.add :string, 'is invalid' unless
        value && value =~ /\A\+1\d{10}\Z/
  end
  before_validation do
    if attribute_present?("string")
      self.number = string.gsub(/[^0-9]/, "")
      self.number = "1" + number unless number =~ /^1\d{10}$/
      self.number =  "+"  + number unless number =~ /^\+$/
    end
  end
end
