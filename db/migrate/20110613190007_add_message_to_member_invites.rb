class AddMessageToMemberInvites < ActiveRecord::Migration
  def self.up
    add_column :member_invites, :message, :text
  end

  def self.down
    remove_column :member_invites, :message
  end
end
