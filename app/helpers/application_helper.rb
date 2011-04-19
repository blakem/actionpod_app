module ApplicationHelper
  def title
    base_title = "15-Minute Calls"
    base_title = "(dev) " + base_title if Rails.env.development?
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  def logo
    image_tag("logo.png", :alt => "15-Minute Calls", :class => "round")
  end
    
  def pretty_object_error_messages(object)
    return "" if object.errors.empty?
    html = %(<div class="flash alert round">)
    html += "<b>Ooops. The following errors need to be fixed:</b><br/>"
    errors = []
    object.errors.each do |key, value|
      errors.push(object.class.human_attribute_name(key) + " " + value)
    end
    html += errors.uniq.map{ |error| '- ' + error + "<br/>\n" }.join('')
    html += %(</div>)
    html.html_safe
  end
end
