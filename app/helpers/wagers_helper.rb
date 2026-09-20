module WagersHelper
  # One pane of the history page: a tab label and the partial behind it.
  HistoryPane = Struct.new(:id, :label, :partial, :locals, keyword_init: true)

  # The book's combined ledger first, when there is one, then an account per
  # pane. The ledger pane appears only because HouseLedger.for already
  # returned something, which it does for nobody but an admin - this reads
  # the decision rather than making it a second time.
  def history_panes(house_ledger, wagers_by_account, user)
    panes = []

    if house_ledger.present?
      panes << HistoryPane.new(id: "house", label: "The Book", partial: "house_ledger",
                               locals: { ledger: house_ledger })
    end

    wagers_by_account.each do |account, wagers|
      panes << HistoryPane.new(
        id: "account-#{account.id}",
        label: user.admin? ? account.qualified_name : account.to_s,
        partial: "account_history",
        locals: { account: account, wagers: wagers }
      )
    end

    panes
  end

  # Up, down, or neither. A push nets exactly zero, and colouring that green
  # reads as a win the book did not have.
  def money_direction_class(amount)
    return "is-up" if amount.positive?
    return "is-down" if amount.negative?

    nil
  end

  # "BUF +2.5" for a spread, "BUF/MIA O 47.5" for a total, "BUF ML" for a
  # moneyline - the same data Line#to_s already reaches for, so this adds no
  # queries. side_label owns the per-kind naming; see LinesHelper.
  def wager_line_label(line)
    team = line.competitor&.abbreviation || line.game.short_matchup

    [team, side_label(line)].compact.join(" ")
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
