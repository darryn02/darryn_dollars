class User < ApplicationRecord
  has_many :accounts

  def self.list_all
    all.map { |u| "[#{u.id}] #{u.name}, #{u.mobile}, #{u.email}"}
  end
end
