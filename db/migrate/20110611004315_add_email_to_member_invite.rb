class AddEmailToMemberInvite < ActiveRecord::Migration
  def self.up
    add_column :member_invites, :email, :string
  end

  def self.down
    remove_column :member_invites, :email
  end
end
