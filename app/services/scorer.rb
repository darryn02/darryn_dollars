class Scorer 
  def self.run(line)
    new(line).run
  end

  def initialize(line)
    @line = line
  end

  private

  attr_reader :line

  # The periods this line settles from, totalled - or nil when they are not
  # all in yet.
  #
  # nil rather than zero, deliberately. Every scorer leaves a line pending on
  # a blank score, and 0.blank? is false, so a summed empty slice sailed
  # straight past that guard. Once partial scores are written that stops
  # being theoretical: at half time a second half line slices to [], and a
  # zero would have graded it as a 0-0 loss while the third quarter was still
  # being played.
  def contestant_score(contestant)
    played = contestant.scores[line.periods]

    played.presence&.sum
  end

  # Both sides added up, or nil if either side is not in yet. Summing a nil
  # would raise, and treating it as zero would grade a total on half a game.
  def combined_score(contestants)
    scores = contestants.map(&method(:contestant_score))

    scores.sum unless scores.any?(&:nil?)
  end
end
