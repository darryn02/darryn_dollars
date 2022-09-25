class LineScorerFactory
  def self.build(line)
    [line.kind, 'scorer'].join('_').camelize.constantize.new(line)
  end
end
