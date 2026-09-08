# Presents one game's lines as two team rows for the lines board.
#
# The board used to build its rows with `each_cons(2)` over the sorted spread
# lines, which meant a game with fewer than two active spread lines rendered
# nothing at all - including its over/under. Here a side with no line simply
# has no line, and the game still shows up.
class GameLinesViewModel
  Row = Struct.new(:competitor, :spread, :total, :spread_flagged, :total_flagged,
                   keyword_init: true) do
    def abbreviation
      competitor&.abbreviation
    end

    def name
      competitor&.name
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
      build_row(spread_lines.first, over_line, under_line, competitors.first),
      build_row(spread_lines.second, under_line, over_line, competitors.second)
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

    rows.flat_map { |row| [row.spread, row.total] }.compact.uniq
  end

  private

  def build_row(spread, total, opposing_total, fallback_competitor)
    Row.new(
      competitor: spread&.competitor || fallback_competitor,
      spread: spread,
      total: total,
      spread_flagged: flagged?(spread, opposing_spread_for(spread)),
      total_flagged: flagged?(total, opposing_total)
    )
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

  def chump_total(line)
    line.chump_wagers.sum(&:amount)
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

  def over_line
    @over_line ||= lines.find(&:over?)
  end

  def under_line
    @under_line ||= lines.find(&:under?)
  end

  # Only consulted when a side has no spread line of its own, so the row can
  # still name the team instead of the whole game disappearing.
  def competitors
    @competitors ||= game.contestants.sort_by(&:priority).map(&:competitor)
  end
end
