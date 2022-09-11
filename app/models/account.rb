class Account < ApplicationRecord
  belongs_to :user
  has_many :wagers

  def to_s
    name
  end
end
