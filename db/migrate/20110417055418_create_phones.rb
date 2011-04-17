class CreatePhones < ActiveRecord::Migration
  def self.up
    create_table :phones do |t|
      t.string :number
      t.string :string
      t.boolean :primary, :default => false
      t.belongs_to :user, :null => false
      
      t.timestamps
    end
    User.all.each do |u|
      phone = Phone.create(
        :user_id => u.id,
        :number => u.primary_phone,
        :string => u.primary_phone_string,
        :primary => true,
      )
    end
    remove_column :users, :primary_phone
    remove_column :users, :primary_phone_string
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration, "Not even going to try to write the reverse migration"
  end
end
