class AddPhoneticNameToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :phonetic_name, :string
    execute("update users set phonetic_name=name")
  end

  def self.down
    remove_column :users, :phonetic_name
  end
end
