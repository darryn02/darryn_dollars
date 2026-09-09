class Line < ApplicationRecord
  belongs_to :contestant, optional: true
  has_one :competitor, through: :contestant
  belongs_to :game
  has_many :wagers
  has_many :chump_wagers, -> { where.not(account_id: Account::CHAD) }, class_name: "Wager", foreign_key: "line_id"

  enum kind: { point_spread: 0, moneyline: 1, over: 2, under: 3, prop: 9 }
  enum scope: { game: 0, first_half: 1, second_half: 2 }
  enum result: { pending: 0, win: 1, loss: 2, push: 3 }

  # "Total" is not a kind of its own - a total is one over line and one
  # under line, priced together. Anywhere a person picks a market type
  # rather than a database column, these are the choices.
  KIND_GROUPS = {
    "spread" => %w[point_spread],
    "total" => %w[over under],
    "moneyline" => %w[moneyline]
  }.freeze

  def self.latest
    order(updated_at: :desc).take
  end

  def self.active
    where.not(hidden: true)
  end

  def self.nfl
    joins(:game).merge(Game.nfl)
  end

  def self.ncaaf
    joins(:game).merge(Game.ncaaf)
  end

  def active?
    !hidden
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

  # "BUF +2.5 (-110)" for a game line, "BUF +2.5 (-110 1H)" for a half. The
  # terms used to be interpolated as "(#{odds} #{scope_str(scope)})", which
  # left "(-110 )" whenever scope_str returned nil - squish cannot reach a
  # space that sits inside the parentheses.
  def to_s
    [
      competitor.present? ? competitor.abbreviation : game.short_matchup,
      "#{kind_string(kind)}#{value_string(kind)}",
      "(#{[odds, scope_str(scope)].compact.join(" ")})"
    ].join(" ").squish
  end

  private

  def value_string(kind)
    if %w[over under].include?(kind)
      value.to_s
    else
      if value < 0
        value.to_s
      elsif value > 0
        "+#{value}"
      else
        "PICK"
      end
    end
  end

  def kind_string(kind)
    if kind == "over"
      "O"
    elsif kind == "under"
      "U"
    end
  end

  def scope_str(scope)
    if scope == "first_half"
      "1H"
    elsif scope == "second_half"
      "2H"
    end
  end
end
