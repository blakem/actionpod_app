class AddAllowOthersToInviteToPools < ActiveRecord::Migration
  def self.up
    add_column :pools, :allow_others_to_invite, :boolean
    Pool.all.each do |p|
      p.allow_others_to_invite = true
      p.public_group = true
      p.save
    end
  end

  def self.down
    remove_column :pools, :allow_others_to_invite
  end
end
