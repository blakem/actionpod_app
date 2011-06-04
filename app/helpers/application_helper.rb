module ApplicationHelper
  def title
    base_title = "15 Minute Calls"
    base_title = "(dev) " + base_title if Rails.env.development?
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  def logo
    image_tag("logo.png", :alt => "15 Minute Calls", :class => "round")
  end
    
  def pretty_object_error_messages(object)
    return "" if object.errors.empty?
    html = %(<div class="flash alert round">)
    html += "<b>Ooops. The following errors need to be fixed:</b><br/>"
    errors = []
    object.errors.each do |key, value|
      errors.push(object.class.human_attribute_name(key) + " " + value)
    end
    html += errors.uniq.map{ |error| '- ' + error + "<br/>\n" }.join('')
    html += %(</div>)
    html.html_safe
  end

  private
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
      end_time = start_time + 1.month
      user.events.each do |event|
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          calls.push(occurrence.in_time_zone(current_user.time_zone))
        end
      end
      calls = calls.sort{ |a,b| a <=> b }.map { |c| c.strftime("%l:%M%p on %a %b #{c.day.ordinalize}").sub(/AM/,'am').sub(/PM/,'pm').strip }
      calls[0..4]
    end

    def build_timeslots(current_user = current_user)
      slots = []
      build_scheduled_events(current_user).sort{ |a,b| a[:minute_of_day] <=> b[:minute_of_day]}.each do |hash|
        slot = hash[:occurrence].strftime('%l:%M%p').downcase.strip
        slots.push(slot) unless slots.include?(slot)
      end
      current_user.events.each do |event|
        slots.delete(event.time.downcase.strip)
      end
      slots.map{ |s| {:time => s, :string => "#{s} on selected Weekdays"} }
    end
  
    def build_scheduled_events(current_user = current_user)
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
          hash[key][:minute_of_day] = occurrence.min + (60 * occurrence.hour)
        end
      end
      hash.each_value.sort { |a,b| 
        first = a[:occurrence] <=> b[:occurrence]; 
        first != 0 ? first : a[:pool_id] <=> b[:pool_id] }
    end
  
    def build_call_groups(viewer, user = nil)
      call_groups = {}
      my_calls = {}
      pools = viewer.pools
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
      call_groups = call_groups.select{ |k,v| my_calls[k]} if user && !viewer.admin?     
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
