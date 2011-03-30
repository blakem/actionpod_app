class PagesController < ApplicationController
  before_filter :authenticate_user!

  def home
    @events = current_user.events
  end
end
