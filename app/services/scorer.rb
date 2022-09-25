class Scorer 
  def self.run(line)
    new(line).run
  end

  def initialize(line)
    @line = line
  end

  private

  attr_reader :line
end
