# == Schema Information
# Schema version: 20110801212422
#
# Table name: events
#
#  id                :integer         not null, primary key
#  name              :string(255)
#  schedule_yaml     :text
#  user_id           :integer         not null
#  created_at        :datetime
#  updated_at        :datetime
#  pool_id           :integer         not null
#  send_sms_reminder :boolean         default(TRUE)
#  pool_event        :boolean
#  auto_subscribe    :boolean
#

class Event < ActiveRecord::Base
  belongs_to :user
  belongs_to :pool

  validates_presence_of :name
  validates_format_of :skip_dates, 
    :with => /(\A\Z|\A(\d{1,2}\/\d{1,2}\/\d{4}(\,\d{1,2}\/\d{1,2}\/\d{4})*)\Z)/i, 
    :on => :update, 
    :message => "must be comma separated in mm/dd/yyyy format. i.e '5/10/2011,5/11/2011'"

  before_validation do
    self.name = self.default_name if self.name.blank?
  end
  
  def schedule
    days.empty? ? empty_schedule : schedule_actual
  end
  
  def time
    ampm_format(hour_of_day, minute_of_hour)
  end

  def time=(string)
    string = string.downcase.sub(/^0/,'')
    string =~ /^(\d+):(\d+)(\w+)$/    
    hour = $1
    minute = $2
    ampm = $3
    hour = hour.to_i
    minute = minute.to_i
    hour += 12 if ampm =~ /^pm$/i and hour != 12
    hour = 0 if hour == 12 and ampm =~ /^am$/i
    self.alter_schedule(:hour_of_day => [hour], :minute_of_hour => [minute])
    self.name = self.name.sub(/\d+(:\d{2})?(am|pm)/i, string) unless self.name.blank?
  end
  
  def skip_dates
    return @skip_dates if @skip_dates
    self.schedule.exdates.select{ |date| date > Time.now }.sort.
      map{ |date| date.strftime("%m/%d/%Y").sub(/^0/, '').sub(/\/0/, '/') }.join(',')
  end
  
  def skip_dates=(string)
    return unless self.user
    @skip_dates = string
    return unless string =~ /(\A\Z|\A(\d{1,2}\/\d{1,2}\/\d{4}(\,\d{1,2}\/\d{1,2}\/\d{4})*)\Z)/i
    @skip_dates = nil
    event_minute = self.minute_of_hour
    event_hour = self.hour_of_day
    event_time_zone = Time.now.in_time_zone(self.user.time_zone).zone
    exdates = string.split(',').map{ |s| 
      time_string = s + " #{event_hour}:#{event_minute} #{event_time_zone}"
      Time.zone.parse(DateTime.strptime(time_string , "%m/%d/%Y %H:%M %z").to_s)
    }
    self.alter_schedule(:exdates => exdates)
  end
  
  def next_occurrence(from = Time.now)
    sched = self.schedule
    next_occurrence = sched.next_occurrence(from)
    return next_occurrence if next_occurrence
    sched.occurrences_between(Time.now, Time.now + (sched.exdates.count + 21).days).first
  end
  
  def minute_of_hour
    schedule_validations[:minute_of_hour][0]
  end

  def hour_of_day
    schedule_validations[:hour_of_day][0]
  end

  def minute_of_day
    return hour_of_day*60 + minute_of_hour
  end

  def days
    schedule_validations[:day]
  end

  def days=(day_list)
    self.alter_schedule(:day => day_list)
  end
  
  def schedule_str
    return self.time + ", but No Days Selected!" if days.empty?
    day_string = schedule_day_string
    day_string = 'on ' + day_string unless day_string == 'Everyday'
    return self.time + ' ' + day_string
  end

  def schedule_day_string
    hash =  {
      0 => 'Sundays',
      1 => 'Mondays',
      2 => 'Tuesdays',
      3 => 'Wednesdays',
      4 => 'Thursdays',
      5 => 'Fridays',
      6 => 'Saturdays'
    }
    hash_short =  {
      0 => 'Su',
      1 => 'M',
      2 => 'Tu',
      3 => 'W',
      4 => 'Th',
      5 => 'F',
      6 => 'Sa'
    }
    if days == [0,1,2,3,4,5,6]
      day_string = 'Everyday'
    elsif days == [1,2,3,4,5]
      day_string = 'Weekdays'
    elsif days == [0,6]
      day_string = 'Weekends'
    elsif days.count == 1
      day_string = hash[days[0]]
    else
      day_string = days.sort.map { |k| hash_short[k] }.to_sentence
    end
    day_string
  end
  
  def alter_schedule(args)
    sched_hash = schedule_actual.to_hash
    sched_hash[:start_date] = args.delete(:start_date) if args[:start_date]
    sched_hash[:exdates] = args.delete(:exdates) if args[:exdates]
    sched_hash[:rrules][0][:validations].merge!(args)
    
    self.schedule_yaml = IceCube::Schedule.from_hash(sched_hash).to_yaml
  end
  
  def on_day(int)
    days.include?(int)
  end

  def default_name
    self.user.first_name + "'s " + self.time + " Call"
  end

  def name_in_second_person
    event_name = name.sub(/#{user.first_name}'s\s+/, '')
    event_name += ' call' unless event_name =~ /call$/i
    event_name
  end
  
  def sms_reminder_text
    event_name = self.name_in_second_person
    if self.name == self.default_name
      "Your #{self.pool.name} #{event_name} is about to begin. Expect a call in 10 minutes."
    else
      "Your #{event_name} will begin at #{self.time}. Expect a call in 10 minutes."
    end  
  end
  
  def name_with_pool
    default_pool = Pool.default_pool
    if default_pool.id == self.pool_id
      self.name
    else
      self.pool.name + ": " + self.name 
    end
  end
  
  def make_call(start_time)
    unless self.pool.after_call_window(start_time)
      TropoCaller.new.start_call_for_event(self)
      self.user.called_count += 1
      self.user.save
    end
  end

  def destroy
    destroy_delayed_jobs
    super
  end

  def save(*args)
    return super(*args) unless self.schedule_yaml_changed? or self.new_record?
    destroy_delayed_jobs
    return false unless super(*args)
    EventQueuer.new.queue_event(self)
    return true
  end
  
  def ampm_format(hour, minute)
    ampm = 'am'
    if hour.to_i >= 12
      hour = (hour.to_i - 12).to_s
      ampm = 'pm'
    end
    hour = '12' if hour.to_i == 0
    "#{hour}:" + sprintf('%02i', minute) + ampm
  end

  private
    def schedule_validations
      sched_hash = schedule_actual.to_hash
      validations = sched_hash[:rrules][0][:validations]
    end

    def default_schedule
      sched = empty_schedule
      sched.add_recurrence_rule IceCube::Rule.weekly(1).day(:monday, :tuesday, :wednesday, :thursday, :friday).hour_of_day(8).minute_of_hour(0)
      sched
    end
    
    def empty_schedule
      time_zone = self.user ? self.user.time_zone : 'Pacific Time (US & Canada)'
      IceCube::Schedule.new(Time.now.in_time_zone(time_zone).beginning_of_day)
    end
    
    def schedule_actual
      sched = IceCube::Schedule.from_yaml(self.schedule_yaml ||= default_schedule.to_yaml)
      sched.instance_variable_set(:@exdates, sched.exdates.map { |ed| Time.zone.parse(ed.to_s).in_time_zone(self.user.time_zone) })
      sched
    end

    def destroy_delayed_jobs
      DelayedJob.where(:obj_type => 'Event', :obj_id => self.id).each { |dj| dj.destroy }
      sched = schedule_yaml_was && schedule_yaml_changed? ? IceCube::Schedule.from_yaml(schedule_yaml_was) : schedule
      next_run_time = sched.next_occurrence
      return unless next_run_time
      next_run_time = next_run_time.utc
      scheduled_events = DelayedJob.where(
        :obj_type    => 'Event',
        :obj_jobtype => 'make_call',
        :run_at      => next_run_time,
        :pool_id     => self.pool_id
      )
      PoolQueuer.new.dequeue_pool(self.pool_id, next_run_time) if scheduled_events.empty?
    end
end
