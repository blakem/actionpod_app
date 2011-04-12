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
  end
  
  def callcal
    @scheduled_events = build_scheduled_events
  end
  
  private
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
