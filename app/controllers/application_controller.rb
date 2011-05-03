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
  
    def set_profile_values(user = current_user)
      @user = user
      @current_user = current_user
      @title = @user.name
      @nextcalls = build_nextcalls(@user)
      @your = 'Your'
      @youhave = 'You have'
      @my = 'My'
      @mailer = false
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
      build_scheduled_events.each do |hash|
        slot = hash[:occurrence].strftime('%l:%M%p').downcase.strip
        slots.push(slot) unless slots.include?(slot)
      end
      current_user.events.each do |event|
        slots.delete(event.time.downcase.strip)
      end
      slots.map{ |s| {:time => s, :string => "#{s} on selected Weekdays"} }
    end
    
    def build_scheduled_events
      hash = {}
      start_time = Time.now.beginning_of_week + 6.days
      end_time = start_time + 7.days
      Event.all.each do |event|
        next unless (event.minute_of_hour == 0 or current_user.admin?)
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          occurrence = occurrence.in_time_zone(current_user.time_zone)
          key = event.pool.id.to_s + ':' + occurrence.to_s
          hash[key] ||= {}
          hash[key][:count] ||= 0
          hash[key][:count] += 1
          hash[key][:pool_id] = event.pool.id
          hash[key][:occurrence] = occurrence
        end
      end
      hash.each_value.sort { |a,b| 
        first = a[:occurrence] <=> b[:occurrence]; 
        first != 0 ? first : a[:pool_id] <=> b[:pool_id] }
    end
    
    def build_call_groups(viewer, user = nil)
      call_groups = {}
      my_calls = {}
      pools = viewer.memberships
      Event.all.each do |event|
        next unless pools.include?(event.pool)
        occurrence = event.next_occurrence
        next unless occurrence
        occurrence = occurrence.in_time_zone(viewer.time_zone)
        time = occurrence.strftime('%l:%M%p').downcase.strip
        key = event.pool_id.to_s + ':' + time
        call_groups[key] ||= {
          :time => time,
          :pool => event.pool_id,
          :events => [],
          :minute => occurrence.hour * 60 + occurrence.min,
        }
        call_groups[key][:events].push [event.id, event.user_id]
        my_calls[key] = true if user and event.user_id == user.id
      end
      call_groups = call_groups.select{ |k,v| my_calls[k]} if user      
      call_groups.
        sort{ |a,b| 
          first = a[1][:minute] <=> b[1][:minute]
          first != 0 ? first : a[1][:pool] <=> b[1][:pool] 
        }.map{ |cg| {
          :time => cg[1][:time],
          :pool => cg[1][:pool],
          :events => cg[1][:events].sort { |a,b| b[1] <=> a[1] } 
        } }
    end
end
