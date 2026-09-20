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

  # What a line says about its side, whatever kind it is. The one place that
  # knows how each kind names itself, so nothing else has to branch on kind
  # again - the ternary this replaced fed a moneyline to total_label, which
  # reads line.over? (false) and printed "U 0.0".
  #
  # Moneyline is the one kind with nothing to say but its name. The price is
  # the differentiating value, and line_terms already carries it alongside
  # everywhere this is used, so the sheet, slip and history read "BUF ML".
  # The board cell is the exception and shows the price itself - see
  # GameLinesViewModel - because there the two rows would otherwise both
  # read "ML" under a header that also says ML.
  def side_label(line)
    return nil if line.nil?

    case line.kind
    when "point_spread" then spread_label(line)
    when "moneyline"    then "ML"
    when "over", "under" then total_label(line)
    end
  end

  # The headline for a bet, e.g. "BUF +2.5" or "O 47.5". Built here rather than
  # from Line#to_s so the offcanvas title is free of the model's formatting.
  def line_headline(line)
    [line.competitor&.abbreviation, side_label(line)].compact.join(" ")
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
    [50, 75, 100, 200]
  end
end
