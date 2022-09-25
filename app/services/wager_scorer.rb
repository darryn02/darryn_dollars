class WagerScorer
  def self.run(scope = Wager.all.confirmed)
    new(scope).run
  end

  def run(scope = Wager.all.confirmed)
    scope.
      includes(:line).
      find_each do |wager|
      if wager.line.win?
        wager.win! 
      elsif wager.line.loss?
        wager.loss! 
      elsif wager.line.push?
        wager.push! 
      end
    end
  end
end
