class Contestant < ApplicationRecord
  belongs_to :game
  belongs_to :competitor
  has_many :contests

  delegate :name, to: :competitor
end
