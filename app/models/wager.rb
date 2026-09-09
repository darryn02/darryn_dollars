class Wager < ApplicationRecord
  DEFAULT_MIN_WAGER = ENV.fetch('MIN_WAGER', 50).to_i
  WINDOW = ENV.fetch("WAGER_WINDOW_HOURS", 24).to_i.hours

  belongs_to :account
  belongs_to :bet_slip
  belongs_to :line
  has_one :contestant, through: :line

  enum status: { pending: 0, confirmed: 1, win: 2, loss: 3, push: 4, canceled: 5 }

  before_validation :set_placed_at
  before_save :update_net

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: DEFAULT_MIN_WAGER }, on: :create
  validates :line, presence: true, on: :create
  validates :account, presence: true, on: :create
  validates :placed_at, presence: true, if: :confirming?
  validate :game_has_not_started
  validate :second_half_has_not_started
  validate :line_must_be_active
  validate :account_has_sufficient_credit

  def self.historical
    where(status: [:win, :loss, :push])
  end

  # The three ways the admin vig-waiver widget can select wagers: one exact
  # line, one kind group across a whole game, or one kind group across every
  # game on a calendar day (the book's own day - America/New_York - same as
  # Game.today). A canceled wager was never going to pay out anything, so it
  # is never a candidate.
  def self.matching_scope(scope_type:, line_id: nil, game_id: nil, kind_group: nil, date: nil)
    kinds = Line::KIND_GROUPS.fetch(kind_group.to_s, [])

    scope =
      case scope_type.to_s
      when "line"
        where(line_id: line_id)
      when "game"
        joins(:line).where(lines: { game_id: game_id, kind: kinds })
      when "day"
        day = date.is_a?(Date) ? date : Date.parse(date.to_s)
        range = day.in_time_zone("America/New_York").all_day
        joins(line: :game).where(games: { starts_at: range }, lines: { kind: kinds })
      else
        none
      end

    scope.where.not(status: :canceled)
  end

  def self.min_wager
    @min_wager || DEFAULT_MIN_WAGER
  end

  def self.min_wager=(value)
    @min_wager = value
  end

  def self.list_all
    order(placed_at: :asc).map(&:to_s)
  end

  def historical?
    win? || loss? || push?
  end

  def to_s
    str =
      "#{ActionController::Base.helpers.number_to_currency(amount)} " \
      "#{line}".
      squish
  end

  def potential_profit
    line.payout(amount)
  end

  # What losing actually costs when the vig is waived: whatever a win would
  # have paid, never more than the stake itself. At standard -110 pricing a
  # win already nets exactly what pick'em odds would - $100 on a $110 bet -
  # so the vig was only ever showing up on the loss side, at the full stake.
  # Capping there, rather than raising the win, is what "waiving the vig"
  # actually is: risk 110, but never lose (or win) more than 100.
  #
  # The min matters on a positive-odds underdog line, where potential_profit
  # is larger than the stake (a $100 bet at +150 nets $150) - without it,
  # waiving the vig there would make a loss cost more than what was risked.
  # It just quietly does nothing on a line with no vig to waive in the
  # first place.
  def loss_amount
    vig_waived? ? [potential_profit, amount].min : amount
  end

  def to_win
  end

  private

  def update_net
    return self.net = potential_profit if win?
    return self.net = -loss_amount if loss?
    self.net = 0
  end

  def set_placed_at
    self.placed_at = Time.now if confirming?
  end

  def game_has_not_started
    return unless confirming?

    if line.active? && (line.game? || line.first_half?) && line.game.starts_at.past?
      errors.add(:line, "has expired, past game start time")
    end
  end

  # A second half line has no scheduled start of its own, so the only thing
  # that retires it is Bovada dropping the market - a signal that reaches us
  # through a CDN caching for ten minutes. Long enough for a player watching
  # the game to get a bet down on a half already underway, so the display is
  # allowed to lag but the confirmation is not: ask ESPN at the moment the
  # money is committed.
  def second_half_has_not_started
    return unless confirming?
    return unless line.second_half? && line.active?

    if line.game.second_half_started?
      errors.add(:line, "is no longer wagerable, the second half has started")
    end
  rescue EspnScoreboard::Unavailable => e
    # Fail closed. A rejected wager is an annoyance; an accepted wager on a
    # half in progress is a player betting with information we do not have.
    Rails.logger.warn("Could not verify second half status for line #{line.id}: #{e.message}")
    Honeybadger.notify(e, context: { line_id: line.id }) if defined?(Honeybadger)
    errors.add(:line, "could not be verified right now, please try again")
  end

  def line_must_be_active
    return unless confirming?

    if line.hidden?
      errors.add(:line, "is no longer active")
    end
  end

  def account_has_sufficient_credit
    return unless confirming?

    if account.credit_limit + account.balance - account.liabilities < amount
      errors.add(:accout, "has insufficient credit")
    end
  end

  def confirming?
    persisted? && changes["status"] == ["pending", "confirmed"]
  end
end
