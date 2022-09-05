class LineChange < StandardError; end
class LineNotFound < StandardError; end

class WagerProcessor
  def create_wager!(account, game_type, requested_line, amount, competitors)
    relation = Line.
      joins(:game, :competitors).
      where(games: { starts_at: Time.current..Time.current + 12.hours})
      where.contains(competitors: competitors.map(&:id))

    if game_type.present?
      relation = relation.send(game_type)
    end

    latest_line = relation.latest
    raise LineNotFound if latest_line.nil?

    if requested_line.present?
      raise LineChange if latest_line.value != requested_line
    end

    Wager.create!(
      account: account,
      line: latest_line,
      placed_at: Time.current,
      amount_wagered: amount
    )
  end
end
