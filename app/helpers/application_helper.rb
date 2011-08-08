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
        next if event.pool_event
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          calls.push(occurrence.in_time_zone(current_user.time_zone))
        end
      end
      calls = calls.sort{ |a,b| a <=> b }.map { |c| c.strftime("%l:%M%p on %a %b #{c.day.ordinalize}").sub(/AM/,'am').sub(/PM/,'pm').strip }
      calls[0..4]
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
end
