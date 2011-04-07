Dir.entries("#{Rails.root}/lib").each do |entry|
  require entry if entry =~ /.rb$/
end

require 'twiliolib-2.0.7/lib/twiliolib'
