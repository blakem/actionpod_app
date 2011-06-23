class AddSendConferenceEmailToPools < ActiveRecord::Migration
  def self.up
    add_column :pools, :send_conference_email, :boolean
    Pool.all.each do |pool|
      pool.send_conference_email = true
      pool.save
    end
  end

  def self.down
    remove_column :pools, :send_conference_email
  end
end
