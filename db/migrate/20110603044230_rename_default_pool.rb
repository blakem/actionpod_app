class RenameDefaultPool < ActiveRecord::Migration
  def self.up
    pool = Pool.where(:name => 'Default Pool').sort{ |a,b| a.id <=> b.id }.first
    pool.name = "Default Group"
    pool.save
  end

  def self.down
    pool = Pool.where(:name => 'Default Group').sort{ |a,b| a.id <=> b.id }.first
    pool.name = "Default Pool"
    pool.save
  end
end
