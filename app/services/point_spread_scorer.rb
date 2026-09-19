class PointSpreadScorer < Scorer
  def run
    contestants = line.game.contestants
    me, them = contestants.partition { |c| c&.id == line.contestant_id }.map(&:first)
    if me.blank? || them.blank?
      Rails.logger.error("Line #{line.id} with contestant_id #{line.contestant_id} did not match a game contestant (#{contestants.map { |c| c&.id }})")
      return
    end

    their_score = contestant_score(them)
    my_score = contestant_score(me)

    { wins: 0, losses: 0, pushes: 0 }.tap do |results|
      if my_score.blank? || their_score.blank?
        line.pending!
      elsif my_score + line.value > their_score
        line.win!
        results[:wins] += 1
      elsif my_score + line.value < their_score
        line.loss!
        results[:losses] += 1
      else
        line.push!
        results[:pushes] += 1
      end
    end
  end
end
