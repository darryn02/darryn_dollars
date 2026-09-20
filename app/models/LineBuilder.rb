class LineBuilder
  def game(g)
    @game = g
    self
  end

  def kind(k)
    @kind = parse_kind(k)
    self
  end

  def scope(s)
    @scope = parse_scope(s)
    self
  end

  def value(v)
    @value = v.to_f
    self
  end

  # Stored raw and parsed at build time, because the parse depends on @kind
  # and nothing guarantees the caller set the kind first.
  def odds(o)
    @odds = o
    self
  end

  # The price the book published, before normalization. Audit only; nil on
  # every kind but moneyline.
  def raw_odds(o)
    @raw_odds = o
    self
  end

  def contestant(c)
    @contestant = c
    self
  end

  def find_or_create!
    line = Line.find_or_create_by!(
      game: @game,
      kind: @kind,
      scope: @scope,
      value: @value,
      odds: @kind == :moneyline ? moneyline_odds : -110,
      contestant: @contestant
    )

    # After the find, not inside a create block. The block runs on create
    # only, so every row that survives a scrape - which is all of the
    # currently active ones - would stay NULL forever and the column would
    # answer nothing. raw_odds is not part of the lookup key, so this is
    # the only place a surviving row learns the price this scrape saw.
    line.update_column(:raw_odds, @raw_odds) if line.raw_odds != @raw_odds

    line
  end

  private

  # Defence in depth. BovadaApiClient validates and normalizes the pair at
  # the trust boundary before anything reaches here, so this should never
  # fire - it exists so a future caller going round that boundary cannot
  # put a meaningless price on a moneyline.
  #
  # Guarded on the kind, exactly as the odds column itself already is. An
  # unguarded parse would let a malformed spread or total payload break
  # ingestion for two kinds that hardcode -110 and never read this at all.
  #
  # The old `o.to_i` is what made this necessary: Bovada writes exactly
  # +100 as "EVEN", and "EVEN".to_i is 0, which sends Line#payout down its
  # odds >= 0 branch and returns $0 profit on a winning bet.
  def moneyline_odds
    odds = Integer(@odds, exception: false)
    return odds if odds && odds.abs >= 100

    raise ArgumentError, "#{@odds.inspect} is not a valid moneyline price"
  end

  def parse_kind(k)
    k = k.downcase
    if k == "o"
      :over
    elsif k == "u"
      :under
    else
      k.parameterize.underscore.to_sym
    end
  end

  def parse_scope(str)
    s = str.downcase.strip
    if s == "g"
      :game
    elsif s == "1h"
      :first_half
    elsif s == "2h"
      :second_half
    else
      raise "Invalid game scope - #{s}"
    end
  end
end
