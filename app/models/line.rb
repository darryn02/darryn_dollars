class Line < ApplicationRecord
  belongs_to :contestant, optional: true
  belongs_to :game

  enum kind: { point_spread: 0, moneyline: 1, over: 2, under: 3, prop: 9 }
  enum scope: { game: 0, first_half: 1, second_half: 2 }

  def self.latest
    order(created_at: :desc).take
  end

  def create_line_change!(properties = {})

  end

  def payout(amount)
    if odds >= 0
      amount * odds * 0.01
    else
      amount * 0.01 / odds
    end
  end
end
