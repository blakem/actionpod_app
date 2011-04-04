class AddObjectFieldsToDelayedJob < ActiveRecord::Migration
  def self.up
    add_column :delayed_jobs, :obj_type, :string
    add_column :delayed_jobs, :obj_id, :integer
    add_column :delayed_jobs, :obj_jobtype, :string
  end

  def self.down
    remove_column :delayed_jobs, :obj_jobtype
    remove_column :delayed_jobs, :obj_id
    remove_column :delayed_jobs, :obj_type
  end
end
