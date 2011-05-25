class ApplicationController < ActionController::Base
  protect_from_forgery
  
  include ApplicationHelper

  before_filter :ensure_domain
  before_filter :set_timezone
  before_filter :add_initial_breadcrumbs

  def admin_signed_in?
    user_signed_in? && current_user.admin?
  end

  def sublayout 
    @view_options ? 'sidebar' : 'main'
  end

  private
    def add_initial_breadcrumbs
      breadcrumbs.add 'Home', root_path
    end

    def ensure_domain
      return unless Rails.env.production?
      if (request.env['HTTP_HOST'] != 'www.15minutecalls.com' && request.env['HTTP_HOST'] != 'actionpods-staging.heroku.com')
        redirect_to "http://www.15minutecalls.com", :status => 301
      end
    end
  
    def set_timezone
      Time.zone = current_user.time_zone if current_user
    end
end
