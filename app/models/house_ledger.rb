# The book's own view of the action: every wager that moves the house's
# bottom line, across every account, most recently decided first.
#
# Reached through .for rather than .new on purpose. The check that this is
# the book looking is the constructor, so a template that forgets to ask has
# nothing to render rather than a collection of everybody's money. Hiding a
# section in a view hides the section; not building the object is what makes
# the leak impossible.
class HouseLedger
  SETTLED = %w[win loss push].freeze

  def self.for(user)
    new if user&.admin?
  end

  # Open action first. It has not settled, so it has no settlement time to
  # sort by, and it is the part the book cannot bank yet - burying it below
  # three months of decided wagers would be the wrong way round.
  def rows = open_wagers + settled_wagers

  # updated_at, because there is no settled_at column and scoring is what
  # last touches one of these rows - WagerScorer writes the status and the
  # net together. It is a proxy, not a record of the event: waiving the vig
  # on an already-decided wager moves it back to the top without anything
  # having been re-decided. Rare enough to accept, and the alternative is a
  # column that only exists to be sorted on.
  def settled_wagers
    @settled_wagers ||= scope.where(status: SETTLED).order(updated_at: :desc).to_a
  end

  def open_wagers
    @open_wagers ||= scope.where(status: :confirmed).order(placed_at: :desc).to_a
  end

  # The book is on the other side of every wager, so its result is the
  # player's inverted: their win is its loss.
  def house_net(wager) = -wager.net.to_d

  def settled_net = settled_wagers.sum { |wager| house_net(wager) }

  # What the book would owe if every open wager came in - the worst case it
  # is currently carrying, not an expectation.
  def exposure = open_wagers.sum(&:potential_profit)

  def any? = rows.any?

  private

  # Every account, deliberately. Account::CHAD is kept out of chump_wagers so
  # insider money does not skew which side the chumps look to be on, but that
  # is a question about signal. This is a question about money, and the book
  # pays Chad the same as anybody else.
  def scope
    Wager.includes(:line, :contestant, account: :user)
  end
end
