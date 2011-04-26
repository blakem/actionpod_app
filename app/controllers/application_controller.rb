class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :ensure_domain
  before_filter :set_timezone

  def admin_signed_in?
    user_signed_in? && current_user.admin?
  end

  def sublayout 
    @view_options ? 'sidebar' : 'main'
  end

  private
    def ensure_domain
      return unless Rails.env.production?
      if (request.env['HTTP_HOST'] != 'www.15minutecalls.com' && request.env['HTTP_HOST'] != 'actionpods-staging.heroku.com')
        redirect_to "http://www.15minutecalls.com", :status => 301
      end
    end
  
    def set_timezone
      Time.zone = current_user.time_zone if current_user
    end
  
    def set_profile_values
      @user = current_user
      @title = @user.name
      @nextcalls = build_nextcalls(@user)
      @your = 'Your'
      @youhave = 'You have'
      @view_options = {}
    end
  
    def build_nextcalls(user)
      calls = []
      start_time = Time.now
      end_time = start_time + 7.days
      user.events.each do |event|
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          calls.push(occurrence.in_time_zone(current_user.time_zone))
        end
      end
      calls = calls.sort{ |a,b| a <=> b }.map { |c| c.strftime("%l:%M%p on %A").sub(/AM/,'am').sub(/PM/,'pm').strip }
      calls[0..4]
    end

    def build_timeslots
      slots = []
      build_scheduled_events.each do |occurrence|
        slot = occurrence[0].strftime('%l:%M%p').downcase.strip
        slots.push(slot) unless slots.include?(slot)
      end
      current_user.events.each do |event|
        slots.delete(event.time.downcase.strip)
      end
      slots.map{ |s| {:time => s, :string => "#{s} on Weekdays"} }
    end
    
    def build_scheduled_events
      hash = {}
      start_time = Time.now.beginning_of_week + 6.days
      end_time = start_time + 7.days
      Event.all.each do |event|
        next unless (event.minute_of_hour == 0 or current_user.admin?)
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          occurrence = occurrence.in_time_zone(current_user.time_zone)
          hash[occurrence] ||= 0
          hash[occurrence] += 1
        end
      end
      hash.each.sort
    end
    
    def build_call_groups(user)
      call_groups = {}
      my_calls = {}
      pools = user.memberships
      Event.all.each do |event|
        next unless pools.include?(event.pool)
        occurrence = event.schedule.next_occurrence
        next unless occurrence
        occurrence = occurrence.in_time_zone(user.time_zone)
        time = occurrence.strftime('%l:%M%p').downcase.strip
        call_groups[time] ||= {
          :time => time,
          :events => [],
          :minute => occurrence.hour * 60 + occurrence.min,
        }
        call_groups[time][:events].push [event.id, event.user_id]
        my_calls[time] = true if event.user_id == user.id
      end
      call_groups.
        select{ |k,v| my_calls[k]}.
        sort{ |a,b| a[1][:minute] <=> b[1][:minute] }.
        map{ |cg| {
          :time => cg[0], 
          :events => cg[1][:events].sort { |a,b| b[1] <=> a[1] } 
        } }
    end
end
