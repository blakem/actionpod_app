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
end
