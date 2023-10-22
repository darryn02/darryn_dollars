class WagerScorer
  def self.run(scope = Wager.all.confirmed)
    new.run(scope)
  end

  def run(scope = Wager.all.confirmed)
    wins, losses, pushes = 0, 0, 0

    scope.
      includes(:line).
      find_each do |wager|
        if wager.line.win?
          wager.win!
          wins += 1
        elsif wager.line.loss?
          wager.loss!
          losses += 1
        elsif wager.line.push?
          wager.push!
          pushes += 1
        end
    end
    "Wagers scored: #{wins} wins, #{losses} losses, #{pushes} pushes."
  end
end
