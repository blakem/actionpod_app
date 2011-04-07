class AddPoolIdToDelayedJobs < ActiveRecord::Migration
  def self.up
    add_column :delayed_jobs, :pool_id, :integer
  end

  def self.down
    remove_column :delayed_jobs, :pool_id
  end
end
