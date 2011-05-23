class CreateMemberMails < ActiveRecord::Migration
  def self.up
    create_table :member_mails do |t|
      t.integer :user_id
      t.datetime :sent_at
      t.string :email_type

      t.timestamps
    end
  end

  def self.down
    drop_table :member_mails
  end
end
