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
end
