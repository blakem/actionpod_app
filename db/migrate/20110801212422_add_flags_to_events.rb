class AddFlagsToEvents < ActiveRecord::Migration
  def self.up
    add_column :events, :pool_event, :boolean, :default => false
    add_column :events, :auto_subscribe, :boolean, :default => false
    Event.all.each do |event|
      event.pool_event = false
      event.auto_subscribe = false
      event.save
    end
  end

  def self.down
    remove_column :events, :auto_subscribe
    remove_column :events, :pool_event
  end
end
