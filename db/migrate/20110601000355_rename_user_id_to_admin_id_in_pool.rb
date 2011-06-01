class RenameUserIdToAdminIdInPool < ActiveRecord::Migration
  def self.up
    rename_column('pools', 'user_id', 'admin_id')
  end

  def self.down
    rename_column('pools', 'admin_id', 'user_id')
  end
end
