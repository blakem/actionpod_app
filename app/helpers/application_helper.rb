module ApplicationHelper
  def title
    base_title = "ActionPods"
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  def logo
    image_tag("logo.png", :alt => "ActionPods", :class => "round")
  end
  
  def admin_signed_in?
    user_signed_in? && current_user.admin?
  end
end
