class AddMultiPhonesToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :multi_phones, :boolean
    User.all.each do |user|
      user.multi_phones = false
    end
  end

  def self.down
    remove_column :users, :multi_phones
  end
end
