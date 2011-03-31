# == Schema Information
# Schema version: 20110331195131
#
# Table name: delayed_jobs
#
#  id         :integer         not null, primary key
#  priority   :integer         default(0)
#  attempts   :integer         default(0)
#  handler    :text
#  last_error :text
#  run_at     :datetime
#  locked_at  :datetime
#  failed_at  :datetime
#  locked_by  :text
#  created_at :datetime
#  updated_at :datetime
#

class DelayedJob < ActiveRecord::Base
end
