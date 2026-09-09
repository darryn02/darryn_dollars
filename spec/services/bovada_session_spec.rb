require "rails_helper"

RSpec.describe BovadaSession, type: :service do
  let(:home) { BovadaSession::HOME_PAGE }
  let(:api) { "https://www.bovada.lv/services/sports/event/v2/events/A/description/football/nfl" }

  it "warms the home page and carries any cookies it issued onto the next request" do
    stub_request(:get, home).to_return(
      status: 200, body: "<html></html>",
      headers: { "Content-Type" => "text/html", "Set-Cookie" => "TS0189=abc123; Path=/" }
    )
    stub_request(:get, api).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

    described_class.new.warm!.get_json(api)

    expect(a_request(:get, api).with(headers: { "Cookie" => "TS0189=abc123" })).to have_been_made
  end

  it "sends a Referer pointing back at the home page" do
    stub_request(:get, home).to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })
    stub_request(:get, api).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

    described_class.new.warm!.get_json(api)

    expect(a_request(:get, api).with(headers: { "Referer" => home })).to have_been_made
  end

  it "identifies itself as a browser, not Ruby's default" do
    stub_request(:get, home).to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })
    stub_request(:get, api).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

    described_class.new.warm!.get_json(api)

    expect(a_request(:get, api).with { |req| req.headers["User-Agent"].to_s.include?("Chrome") }).
      to have_been_made
  end

  it "raises Challenged when the response is not JSON" do
    stub_request(:get, home).to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })
    stub_request(:get, api).to_return(status: 200, body: "<html>Access Denied</html>",
                                      headers: { "Content-Type" => "text/html" })

    expect { described_class.new.warm!.get_json(api) }.to raise_error(BovadaSession::Challenged, /expected json/)
  end

  it "raises Challenged when the body claims to be JSON but does not parse" do
    stub_request(:get, home).to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })
    stub_request(:get, api).to_return(status: 200, body: "not actually json",
                                      headers: { "Content-Type" => "application/json" })

    expect { described_class.new.warm!.get_json(api) }.to raise_error(BovadaSession::Challenged, /unparseable body/)
  end

  it "raises Challenged on a non-2xx response" do
    stub_request(:get, home).to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })
    stub_request(:get, api).to_return(status: 403, body: "denied")

    expect { described_class.new.warm!.get_json(api) }.to raise_error(BovadaSession::Challenged, /403/)
  end

  it "still returns itself when warming the home page is challenged" do
    stub_request(:get, home).to_return(status: 403, body: "denied")
    stub_request(:get, api).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

    session = described_class.new.warm!

    expect(session).to be_a(described_class)
    expect(session.get_json(api)).to eq({})
  end
end
