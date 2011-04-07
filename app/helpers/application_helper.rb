module ApplicationHelper
  def title
    base_title = "15-Minute Calls"
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  def logo
    image_tag("logo.png", :alt => "15-Minute Calls", :class => "round")
  end
end
