class AddSendSmsReminderToEvent < ActiveRecord::Migration
  def self.up
    add_column :events, :send_sms_reminder, :boolean, :default => true
    Event.all.each do |event|
      event.send_sms_reminder = true
      event.save
    end
  end

  def self.down
    remove_column :events, :send_sms_reminder
  end
end
