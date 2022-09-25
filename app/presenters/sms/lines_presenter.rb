module Sms
  class LinesPresenter
    def initialize(modifier)
      @modifier = modifier
    end

    def to_s
      LineScraper.ensure_second_half_lines_are_recent! if scope == :second_half

      Game.
        wagerable.
        includes(:competitors, lines: { contestant: :competitor }).
        order(starts_at: :asc).
        map(&method(:format)).
        join("\n")
    end

    private

    attr_reader :modifier

    def format(game)
      str = ""

      lines = game.lines.active.send(scope)

      lines.point_spread.order(created_at: :desc).take(2).sort_by { |l| l.contestant.priority }.each_cons(2) do |line1, line2|
        str +=
          "#{game.starts_at.strftime("%l:%M%P")}" \
          " #{line1.contestant.competitor.abbreviation} #{"(#{line1.value})" if line1.value.negative?} vs" \
          " #{line2.contestant.competitor.abbreviation} #{"(#{line2.value})" if line2.value.negative?}" \
          " #{"(#{line1.scope})" unless line1.game?}".squish

      end

      over_under = lines.over.latest&.value
      str.concat ", #{over_under}" if over_under.present?
      str
    end

    def scope
      @scope ||= Line.parse_scope(modifier)
    end
  end
end
