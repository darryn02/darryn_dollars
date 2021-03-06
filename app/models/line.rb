class Line < ApplicationRecord
  default_scope { where(hidden: false) }
  scope :point_spreads, -> { where(type: 'PointSpread') }
  scope :over_unders, -> { where(type: 'OverUnder') }
  scope :money_lines, -> { where(type: 'MoneyLine') }
  scope :run_lines, -> { where(type: 'RunLine') }
  scope :puck_lines, -> { where(type: 'PuckLine') }

  belongs_to :contest

  def self.latest
    order(created_at: :desc).take
  end

  def payout(amount)
    if odds >= 0
      amount * odds * 0.01
    else
      amount * 0.01 / odds
    end
  end
end

class PointSpread < Line; end
class OverUnder < Line; end
class MoneyLine < Line; end
class RunLine < Line; end
class PuckLine < Line; end
