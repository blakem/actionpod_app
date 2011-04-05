class PagesController < ApplicationController

  def home
    if user_signed_in?
      self.profile
      render :action => 'profile'
    end
  end
  
  def profile
    @events = current_user.events
  end
  
  def callcal
    redirect_to(root_path) unless user_signed_in?
    @scheduled_events = build_scheduled_events
  end
  
  private
    def build_scheduled_events
      hash = {}
      start_time = Time.now.beginning_of_week + 6.days
      end_time = start_time + 7.days
      Event.all.each do |event|
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          hash[occurrence] ||= 0
          hash[occurrence] += 1
        end
      end
      hash.each.sort
    end  
end
