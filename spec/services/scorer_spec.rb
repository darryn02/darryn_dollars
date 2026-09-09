require "rails_helper"

RSpec.describe Scorer, type: :service do
  it "builds an instance around the line and delegates to #run" do
    subclass = Class.new(Scorer) do
      def run
        line
      end
    end

    line = instance_double(Line)

    expect(subclass.run(line)).to eq(line)
  end
end
