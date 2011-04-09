# == Schema Information
# Schema version: 20110409013012
#
# Table name: users
#
#  id                   :integer         not null, primary key
#  email                :string(255)     default(""), not null
#  encrypted_password   :string(128)     default(""), not null
#  password_salt        :string(255)     default(""), not null
#  reset_password_token :string(255)
#  remember_token       :string(255)
#  remember_created_at  :datetime
#  sign_in_count        :integer         default(0)
#  current_sign_in_at   :datetime
#  last_sign_in_at      :datetime
#  current_sign_in_ip   :string(255)
#  last_sign_in_ip      :string(255)
#  created_at           :datetime
#  updated_at           :datetime
#  admin                :boolean
#  time_zone            :string(255)
#  name                 :string(255)
#  primary_phone        :string(255)
#  title                :string(255)
#  invite_code          :string(255)
#  use_ifmachine        :boolean
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :invite_code, :time_zone, :name, :primary_phone, :title,
                  :invite_code

  has_many :events
  has_many :pools

  validates_each :invite_code, :on => :create do |record, attr, value|
      record.errors.add attr, "Please enter correct invite code." unless
        value && (value == User.secret_invite_code || InviteCode.find_by_name(value.downcase))
  end
  validates_format_of :primary_phone, :with => /\A\+1\d{10}\Z/

  after_initialize :init
  
  def init
    self.time_zone ||= 'Pacific Time (US & Canada)'
  end

  before_validation do
    if attribute_present?("primary_phone")
      self.primary_phone = primary_phone.gsub(/[^0-9]/, "")
      self.primary_phone = "1" + primary_phone unless primary_phone =~ /^1\d{10}$/
      self.primary_phone =  "+"  + primary_phone unless primary_phone =~ /^\+$/
    end
  end

  def save(*args)
    rv = super(*args)
    return rv unless rv
    self.events.each do |event|
      event.alter_schedule(:start_date => event.schedule.start_time.in_time_zone(self.time_zone).beginning_of_day)
      event.save
    end
    rv
  end

  def self.secret_invite_code
    "acti0np0duser"
  end
end
