class CreatePhones < ActiveRecord::Migration
  def self.up
    create_table :phones do |t|
      t.integer :user_id
      t.string :phone_number
      t.string :phone_number_string

      t.timestamps
    end
    add_column :users, :primary_phone_id, :integer
    User.all.each do |u|
      phone = Phone.create(
        :user_id => u.id,
        :phone_number => u.primary_phone,
        :phone_number_string => u.primary_phone_string,
      )
      u.primary_phone_id = phone.id
      u.save
    end
    remove_column :users, :primary_phone
    remove_column :users, :primary_phone_string
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration, "Not even going to try to write the reverse migration"
  end
end
