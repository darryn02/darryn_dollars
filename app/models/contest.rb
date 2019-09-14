class Contest < ApplicationRecord
  belongs_to :game
  has_many :contestants
  has_many :competitors, through: :contestants

  def self.primary
    find_by(primary: true)
  end
end
