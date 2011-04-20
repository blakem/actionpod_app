class CreatePlans < ActiveRecord::Migration
  def self.up
    create_table :plans do |t|
      t.text :body
      t.belongs_to :user, :null => false
      
      t.timestamps
    end
  end

  def self.down
    drop_table :plans
  end
end
