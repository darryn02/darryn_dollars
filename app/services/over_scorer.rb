class OverScorer < Scorer
  def run
    contestants = line.game.contestants
    total = contestants.sum(&method(:contestant_score))

    { wins: 0, losses: 0, pushes: 0 }.tap do |results|
      if total.blank?
        line.pending!
      elsif total > line.value
        line.win!
        results[:wins] += 1
      elsif total < line.value
        line.loss!
        results[:losses] += 1
      else
        line.push!
        results[:pushes] += 1
      end
    end
  end

  def contestant_score(contestant)
    if line.game?
      contestant.scores.sum
    elsif line.first_half?
      contestant.scores[0..1].sum
    elsif line.second_half?
      contestant.scores[2..].sum
    else
      raise 'invalid line scope'
    end
  end
end
