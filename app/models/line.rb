class Line < ApplicationRecord
  belongs_to :contestant, optional: true
  has_one :competitor, through: :contestant
  belongs_to :game
  has_many :wagers
  has_many :chump_wagers, -> { where.not(account_id: Account::CHAD) }, class_name: "Wager", foreign_key: "line_id"

  enum kind: { point_spread: 0, moneyline: 1, over: 2, under: 3, prop: 9 }
  enum scope: { game: 0, first_half: 1, second_half: 2 }
  enum result: { pending: 0, win: 1, loss: 2, push: 3 }

  # Which linescore periods each scope settles from.
  #
  # The open-ended ranges are the point. A scope that runs to the final
  # whistle cannot settle early, because overtime keeps adding to it; a
  # bounded one settles the moment its own periods are in, which is what lets
  # a first half pay out at the half rather than three hours later.
  #
  # A new scope - college quarters, hockey periods - is a row here and
  # nothing else. The scorers and the fetch cadence both read this rather
  # than knowing the names of scopes themselves.
  PERIODS = {
    "game" => (0..),
    "first_half" => (0..1),
    "second_half" => (2..)
  }.freeze

  # "Total" is not a kind of its own - a total is one over line and one
  # under line, priced together. Anywhere a person picks a market type
  # rather than a database column, these are the choices.
  KIND_GROUPS = {
    "spread" => %w[point_spread],
    "total" => %w[over under],
    "moneyline" => %w[moneyline],
    "all" => %w[point_spread moneyline over under]
  }.freeze

  def periods = PERIODS.fetch(scope) { raise "invalid line scope #{scope.inspect}" }

  # Whether the result this line is waiting on can still change. Bounded
  # scopes need their own periods final and nothing more; open-ended ones
  # need the game itself to be over.
  def settleable?
    return game.completed_at.present? if periods.end.nil?

    game.contestants.all? { |contestant| contestant.scores.length > periods.end }
  end

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

  # A moneyline has no handicap, so it contributes no value segment at all -
  # "BUF ML (-285 1H)". The value column still holds 0.0 because it is NOT
  # NULL, and without this branch the spread arm below read that zero and
  # printed a -285 favorite as "BUF PICK (-285 1H)".
  def value_string(kind)
    if kind == "moneyline"
      nil
    elsif %w[over under].include?(kind)
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
    elsif kind == "moneyline"
      "ML"
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
