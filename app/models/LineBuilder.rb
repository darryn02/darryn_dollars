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

  def odds(o)
    @odds = o.to_i
    self
  end

  def contestant(c)
    @contestant = c
    self
  end

  def find_or_create!
    Line.find_or_create_by!(
      game: @game,
      kind: @kind,
      scope: @scope,
      value: @value,
      odds: @kind == :moneyline ? @odds : -110,
      contestant: @contestant
    )
  end

  private

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
