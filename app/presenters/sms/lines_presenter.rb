module Sms
  class LinesPresenter
    def initialize(modifier)
      @modifier = modifier
    end

    def to_s
      Game.
        wagerable.
        includes(:competitors, lines: { contestant: :competitor }).
        where(starts_at: Time.current..Time.current + Wager::WINDOW).
        order(starts_at: :asc).
        map(&method(:present)).
        join("\n")
    end

    private

    attr_reader :modifier

    def present(game)
      str = ""

      lines = game.lines.select(&method(:scope))

      lines.select(&:point_spread?).sort_by { |l| l.contestant.priority }.each_cons(2) do |line1, line2|
        str +=
          "#{game.starts_at.strftime("%l:%M%P")}" \
          " #{line1.contestant.competitor.abbreviation} #{"(#{line1.value})" if line1.value.negative?} vs" \
          " #{line2.contestant.competitor.abbreviation} #{"(#{line2.value})" if line2.value.negative?}" \
          " #{"(#{line1.scope})" unless line1.game?}".squish

      end

      str.concat ", #{lines.select(&:over?).first.value}"
    end

    def scope(line)
      if modifier.match?(/(first half|1st half|1h)/).present?
        line.first_half?
      elsif modifier.match?(/(second half|2nd half|2h|halftime|half time)/).present?
        line.second_half?
      else
        line.game?
      end
    end
  end
end
