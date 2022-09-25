class Line < ApplicationRecord
  belongs_to :contestant, optional: true
  has_one :competitor, through: :contestant
  belongs_to :game
  has_many :wagers

  enum kind: { point_spread: 0, moneyline: 1, over: 2, under: 3, prop: 9 }
  enum scope: { game: 0, first_half: 1, second_half: 2 }
  enum result: { pending: 0, win: 1, loss: 2, push: 3 }

  def self.latest
    order(created_at: :desc).take
  end

  def self.active
    where.not(hidden: true)
  end

  def self.parse_scope(modifier)
    if modifier.match?(/(first_half|first half|1st half|1h)/).present?
      :first_half
    elsif modifier.match?(/(second_half|second half|2nd half|2h|halftime|half time)/).present?
      :second_half
    else
      :game
    end
  end

  def create_line_change!(properties = {})

  end

  def payout(amount)
    if odds >= 0
      amount * odds * 0.01
    else
      amount / -0.01 / odds
    end
  end

  def to_s
    "#{competitor.present? ? competitor.abbreviation : game.short_matchup}" \
    " #{kind if %w[over under].include?(kind)}" \
    " #{value_string}" \
    " #{"(#{odds}, #{scope})"}".squish
  end

  private

  def value_string
    if value < 0
      value.to_s
    elsif value > 0
      "+#{value}"
    else
      "PICK"
    end
  end
end
