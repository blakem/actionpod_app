# == Schema Information
# Schema version: 20110407224434
#
# Table name: delayed_jobs
#
#  id          :integer         not null, primary key
#  priority    :integer         default(0)
#  attempts    :integer         default(0)
#  handler     :text
#  last_error  :text
#  run_at      :datetime
#  locked_at   :datetime
#  failed_at   :datetime
#  locked_by   :text
#  created_at  :datetime
#  updated_at  :datetime
#  obj_type    :string(255)
#  obj_id      :integer
#  obj_jobtype :string(255)
#  pool_id     :integer
#

class DelayedJob < ActiveRecord::Base
end
