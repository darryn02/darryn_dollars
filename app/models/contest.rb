class Contest < ApplicationRecord
  include ResultEnum

  belongs_to :contestant
  has_many :lines
  has_one :latest_line, -> { order(created_at: :desc) }, class_name: "Line"
end
