module LinesHelper
  # "+2.5" / "-3.0" / "PICK"
  def spread_label(line)
    return nil if line.nil?
    return "PICK" if line.value.zero?

    line.value.positive? ? "+#{line.value}" : line.value.to_s
  end

  # "O 47.5" / "U 47.5"
  def total_label(line)
    return nil if line.nil?

    "#{line.over? ? 'O' : 'U'} #{line.value}"
  end

  # The headline for a bet, e.g. "BUF +2.5" or "O 47.5". Built here rather than
  # from Line#to_s so the offcanvas title is free of the model's formatting.
  def line_headline(line)
    side = line.point_spread? ? spread_label(line) : total_label(line)

    [line.competitor&.abbreviation, side].compact.join(" ")
  end

  # "-110" or "-110 · 1st Half"
  def line_terms(line)
    [line.odds, line_scope_label(line)].compact.join(" · ")
  end

  def line_scope_label(line)
    case line.scope
    when "first_half"  then "1st Half"
    when "second_half" then "2nd Half"
    end
  end

  def quick_wager_amounts
    minimum = Wager.min_wager

    [minimum, minimum * 2, minimum * 5, minimum * 10]
  end
end
