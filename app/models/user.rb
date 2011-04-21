# == Schema Information
# Schema version: 20110419204133
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
#  title                :string(255)
#  invite_code          :string(255)
#  use_ifmachine        :boolean
#  deleted_at           :datetime
#  location             :string(255)
#  confirmation_token   :string(255)
#  confirmed_at         :datetime
#  confirmation_sent_at :datetime
#  handle               :string(255)
#  hide_email           :boolean
#  about                :text
#  facebook_uid         :string(255)
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :invite_code, :time_zone, :name, :title,
                  :invite_code, :use_ifmachine, :location, :handle, :hide_email, :about, :phones_attributes, :facebook_uid

  has_many :events
  has_many :pools
  has_many :phones, :dependent => :destroy
  has_many :plans, :dependent => :destroy
  has_and_belongs_to_many :conferences
  accepts_nested_attributes_for :phones, :allow_destroy => true

  validates_each :invite_code, :on => :create do |record, attr, value|
      record.errors.add attr, "Please enter correct invite code." unless
        value && (value == secret_invite_code || InviteCode.find_by_name(value.downcase))
  end

  validates_format_of :handle, :with => /\A[0-9a-z]+\Z/i, :message => "can only be letters and numbers."
  validates_presence_of :name
  validates_uniqueness_of :handle

  after_initialize :init
  after_update     :update_events
  
  def init
    write_attribute(:time_zone, default_time_zone) unless read_attribute(:time_zone)
  end

  before_validation do
    if attribute_present?("email") && !attribute_present?("handle")
      self.handle = self.generate_handle_from_email
    end
  end

  def update_events
    if self.time_zone_changed?
      self.events.each do |event|
        old_time_zone = ActiveSupport::TimeZone.new(self.time_zone_was)
        new_time_zone = ActiveSupport::TimeZone.new(self.time_zone)
        new_time = old_time_zone.parse(event.time).in_time_zone(new_time_zone).strftime("%I:%M%p").downcase
        event.alter_schedule(:start_date => event.schedule.start_time.in_time_zone(self.time_zone).beginning_of_day)
        event.time = new_time
        event.save
      end
    end
  end
  
  def soft_delete
    self.deleted_at = Time.current
    self.save
  end
  
  def with_phone
    self.phones.build if self.phones.empty?
    self
  end
  
  def self.secret_invite_code
    "acti0np0duser"
  end
  
  def first_name
    name.blank? ? self.email.sub(/@.*/,'') : name.split[0].titlecase
  end
  
  def generate_handle_from_email
    genhandle = self.email.sub(/@.*/,'').downcase
    genhandle.gsub!(/[^0-9a-z]+/i, '')
    find_unique_handle(genhandle)
  end

  def primary_phone
    Phone.where(:user_id => self.id, :primary => true)[0]
  end

  def current_plan
    self.plans.sort_by(&:id).last
  end

  def find_unique_handle(genhandle, count=1)
    genhandle = genhandle + count.to_s if count > 1
    self.class.find_by_handle(genhandle) ? find_unique_handle(genhandle, count+1) : genhandle
  end
  
  def self.human_attribute_name(attribute_key_name, options = {})
    return "Primary Phone" if attribute_key_name.to_s == 'phones.string'
    return "Primary Phone" if attribute_key_name.to_s == 'phones.number'
    return "" if options[:default] == 'Invite code'
    return super(attribute_key_name, options)
  end

  private
    def default_time_zone
      'Pacific Time (US & Canada)'
    end      
end
