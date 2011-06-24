class AddMergeTypeToPools < ActiveRecord::Migration
  def self.up
    add_column :pools, :merge_type, :integer
    Pool.all.each do |pool|
      pool.merge_type = 1
      pool.save
    end
  end

  def self.down
    remove_column :pools, :merge_type
  end
end
