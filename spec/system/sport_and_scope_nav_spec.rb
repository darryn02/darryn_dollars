require "rails_helper"

# The sport nav carried an `overflow-x: auto`, which clipped the very dropdowns
# it contained: the markup was all present and correct, and the first and second
# half lines were simply unreachable. Nothing that asserts on markup alone would
# have caught it, so these specs check two things a real browser can answer -
# whether the items can actually be clicked through to the board they name, and
# whether any ancestor is clipping the open menu.
RSpec.describe "The sport and scope nav", type: :system do
  let(:user) { create_user }
  let!(:account) { create_account(user: user) }
  let(:game) { create_game(starts_at: 2.hours.from_now) }

  let!(:away_contestant) { game.contestants.order(:priority).first }

  let!(:game_line) { create_spread(game: game, contestant: away_contestant, value: 2.5) }
  let!(:first_half_line) { create_spread(game: game, contestant: away_contestant, value: 1.5, scope: :first_half) }
  # 0.0 so the board has to render it as PICK, which is how a pick'em reaches
  # the player and is easy to regress into a bare "0.0".
  let!(:second_half_line) { create_spread(game: game, contestant: away_contestant, value: 0.0, scope: :second_half) }

  around do |example|
    original = ENV["NCAAF_ENABLED"]
    example.run
  ensure
    ENV.delete("NCAAF_ENABLED")
    ENV["NCAAF_ENABLED"] = original if original
  end

  before { login_as(user, scope: :user) }

  # The `show` class goes on before Popper has positioned anything, so for a
  # frame or two the menu is open but still parked at the top-left corner.
  # Asserting on it then measures the wrong box, and clicking an item then
  # sends the click to wherever that item used to be. Popper stamps the
  # placement onto the menu once it has really placed it, so that is the
  # signal worth waiting for.
  def open_sport_menu(label)
    find(".dd-scope-pill", text: label).click
    expect(page).to have_css(".dd-scope-nav .dropdown-menu.show[data-popper-placement]")
  end

  # Walks up from the open menu looking for an ancestor that both establishes a
  # scrollport and fails to contain the menu's box. Returns nil when the menu
  # hangs free, or a description of the offender - which is what the regression
  # would produce.
  def clipping_ancestor
    page.evaluate_script(<<~JS)
      (function () {
        var menu = document.querySelector('.dd-scope-nav .dropdown-menu.show');
        if (!menu) { return 'no open menu'; }

        var mr = menu.getBoundingClientRect();
        if (mr.width === 0 || mr.height === 0) { return 'menu has no box'; }

        var el = menu.parentElement;
        while (el && el !== document.body) {
          var cs = window.getComputedStyle(el);
          if (cs.overflowX !== 'visible' || cs.overflowY !== 'visible') {
            var r = el.getBoundingClientRect();
            if (mr.top < r.top - 1 || mr.bottom > r.bottom + 1 ||
                mr.left < r.left - 1 || mr.right > r.right + 1) {
              return (el.className || el.tagName) +
                     ' (overflow ' + cs.overflowX + '/' + cs.overflowY + ') clips the menu';
            }
          }
          el = el.parentElement;
        }
        return null;
      })()
    JS
  end

  it "opens the sport menu with all three scopes showing" do
    visit lines_path

    open_sport_menu("NFL")

    within(".dd-scope-nav .dropdown-menu.show") do
      expect(page).to have_css(".dropdown-item", text: "Game")
      expect(page).to have_css(".dropdown-item", text: "First Half")
      expect(page).to have_css(".dropdown-item", text: "Second Half")
    end
  end

  it "lets the open menu hang outside the nav strip instead of clipping it" do
    visit lines_path

    open_sport_menu("NFL")

    expect(clipping_ancestor).to be_nil

    box = page.evaluate_script(<<~JS)
      (function () {
        var menu = document.querySelector('.dd-scope-nav .dropdown-menu.show');
        var nav = document.querySelector('.dd-scope-nav');
        var mr = menu.getBoundingClientRect();
        return {
          menu_bottom: mr.bottom,
          nav_bottom: nav.getBoundingClientRect().bottom,
          viewport: window.innerHeight
        };
      })()
    JS

    # It has to escape the strip it lives in, and still land on screen.
    expect(box["menu_bottom"]).to be > box["nav_bottom"]
    expect(box["menu_bottom"]).to be <= box["viewport"]
  end

  it "reaches the first half board through the menu" do
    visit lines_path

    open_sport_menu("NFL")
    click_link "First Half"

    expect(page).to have_css(".dd-bet-btn", text: "+1.5")
    expect(page).to have_no_css(".dd-bet-btn", text: "+2.5")
  end

  it "reaches the second half board through the menu" do
    visit lines_path

    open_sport_menu("NFL")
    click_link "Second Half"

    expect(page).to have_css(".dd-bet-btn", text: "PICK")
    expect(page).to have_no_css(".dd-bet-btn", text: "+2.5")
  end

  it "drops the college pill when that board is switched off" do
    ENV["NCAAF_ENABLED"] = "0"

    visit lines_path

    expect(page).to have_css(".dd-scope-pill", text: "NFL")
    expect(page).to have_no_css(".dd-scope-pill", text: "NCAAF")
  end
end
