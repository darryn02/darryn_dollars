module WagersHelper
  # "BUF +2.5" for a spread, "BUF/MIA O 47.5" for a total - the same data
  # Line#to_s already reaches for, so this adds no queries.
  def wager_line_label(line)
    team = line.competitor&.abbreviation || line.game.short_matchup
    side = line.point_spread? ? spread_label(line) : total_label(line)

    [team, side].compact.join(" ")
  end

  # Result badges pair a color with a letter, so the outcome never depends on
  # color alone.
  def wager_result_badge(wager)
    kind, letter, label =
      if wager.win?       then ["win",     "W", "Win"]
      elsif wager.loss?   then ["loss",    "L", "Loss"]
      elsif wager.push?   then ["push",    "P", "Push"]
      else                     ["pending", "·", "Pending"]
      end

    tag.span(class: "dd-result dd-result--#{kind}") do
      concat tag.span(letter, class: "dd-result__letter", aria: { hidden: true })
      concat tag.span(label, class: "dd-result__label")
    end
  end

  # The one visible sign a wager got a break: a loss capped below the full
  # stake, or a still-open bet that will be if it loses. Silent on a win or a
  # push, since neither one's amount ever moves.
  def vig_waived_badge(wager)
    return unless wager.vig_waived?

    tag.span("Vig waived", class: "dd-vig-badge")
  end
end
