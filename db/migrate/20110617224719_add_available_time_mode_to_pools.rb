class AddAvailableTimeModeToPools < ActiveRecord::Migration
  def self.up
    add_column :pools, :available_time_mode, :string
    Pool.all.each do |p|
      p.available_time_mode = '60'
      p.save
    end
  end

  def self.down
    remove_column :pools, :available_time_mode
  end
end
