class UnderScorer < Scorer
  def run
    contestants = line.game.contestants    
    total = contestants.sum(&method(:contestant_score)    

    if total.blank?
      line.pending!
    elsif total < value
      line.win!
    elsif total > value
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
