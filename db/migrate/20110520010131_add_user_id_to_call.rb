class AddUserIdToCall < ActiveRecord::Migration
  def self.up
    add_column :calls, :user_id, :integer
    Call.all.each do |call|
      event = Event.find_by_id(call.event_id)
      call.user_id = event.user_id if event
      call.save
    end
  end

  def self.down
    remove_column :calls, :user_id
  end
end
