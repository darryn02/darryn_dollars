class WagerProcessor
  class LineChange < StandardError; end
  class LineNotFound < StandardError; end
  class LineExpired < StandardError; end
  class InsufficientCredit < StandardError; end

  def create_wager(account, kind, scope, requested_line, amount, competitors)
    relation = Line.
      joins(:game).
      includes(:contestant).
      references(:contestant).
      where(active_game).
      send(kind).
      send(scope)
    if kind == :over || kind == :under
      relation = relation.where("cached_competitor_ids @> ARRAY[?]", competitors.map(&:id))
    elsif competitors.one?
      relation = relation.where(contestants: { competitor_id: competitors.first.id })
    else
      raise LineNotFound
    end

    latest_line = relation.latest
    raise LineNotFound if latest_line.nil?
    raise LineExpired if latest_line.hidden?
    raise LineExpired if (latest_line.game? || latest_line.first_half?) && latest_line.game.starts_at.past?
    raise LineChange if requested_line.present? && requested_line != latest_line.value
    raise InsufficientCredit if insufficient_credit?(account, amount, latest_line)

    Wager.create(
      account: account,
      line: latest_line,
      placed_at: Time.current,
      amount: gross_up(amount, latest_line)
    )
  end

  def gross_up(amount, line)
    if %w[point_spread over under].exclude?(line.kind)
      amount
    elsif line.odds == -110
      1.1 * amount
    end
  end

  private

  def active_game
    {
      games: { starts_at: (Time.current - 3.hours)..(Time.current + Wager::WINDOW) }
    }
  end

  def insufficient_credit?(account, amount, line)
    account.credit_limit + account.balance - account.liabilities < gross_up(amount, line)
  end
end
