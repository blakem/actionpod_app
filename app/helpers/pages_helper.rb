module PagesHelper
  def gravatar_for(user, options = {})
    options = { 
      :size => 50, 
      :default => 'monsterid',
    }.merge(options)

    if user.facebook_uid and !user.facebook_uid.blank?
      size = options[:size]
      %(<img alt=").html_safe + user.name + %(" src="http://graph.facebook.com/).html_safe + user.facebook_uid + 
      %(/picture" width=").html_safe + size.to_s + %(" height=").html_safe + size.to_s + %(" class="gravatar">).html_safe
    else
      gravatar_image_tag(user.email.downcase,
        :alt => user.name, 
        :class => 'gravatar', 
        :gravatar => options
      )
    end    
  end  
end
