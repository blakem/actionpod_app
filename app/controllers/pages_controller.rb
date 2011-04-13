class PagesController < ApplicationController
  before_filter :authenticate_user!, :except => :home
  
  def home
    if user_signed_in?
      self.profile
      render :action => 'profile'
    end
  end
  
  def profile
    @user = current_user
    @title = @user.name
    @events = current_user.events.sort { |a,b| a.minute_of_day <=> b.minute_of_day }
    @timeslots = build_timeslots
    @nextcalls = build_nextcalls
  end
  
  def join
    event = Event.create(:user_id => current_user.id, :pool_id => Pool.default_pool.id, :time => params[:time])
    run_at_date = event.schedule.next_occurrence.strftime("%A at %l:%M%p").sub(/AM/,'am').sub(/PM/,'pm')
    redirect_to(root_path, :notice => "Great! We'll call you on #{run_at_date}. ;-)")
  end
  
  def callcal
    @scheduled_events = build_scheduled_events
  end
  
  private
    def build_nextcalls
      calls = []
      start_time = Time.now
      end_time = start_time + 7.days
      current_user.events.each do |event|
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          calls.push(occurrence.in_time_zone(current_user.time_zone))
        end
      end
      calls = calls.sort{ |a,b| a <=> b }.map { |c| c.strftime("%l:%M%p on %A").sub(/AM/,'am').sub(/PM/,'pm') }
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
end
