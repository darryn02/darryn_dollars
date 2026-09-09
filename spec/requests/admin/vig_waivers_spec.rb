require "rails_helper"

RSpec.describe "Admin vig waivers", type: :request do
  let(:admin) { create_user(name: "The Book", admin: true) }
  let!(:admin_account) { create_account(user: admin) }

  let(:player) { create_user(name: "Plain Player") }
  let!(:player_account) { create_account(user: player) }

  let(:game) { create_game(starts_at: 2.hours.ago) }
  let(:away) { game.contestants.order(:priority).first }
  let(:line) { create_spread(game: game, contestant: away, value: -3.0, odds: -110) }

  describe "authorization" do
    it "is not reachable by a player" do
      sign_in player

      get new_admin_vig_waiver_path

      expect(response).not_to have_http_status(:ok)
    end

    it "is reachable by an admin" do
      sign_in admin

      get new_admin_vig_waiver_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET index (the preview)" do
    it "shows only wagers matching the submitted scope" do
      wager = create_wager(account: player_account, line: line, amount: 110, status: :loss)

      sign_in admin
      get admin_vig_waivers_path, params: { scope_type: "line", line_id: line.id }

      expect(response.body).to include("Plain Player")
      expect(wager.reload).not_to be_vig_waived
    end
  end

  describe "POST create" do
    it "waives the vig only on the wagers actually checked" do
      keep = create_wager(account: player_account, line: line, amount: 110, status: :loss)
      leave = create_wager(account: player_account, line: line, amount: 220, status: :loss)

      sign_in admin
      post admin_vig_waivers_path, params: {
        scope_type: "line", line_id: line.id, wager_ids: [keep.id]
      }

      expect(keep.reload).to be_vig_waived
      expect(keep.net).to eq(-100)
      expect(leave.reload).not_to be_vig_waived
    end

    # A player could not reach this controller at all (require_admin!), but
    # the id list is still re-derived through the submitted scope rather
    # than trusted outright - a wager from outside the scope must not slip
    # through just because its id was added to the params.
    it "ignores a wager id outside the submitted scope" do
      in_scope_game = game
      outside_game = create_game(starts_at: 2.hours.ago,
                                 away: create_competitor(region: "Dallas", name: "Cowboys", abbreviation: "DAL"),
                                 home: create_competitor(region: "New York", name: "Giants", abbreviation: "NYG"))
      outside_line = create_spread(game: outside_game, contestant: outside_game.contestants.order(:priority).first,
                                   value: -3.0)
      outside_wager = create_wager(account: player_account, line: outside_line, amount: 110, status: :loss)

      sign_in admin
      post admin_vig_waivers_path, params: {
        scope_type: "line", line_id: line.id, wager_ids: [outside_wager.id]
      }

      expect(outside_wager.reload).not_to be_vig_waived
    end

    it "credits a bet that already settled as a loss" do
      wager = create_wager(account: player_account, line: line, amount: 110, status: :loss)
      expect(wager.net).to eq(-110)

      sign_in admin
      post admin_vig_waivers_path, params: { scope_type: "line", line_id: line.id, wager_ids: [wager.id] }

      expect(wager.reload.net).to eq(-100)
    end
  end

  describe "DELETE destroy" do
    it "clears a waiver and recomputes net back to the full stake" do
      wager = create_wager(account: player_account, line: line, amount: 110, status: :loss)
      wager.update!(vig_waived: true)

      sign_in admin
      delete admin_vig_waiver_path(wager)

      expect(wager.reload).not_to be_vig_waived
      expect(wager.net).to eq(-110)
    end
  end
end
