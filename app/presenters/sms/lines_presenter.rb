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
        where(starts_at: Time.current..Time.current + Wager::WINDOW).
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
      if modifier.match?(/(first half|1st half|1h)/).present?
        :first_half
      elsif modifier.match?(/(second half|2nd half|2h|halftime|half time)/).present?
        :second_half
      else
        :game
      end
    end
  end
end
