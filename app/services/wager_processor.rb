class WagerProcessor
  class LineChange < StandardError; end
  class LineNotFound < StandardError; end

  def create_wager(account, kind, scope, requested_line, amount, competitors)
    relation = Line.
      joins(:game).
      includes(:contestant).
      references(:contestant).
      where(games: { starts_at: Time.current..Time.current + Wager::WINDOW}).
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

    if requested_line.present?
      raise LineChange if latest_line.value != requested_line
    end

    Wager.create(
      account: account,
      line: latest_line,
      placed_at: Time.current,
      amount: gross_up(amount, latest_line)
    )
  end

  private

  def gross_up(amount, line)
    if %w[point_spread over under].exclude?(line.kind)
      amount
    elsif line.odds == -110
      1.1 * amount
    end
  end
end
