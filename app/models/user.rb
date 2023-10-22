class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :trackable, :timeoutable

  has_many :accounts
  has_many :wagers, through: :accounts

  def self.list_all
    all.map { |u| "[#{u.id}] #{u.name}, #{u.mobile}, #{u.email}"}
  end
end
