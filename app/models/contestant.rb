class Contestant < ApplicationRecord
  belongs_to :contest
  belongs_to :competetor
  has_many :lines

  delegate :name, to: :competetor
end
