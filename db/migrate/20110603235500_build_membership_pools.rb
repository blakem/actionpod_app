class BuildMembershipPools < ActiveRecord::Migration
  def self.up
    pool = Pool.default_pool
    pool.users = User.all
    pool.save
    User.where(:admin => true).each do |user|
      user.pools = Pool.all
    end
  end

  def self.down
    Pool.all.each do |pool|
      pool.users = []
      pool.save
    end
  end
end
