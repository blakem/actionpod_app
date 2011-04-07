class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :ensure_domain
  before_filter :set_timezone

  def ensure_domain
    if request.env['HTTP_HOST'] != 'www.15minutecalls.com'
      redirect_to "http://www.15minutecalls.com", :status => 301
    end
  end
  
  def set_timezone
    Time.zone = current_user.time_zone if current_user
  end
  
  def admin_signed_in?
    user_signed_in? && current_user.admin?
  end
end
