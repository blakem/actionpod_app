# == Schema Information
# Schema version: 20110330183523
#
# Table name: events
#
#  id            :integer         not null, primary key
#  name          :string(255)
#  schedule_yaml :text
#  user_id       :integer         not null
#  created_at    :datetime
#  updated_at    :datetime
#  pool_id       :integer         not null
#

class Event < ActiveRecord::Base
  # include ScheduleAttributes

  belongs_to :user
  belongs_to :pool

  after_initialize :init

  def init
    self.schedule_yaml ||= default_schedule.to_yaml
  end
  
  def schedule 
    IceCube::Schedule.from_yaml(schedule_yaml)
  end
  
  def schedule_str(string = self.schedule.to_s)
    string.sub!(/Weekly/, '')
    string.sub!(/on the (\d+)\w+ minute of the hour/, '')
    minute = $1
    string.sub!(/on the (\d+)\w+ hour of the day/, '')
    hour = $1
    string.strip!.gsub!(/\s+/, ' ')
    ampm = 'am'
    if hour.to_i >= 12
      hour = (hour.to_i - 12).to_s
      ampm = 'pm'
    end
    hour = '12' if hour.to_i == 0
    string = "#{hour}:" + sprintf('%02i', minute) + ampm + " #{string}"
  end
  
  def alter_schedule(args)
    sched_hash = schedule.to_hash
    sched_hash[:start_date] = args.delete(:start_date) if args[:start_date]
    sched_hash[:rrules][0][:validations].merge!(args)
    self.schedule_yaml = IceCube::Schedule.from_hash(sched_hash).to_yaml
  end

  def make_call # XXX needs tests
    account_sid = 'AC2e57bf710b77d765d280786bc07dbacc'
    account_token = 'fc9bd67bb8deee6befd3ab0da3973718'
    api_version = '2010-04-01'
    base_url =  "http://actionpods.heroku.com/callme"
    caller_id = '415-314-1222'
    d = {
        'From' => caller_id,
        'To' => user.primary_phone,
        'Url' => base_url + '/hellomoto.xml',
    }
    resp = ''
    begin
        account = Twilio::RestAccount.new(account_sid, account_token)
        resp = account.request(
            "/#{api_version}/Accounts/#{account_sid}/Calls",
            'POST', d)
        resp.error! unless resp.kind_of? Net::HTTPSuccess
    rescue StandardError => bang
        redirect_to({ :action => '.', 'msg' => "Error #{ bang } #{resp.body.inspect}" })
        return
    end
  end
    
  private
    def default_schedule
      sched = IceCube::Schedule.new(Time.zone.now.yesterday)
      sched.add_recurrence_rule IceCube::Rule.weekly(1).day(:monday, :tuesday, :wednesday, :thursday, :friday).hour_of_day(8).minute_of_hour(0)
      sched
    end
end
