# == Schema Information
# Schema version: 20110415220244
#
# Table name: phones
#
#  id                  :integer         not null, primary key
#  user_id             :integer
#  phone_number        :string(255)
#  phone_number_string :string(255)
#  created_at          :datetime
#  updated_at          :datetime
#

class Phone < ActiveRecord::Base
  belongs_to :user

  before_validation do
    if attribute_present?("phone_number_string")
      self.phone_number = phone_number_string.gsub(/[^0-9]/, "")
      self.phone_number = "1" + phone_number unless phone_number =~ /^1\d{10}$/
      self.phone_number =  "+"  + phone_number unless phone_number =~ /^\+$/
    end
  end
end
