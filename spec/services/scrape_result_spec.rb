require "rails_helper"

RSpec.describe ScrapeResult, type: :service do
  it "renders as the human message" do
    result = described_class.new(outcome: ScrapeRun::SUCCESS, message: "3 lines created")

    expect(result.to_s).to eq("3 lines created")
  end

  it "converts to the attribute shape ScrapeRun expects" do
    result = described_class.new(
      outcome: ScrapeRun::SUCCESS, message: "3 lines created",
      created: 3, activated: 5, deactivated: 1,
      http_status: 200, content_type: "application/json"
    )

    expect(result.to_scrape_run_attributes).to eq(
      outcome: ScrapeRun::SUCCESS,
      detail: "3 lines created",
      lines_created: 3,
      lines_activated: 5,
      lines_deactivated: 1,
      http_status: 200,
      content_type: "application/json"
    )
  end

  it "coerces nil counts to zero" do
    result = described_class.new(outcome: ScrapeRun::NO_DATA, message: "no data")

    attrs = result.to_scrape_run_attributes

    expect(attrs[:lines_created]).to eq(0)
    expect(attrs[:lines_activated]).to eq(0)
    expect(attrs[:lines_deactivated]).to eq(0)
  end

  it "truncates the detail at 500 characters" do
    result = described_class.new(outcome: ScrapeRun::ERROR, message: "x" * 600)

    expect(result.to_scrape_run_attributes[:detail].length).to eq(500)
  end

  it "renders a blank message as an empty string" do
    result = described_class.new(outcome: ScrapeRun::SUCCESS)

    expect(result.to_s).to eq("")
  end
end
