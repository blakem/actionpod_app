class AddCountsToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :called_count, :integer, :default => 0
    add_column :users, :answered_count, :integer, :default => 0
    add_column :users, :placed_count, :integer, :default => 0
    add_column :users, :incoming_count, :integer, :default => 0
    execute("update users set called_count=0, answered_count=0, placed_count=0, incoming_count=0")
    Call.all.select { |c| c.Direction == 'outbound-api' }.map(&:To).each do |outbound_phone|
      phone = Phone.find_by_number(outbound_phone)
      next unless phone
      user = phone.user
      next unless user
      user.called_count += 1
      user.save
    end
    Call.all.select { |c| c.Direction == 'inbound' }.map(&:From).each do |inbound_phone|
      phone = Phone.find_by_number(inbound_phone)
      next unless phone
      user = phone.user
      next unless user
      user.incoming_count += 1
      user.save
    end
    Conference.all.each do |conference|
      conference.users.each do |user|
        user.placed_count += 1
        user.save
      end
    end
    execute("update users set answered_count=placed_count")
  end

  def self.down
    remove_column :users, :incoming_count
    remove_column :users, :placed_count
    remove_column :users, :answered_count
    remove_column :users, :called_count
  end
end
