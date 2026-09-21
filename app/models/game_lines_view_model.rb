# Presents one game's lines as two team rows for the lines board.
#
# The board used to build its rows with `each_cons(2)` over the sorted spread
# lines, which meant a game with fewer than two active spread lines rendered
# nothing at all - including its over/under. Here a side with no line simply
# has no line, and the game still shows up.
class GameLinesViewModel
  Row = Struct.new(:competitor, :spread, :total, :moneyline,
                   :spread_flagged, :total_flagged, :moneyline_flagged,
                   :moneyline_offered, keyword_init: true) do
    def abbreviation
      competitor&.abbreviation
    end

    def name
      competitor&.name
    end

    # The moneyline only if the book is taking bets on it. The slot itself
    # keeps the line either way, because a withheld underdog still prints
    # its price in the closed cell - it is a price you cannot bet, not a
    # market that was never scraped.
    def offered_moneyline
      moneyline if moneyline_offered
    end
  end

  attr_reader :game, :lines, :user

  def initialize(game:, lines:, user:)
    @game = game
    @lines = lines
    @user = user
  end

  def starts_at
    game.starts_at
  end

  def wagerable?
    game.wagerable?
  end

  # Away side first, then home - the order the board has always used.
  def rows
    @rows ||= [
      build_row(spread_lines.first, over_line, under_line,
                moneyline_for(contestants.first), competitors.first),
      build_row(spread_lines.second, under_line, over_line,
                moneyline_for(contestants.second), competitors.second)
    ]
  end

  # "BUF @ MIA". Built from the rows, so it costs no extra query.
  def matchup_label
    rows.map(&:abbreviation).compact.join(" @ ")
  end

  def kickoff_label
    starts_at.strftime("%a %-l:%M %p")
  end

  # Betting opens Wager::WINDOW before kickoff and shuts once the game is
  # underway, so "not wagerable" means two opposite things. Labelling both of
  # them "Closed" reads as "you have missed it" to someone looking at a game
  # that is still two days away.
  def status_label
    return nil if wagerable?
    return "Opens #{betting_opens_at.strftime("%a %-l:%M %p")}" if betting_opens_at.future?

    "Closed"
  end

  def betting_opens_at
    starts_at - Wager::WINDOW
  end

  # Every line on this card that gets a bet button. The offcanvas forms are
  # rendered from here, outside the row grid, so they cannot become stray
  # grid items.
  def bet_lines
    return [] unless wagerable?

    rows.flat_map { |row| [row.spread, row.total, row.offered_moneyline] }.compact.uniq
  end

  private

  def build_row(spread, total, opposing_total, moneyline, fallback_competitor)
    Row.new(
      competitor: spread&.competitor || moneyline&.competitor || fallback_competitor,
      spread: spread,
      total: total,
      moneyline: moneyline,
      spread_flagged: flagged?(spread, opposing_spread_for(spread)),
      total_flagged: flagged?(total, opposing_total),
      moneyline_flagged: flagged?(moneyline, opposing_moneyline_for(moneyline)),
      # Decided here, on the paired line, rather than by filtering
      # moneyline_lines before pairing. rows pairs positionally against
      # competitors.first/.second, so dropping a withheld underdog from the
      # list first would shift its surviving favorite onto the other team's
      # row - the board would show the right price against the wrong team.
      moneyline_offered: Moneyline.offerable?(moneyline)
    )
  end

  # Matched to the row's own side rather than taken positionally out of the
  # list, which is what spread_lines does - and why a game carrying only the
  # home team's spread prints that team's name on both rows today. That is a
  # pre-existing defect and fixing it would change point spread behavior, so
  # it is left alone; it is not copied here either.
  #
  # A moneyline reaches the board one-sided for ordinary reasons - the
  # partner row hidden by a scrape, a contestant nullified - and the right
  # price against the wrong team is the worst thing this column could do.
  def moneyline_for(contestant)
    return nil if contestant.nil?

    moneyline_lines.find { |line| line.contestant_id == contestant.id }
  end

  def opposing_moneyline_for(moneyline)
    return nil if moneyline.nil?

    moneyline_lines.find { |line| line != moneyline }
  end

  def opposing_spread_for(spread)
    return nil if spread.nil?

    spread_lines.find { |line| line != spread }
  end

  # The money bag marks the side the chumps are on, and only non-chumps see it.
  def flagged?(line, opposing_line)
    return false if line.nil? || opposing_line.nil?
    return false unless user.non_chump?

    chump_total(line) > chump_total(opposing_line)
  end

  # What the book would owe this side, not what was staked on it.
  #
  # Summing stake was only ever meaningful because both sides of a spread or
  # a total are priced at -110. On a moneyline they are not: $500 on a -500
  # favorite against $50 on a +400 underdog would flag the favorite every
  # time, whatever the book actually stood to lose.
  #
  # Behavior-preserving for spread and total, which LineBuilder hardcodes at
  # -110 on every single row - weighting by payout scales both sides of an
  # existing comparison by the same 0.909 and can flip no stamp that stands
  # today.
  def chump_total(line)
    line.chump_wagers.sum(&:potential_profit)
  end

  # A spread belongs to a side, and the side is the contestant. `lines` has
  # `on_delete: :nullify` against contestants, so a spread can outlive the
  # contestant that gave it meaning - and one of those is unattributable: we
  # cannot say whose spread it is, let alone which row to hang it on. Drop it
  # and let the side render as having no spread, rather than sorting on nil.
  def spread_lines
    @spread_lines ||= lines.
      select { |line| line.point_spread? && line.contestant.present? }.
      sort_by(&:created_at).
      take(2).
      sort_by { |line| line.contestant.priority }
  end

  # Mirrors spread_lines, and for the same reason: a moneyline belongs to a
  # side, and a contestant-less one cannot be hung on either row.
  def moneyline_lines
    @moneyline_lines ||= lines.
      select { |line| line.moneyline? && line.contestant.present? }.
      sort_by(&:created_at).
      take(2).
      sort_by { |line| line.contestant.priority }
  end

  def over_line
    @over_line ||= lines.find(&:over?)
  end

  def under_line
    @under_line ||= lines.find(&:under?)
  end

  def contestants
    @contestants ||= game.contestants.sort_by(&:priority)
  end

  # Only consulted when a side has no spread line of its own, so the row can
  # still name the team instead of the whole game disappearing.
  def competitors
    @competitors ||= contestants.map(&:competitor)
  end
end
