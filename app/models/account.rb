class Account < ApplicationRecord
  belongs_to :user
  has_many :betting_slips
end
