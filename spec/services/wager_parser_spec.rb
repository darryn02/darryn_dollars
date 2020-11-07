RSpec.describe WagerParser, type: :service do
  describe ".parse" do
    TEST_CASES = [
      "Kc -7 for 75",
      "Bills-7 first half for 75",
      "Niners second half +3.5 for 500",
      "SF +7 $50",
      "Tampa -10 2half for $55 please",
      "100 under 44.5 bears/rams",
      "100 Seattle 1st half -4\r\n100 Seattle -7"
    ]

    it "successfully parses bets in many different formats" do

      WagerParser.parse()
    end
  end
end
