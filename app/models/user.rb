# == Schema Information
# Schema version: 20110506211752
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
#  phonetic_name        :string(255)
#  called_count         :integer         default(0)
#  answered_count       :integer         default(0)
#  placed_count         :integer         default(0)
#  incoming_count       :integer         default(0)
#  missed_in_a_row      :integer         default(0)
#  made_in_a_row        :integer         default(0)
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :invite_code, :time_zone, :name, :title,
                  :invite_code, :use_ifmachine, :location, :handle, :hide_email, :about, :phones_attributes, :facebook_uid,
                  :phonetic_name

  has_many :events
  has_many :pools
  has_many :phones, :dependent => :destroy
  has_many :plans, :dependent => :destroy
  has_many :preferences, :dependent => :destroy
  has_many :preferenced_members, :through => :preferences, :source => :other_user
  has_and_belongs_to_many :conferences, :order => 'id DESC'
  accepts_nested_attributes_for :phones, :allow_destroy => true

  validates_each :invite_code, :on => :create do |record, attr, value|
      record.errors.add attr, "Please enter correct invite code." unless
        value && (value == secret_invite_code || InviteCode.find_by_name(value.strip.downcase))
  end

  validates_format_of :handle, :with => /\A[0-9a-z]+\Z/i, :on => :update, :message => "can only be letters and numbers."
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
    if attribute_present?("name") && !attribute_present?("phonetic_name")
      self.phonetic_name = self.name
    end  end

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

  def memberships
    self.admin ? Pool.all : [Pool.default_pool]
  end

  def prefers?(other_user)
    preference = preferences.find_by_other_user_id(other_user.id)
    preference ? preference.prefer_more : false
  end

  def avoids?(other_user)
    preference = preferences.find_by_other_user_id(other_user.id)
    preference ? !preference.prefer_more : false
  end
  
  def prefer!(other_user)
    return if other_user.id == self.id
    unprefer!(other_user)
    preferences.create!(:other_user_id => other_user.id, :prefer_more => true)
  end
  
  def avoid!(other_user)
    return if other_user.id == self.id
    unprefer!(other_user)
    preferences.create!(:other_user_id => other_user.id, :prefer_more => false)
  end
  
  def unprefer!(other_user)
    return if other_user.id == self.id
    preference = preferences.find_by_other_user_id(other_user.id)
    preference.destroy if preference
  end
  
  def preferred_members
     preferences.select { |p| p.prefer_more }.map(&:other_user)
  end

  def avoided_members
     preferences.select { |p| !p.prefer_more }.map(&:other_user)
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
    return handle_was if handle_changed? and handle == ''
    genhandle = genhandle + count.to_s if count > 1
    self.class.find_by_handle(genhandle) ? find_unique_handle(genhandle, count+1) : genhandle
  end
  
  def next_call_time
    events.map { |e| e.next_occurrence }.select{ |o| o }.sort.first
  end
  
  def next_call_time_string
    call_time = self.next_call_time
    return '' unless call_time
    if call_time.today?
      day = "Today"
    elsif call_time < Time.now.beginning_of_day + 48.hours
      day = "Tomorrow"
    else
      day = call_time.strftime("%A")
    end
    time = call_time.strftime(" at %I:%M%P").sub(/ 0/,' ').humanize
    day + time
  end
  
  def last_successful_call_time
    conference = self.conferences.select { |c| c.status == 'completed' }.first
    conference ? conference.created_at : nil
  end
  
  def member_status
    if !confirmed_at
      "Hasn't confirmed email"
    elsif made_in_a_row == 1
      "Made last call"
    elsif made_in_a_row > 1
      "Made #{made_in_a_row} calls in a row"
    elsif missed_in_a_row == 1
      "Missed last call"
    elsif missed_in_a_row > 1
      "Missed #{missed_in_a_row} calls in a row"
    else
      "Has never been called"
    end
  end
  
  def profile_path
    "/member/#{self.handle}"
  end

  def remote_profile_path
    'http://www.15minutecalls.com' + profile_path
  end
  
  def self.human_attribute_name(attribute_key_name, options = {})
    return "Primary Phone" if attribute_key_name.to_s == 'phones.string'
    return "Primary Phone" if attribute_key_name.to_s == 'phones.number'
    return "" if attribute_key_name.to_s == 'invite_code'
    return super(attribute_key_name, options)
  end

  def self.blake
    return self.find_by_email('blakem@15minutecalls.com') || self.find_by_email('blakem30@yahoo.com')
  end

  def self.blake_test
    return self.find_by_email('blakem@blakem.com')
  end

  private
    def default_time_zone
      'Pacific Time (US & Canada)'
    end      
end
