class User < ApplicationRecord
  CHAD = ENV.fetch("CHAD_USER_ID", 8).to_i

  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :trackable, :timeoutable

  has_many :accounts
  has_many :wagers, through: :accounts

  def self.list_all
    all.map { |u| "[#{u.id}] #{u.name}, #{u.mobile}, #{u.email}"}
  end

  def chump?
    !admin? && id != CHAD
  end

  def non_chump?
    !chump?
  end
end
