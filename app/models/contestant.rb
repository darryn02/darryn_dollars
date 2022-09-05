class Contestant < ApplicationRecord
  belongs_to :game
  belongs_to :competitor, optional: true
  has_many :lines
  has_one :latest_line, -> { order(created_at: :desc) }, class_name: "Line"

  delegate :name, to: :competitor
end
