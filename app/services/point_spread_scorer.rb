class PointSpreadScorer < Scorer
  def run
    contestants = line.game.contestants
    me, them = contestants.partition { |c| c.id == line.contestant_id }.map(&:first)

    their_score = contestant_score(them)
    my_score = contestant_score(me)

    if my_score.blank? || their_score.blank?
      line.pending!
    elsif my_score + line.value > their_score
      line.win!
    elsif my_score + line.value < their_score
      line.loss!
    else
      line.push!
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
