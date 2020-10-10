class Contest < ApplicationRecord
  include ResultEnum

  belongs_to :contestant
  has_one :line
end
