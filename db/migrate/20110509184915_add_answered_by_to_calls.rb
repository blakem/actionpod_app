class AddAnsweredByToCalls < ActiveRecord::Migration
  def self.up
    add_column :calls, :AnsweredBy, :string
  end

  def self.down
    remove_column :calls, :AnsweredBy
  end
end
