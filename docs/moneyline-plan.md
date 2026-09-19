# Adding moneyline betting to Darryn Dollars

**Branch:** `moneyline-betting` (off `master`)
**Status:** plan, reviewed 2026-09-10; rollout revised 2026-09-19. Nothing implemented.
**Constraint:** do not change point spread or total behavior.

Moneyline lines are already scraped and stored — `BovadaApiClient` treats
"Moneyline" as a relevant market, and `LineBuilder` preserves Bovada's real
per-side odds for it (`odds: @kind == :moneyline ? @odds : -110`, the one kind
not hardcoded to -110). 386 moneyline lines exist in the live database, 150
active. Zero moneyline wagers have ever been placed, because the board never
offers one.

This plan closes the gap between "the data exists" and "a player can bet one and
it settles correctly", under three constraints: bound the book's worst-case
single payout, never give back structural edge, and be able to switch the whole
thing off without a deploy.

---

## Decisions (locked)

| Decision | Value | Rationale |
|---|---|---|
| Underdog odds cap | **+300**, `MONEYLINE_MAX_ODDS` | Pulls the dog side from 13.5% of games (vs 26% at +250) and caps a single bet at 3× stake. Evaluated at read time, so it is a dial that can be tightened mid-season with a config change and no re-scrape. |
| Vig floor | **derived from `-110`** in code — `2 × implied_probability(-110)` = 1.047619 | No env var and no magic constant, so it can never drift from what spread and total already charge. The rule states itself: every market on this board pays at least what -110 pays. |
| Probability clamp | **0.99** on the scaling path | Bounds the converted probability whenever a pair is being raised to the floor. A pair already at or above the floor short-circuits untouched and is therefore *not* subject to the clamp — so this is not a global price ceiling, and a raw -12000 can still be stored. |
| Kill switch | `MONEYLINE_ENABLED`, absent = **off** | Deliberately inverted from the `NCAAF_ENABLED` convention (absent = on) for the first deploy, so shipping the code does not ship the market. **Truthiness is an explicit allowlist**, not the `Sports` idiom: on only for `"1"` or `"true"` (case-insensitive), off for absent or anything else. Copying `Sports`' `!= "0"` test would make `MONEYLINE_ENABLED=false` read as *enabled* — the one control that must fail closed. |

**Still open — see Deferred / Open Questions:** whether the cap withholds only
the underdog side or the whole moneyline market for that game. An earlier draft
recorded this as settled; it was not.

---

## Survey: everywhere that assumes a line is a spread or a total

### From the original brief, confirmed

| Location | What is wrong |
|---|---|
| `app/services/moneyline_scorer.rb:2-4` | `run` returns a zero tally and never calls `win!/loss!/push!`. A confirmed moneyline wager would sit `confirmed` forever, permanently inside `Account#liabilities`. |
| `app/models/game_lines_view_model.rb:8`, `:37-41`, `:78-86`, `:70-74` | `Row` has no moneyline slot; `build_row` takes only spread and total; `bet_lines` returns `[row.spread, row.total]`, so no bet button is ever rendered. |
| `app/helpers/lines_helper.rb:20`, `app/helpers/wagers_helper.rb:6` | Both branch `line.point_spread? ? spread_label : total_label`. Feeding a moneyline to `total_label` (`lines_helper.rb:14`) prints `"U 0.0"` — `line.over?` is false, so it renders "U". |
| `app/models/line.rb:58-88` | `kind_string` returns nil for `moneyline` and `value_string` sees `value == 0.0` and prints `PICK`, so a -285 favorite renders `"JAX PICK (-285 1H)"`. |
| `app/models/game_lines_view_model.rb:95-100` | The chump stamp compares a spread against its opposing spread and a total against its opposing total. No moneyline leg. |

### Additional findings

**1. `LineBuilder#odds` silently turns a non-numeric price into 0.**
`LineBuilder.rb:23` does `o.to_i`. Bovada's feed emits `"american": "EVEN"` for a
+100 price, and `"EVEN".to_i == 0`. `Line#payout` (`line.rb:46-52`) then takes
the `odds >= 0` branch and returns `amount * 0 * 0.01` — **$0 profit on a winning
bet**. Harmless so far only because spread and total hardcode -110; moneyline is
the one kind that trusts the parsed value.

`"EVEN"` is not corrupt data — it is Bovada's canonical rendering of exactly
+100, a well-defined price. It must be **mapped to `100`**, not rejected;
rejecting it would silently drop the moneyline market for every near-pick'em
game, which is the shape of game most worth offering, and would contradict the
odds bound below, which makes +100 explicitly legal.

Not confirmed against a live payload — the spec fixture
(`spec/services/bovada_api_client_spec.rb:109-110`) only ever uses `"-110"`.
Pre-flight check, required **before** the bound in step 11 lands:
`Line.moneyline.where(odds: -99..99).count`.

**2. The board is a hard three-column grid.**
`app/views/lines/_game.html.haml:11-14` renders exactly two `bet_cell`s, and
`.dd-game__row` (`app/assets/stylesheets/base/_theme.scss:476-486`) is
`grid-template-columns: minmax(0, 1fr) 5.25rem 5.25rem`. Three bet columns at
5.25rem is 252px, leaving ~90px for the team block on a 360px phone. The board
also has no column headers today — survivable with two columns, confusing with
three.

`.dd-bet-btn__value` has **no CSS rule at all** — no `white-space`, no overflow
handling — so a signed price in a narrowed button can spill into the adjacent
cell rather than wrap or truncate.

**3. `app/views/lines/_bet_cell.html.haml:7`** — `aria-label => "Bet #{line}"`
routes through `Line#to_s`, so screen readers get the "PICK" garbage too. Fixed
for free by the `to_s` change.

**4. `app/models/wager.rb:69-74` (`Wager#to_s`) and `Wager.list_all`** interpolate
`Line#to_s`. Same fix.

**5. `app/views/admin/vig_waivers/new.html.haml:15`** — the "one line" dropdown is
`Line.active` unfiltered by kind, rendering `"#{line.game} — #{line}"`. This is
where the `to_s` bug is already visible in the live app today.

**6. `LineBuilder#find_or_create!` keys the lookup on `odds`**
(`LineBuilder.rb:33-40`). Moneyline is the only kind whose odds move, so every
price change mints a new `Line` row and hides the old one — which is why 386 rows
back 150 active lines. Three consequences:

- A wager freezes the price it was placed at. Good: the cap is evaluated against
  `line.odds`, which never mutates on an existing row.
- **Ordinary price movement invalidates a pending slip.** This is not limited to
  a floor-constant change. Any one-point tick mints a new row, `update_lines`
  hides every active id the current scrape did not return
  (`bovada_api_client.rb:43`), and `line_must_be_active` (`wager.rb:140-146`)
  then refuses the confirm — so a player will routinely be unable to confirm a
  moneyline wager they added minutes earlier. Spread and total rows only re-key
  when the handicap itself moves; moneyline re-keys on every tick, and
  second-half moneylines are re-scraped on any page view older than a minute
  (`ensure_second_half_lines_are_recent!`). Both confirm paths must report this
  as a *price moved* message naming the line, not a generic "no longer active".
- Changing the vig floor constant re-keys every moneyline line at once, with the
  same effect on every open slip. Do not change the floor mid-week.

**7. `lib/tasks/dev.rake` is already dead code**, not a spreads-only seeder.
`dev:prime` cannot run at all against the current schema: it calls
`g.contests.create` (dev.rake:10) but `Game` has no `contests` association — only
`Competitor` does (`competitor.rb:11`) — and it uses `lines.over_unders` /
`lines.point_spreads` scopes that do not exist on `Line`, plus
`FactoryGirl::Syntax::Methods`, a constant factory_bot 6.4.6 no longer defines.
Adding moneyline seeds means rewriting the task, not extending it.

**8. `spec/support/domain_builders.rb:46-67`** has `create_spread` and
`create_total` but no `create_moneyline`. `create_total` takes no `contestant:`,
and a contestant-less moneyline makes the inherited scorer return early rather
than grade. `create_full_card` builds four lines; adding moneyline to it by
default would change the shape of every board and chump-stamp spec, so it goes
behind a keyword defaulting to off.

**9. `spec/services/moneyline_scorer_spec.rb`** currently *asserts the no-op*
("This pins that down so it stays a decision"). It gets rewritten, not extended.

**10. `Wager#loss_amount` misbehaves on a moneyline favorite.** `min(potential_profit, amount)`
(`wager.rb:92-94`) is safe on the dog side, but on a favorite it caps a $100 loss
at $35.09 at -285 and $20 at -500 — a 65–80% refund of stake, against 9% on a
-110 spread. This is not hypothetical: `Line::KIND_GROUPS` already ships
`"moneyline"` and `"all"`, and `admin/vig_waivers/new.html.haml:33` already
renders both options, so the day-wide "All markets" waiver will sweep moneyline
favorites the first time one exists.

### Verified as already fine

- `app/javascript/application.js:7-30` — amount ↔ to-win is generic off
  `data-odds`. Checked both directions: -285 with $500 → $175.44; +250 with $100
  → $250. Both match `Line#payout`.
- `LineScorerFactory` already routes `moneyline` → `MoneylineScorer`.
  `WagerScorer` is kind-agnostic.
- `Leaderboard` and `LeaderboardEntry` are entirely kind-agnostic.
- `LinesController#index` already loads moneyline lines into the view model and
  discards them, so the new column costs **no extra query**.
- A tie is graded a push by the same equality branch `PointSpreadScorer` already
  uses — correct moneyline grading, and 2H ties are common. `ScoreScraper` only
  writes scores for completed games (`score_scraper.rb:32`), so the `scores[2..]`
  empty-array path is not reachable.
- `_bet_form`, `_pending_bet_slip`, `_confirmed_bet_slip`, `_account_history` and
  the vig-waiver table all render bets through `wager_line_label` + `line_terms`,
  so they need no changes beyond the Phase 2 helper fix. Note `_game.html.haml`
  calls `spread_label`/`total_label` directly and does need wiring.

---

## Pricing math, as verified

The one-directional vig floor, as specified:

```
raw_p_a, raw_p_b = implied_probability(odds_a), implied_probability(odds_b)
raw_overround    = raw_p_a + raw_p_b
scale            = [1.0, VIG_FLOOR / raw_overround].max   # never < 1
scaled_p_a, scaled_p_b = raw_p_a * scale, raw_p_b * scale
```

then clamp each scaled probability to 0.99 and convert back to American odds.

Running this over real pairs surfaced two requirements that are not obvious from
the formula:

**Rounding must go toward the book, or the floor leaks.** Converting the scaled
probabilities back with plain `.round` lands *below* the floor in most cases:

```
 -185/+160    scale=1.0134   .round → -192/+157   = 104.66%    BELOW FLOOR
                             book   → -193/+156   = 104.93%    ok
-2000/+1500   scale=1.0323   .round → -5818/+1450 = 104.762%   BELOW FLOOR
                             book   → -5819/+1449 = 104.766%   ok
```

So the favorite rounds away from zero (ceil the magnitude) and the dog rounds
down. Integer odds can then only ever overshoot the floor, never undershoot,
which is the whole point of the one-directional rule.

**The normalizer must short-circuit when `scale == 1.0`.** Re-deriving odds
through probability when nothing needs raising damages a pair that is already at
the floor:

```
-110/-110    raw=104.762% (== floor)   scale=1.0   re-derived → -111/-111 = 105.21%
-415/+310    raw=104.973%              scale=1.0   re-derived → -415/+310 (round-trips by luck)
```

Return the raw integers untouched whenever `scale == 1.0`.

**The clamp works, with a caveat.** `-5000/+3500` scales the favorite to 1.01875
— overflow, no valid American representation. Clamping to 0.99 prevents it, but
the pair then sits at 101.89%, *below* the floor: on that shape the clamp and the
floor genuinely conflict and the clamp has to win.

The optional refinement — give the dog the remainder (`VIG_FLOOR − 0.99`),
turning +3364 into +1635 — is **provably safe to defer**. Whenever the clamp
fires, the scaled total is exactly the floor, so the dog's probability is at most
`1.047619 − 0.99 = 0.0576`, i.e. +1635 or longer. Swept across all clamping
pairs the minimum dog price is +1635, 5.4× the +300 cap, so the dog side is
always withheld — not merely "in practice".

**Two more shapes to handle:**

- The formula's `fav_odds, dog_odds` framing implies a split that does not always
  exist. `-105/-115` is a valid pair with two favorites; it scales, and it needs
  the book rounding. Name the arguments for the two outcomes, not for favorite
  and dog.
- If Bovada returns a **one-sided** moneyline market (the other side suspended),
  there is no pair to normalize. Skip that market entirely rather than offering
  it unnormalized.

Normalization does not meaningfully distort the cap's stated market impact:
across realistic pairs it moves a dog only about 4–7 points, and of 1.66M integer
pairs with a raw dog above +300, only 744 land at or below +300 after
normalization — all at implausibly tight overrounds, with the highest crossing
dog at +317.

---

## Ordered plan

**Deploy ordering is a safety property, not a preference.** An earlier draft
claimed everything through Phase 5 is invisible to players. That is wrong: today
the no-op scorer is the only thing making a crafted wager harmless, so Phase 1
*removes* protection that Phase 5 has not yet replaced. `WagersController#create`
accepts any `line_id` with no kind check and 150 moneyline lines are active right
now, so between those two phases a direct POST would be paid out at Bovada's raw,
un-normalized, uncapped price.

**Phase 3's policy model and Phase 5's wager validation must land in the same
deploy as, or before, the Phase 1 scorer fix.** Phases may be split into separate
deploys only in that order.

### Phase 0 — test support (must precede Phase 5)

**1. `spec/support/domain_builders.rb`** — `create_moneyline` (taking
`contestant:`, unlike `create_total`), and `create_full_card(moneyline: false)`.
Set the test-env default for `MONEYLINE_ENABLED` explicitly, using the
`around`/ENV-restore pattern from `spec/models/sports_spec.rb:4-10`, so specs do
not depend on ambient config. Without this, Phase 5's create-time validation
rejects every moneyline wager in the suite — the ambient state is "absent", which
is off — and Phase 1's own spec goes red the moment Phase 5 lands.

### Phase 1 — settle correctly first

**2. `app/services/moneyline_scorer.rb`** — delete the no-op. Extract the score
comparison from `PointSpreadScorer#run` into a `margin_threshold` (spread returns
`line.value`, moneyline returns `0`), so moneyline never silently inherits a
stray `value`. Ties push. `MoneylineScorer` must return the zero tally rather
than `nil` when the line has no matching contestant: `PointSpreadScorer#run`
currently returns nil there and `LineScorer` then calls `nil.fetch(:wins, 0)`, so
one unattributable row (the contestant FK is `on_delete: :nullify`) aborts the
whole scoring run — spread and total settlement with it.

**3. First scoring run after this deploy** must be scoped to
`Line.pending.where.not(kind: :moneyline)` until the existing backlog has been
inspected. `LineScorer.run` defaults to `Line.pending` with no kind filter, so
otherwise the first real exercise of moneyline grading is a bulk write across 386
historical rows rather than the controlled run in Phase 7.

*Tests:* rewrite `spec/services/moneyline_scorer_spec.rb` — favorite wins, dog
wins, tie pushes, missing scores stay pending, contestant-less row returns a zero
tally, 1H and 2H scoping. Plus one end-to-end `LineScorer` → `WagerScorer` case
proving a confirmed moneyline wager reaches `win`/`loss` and drops out of
`Account#liabilities`.

### Phase 2 — labels

Fixes the admin dropdown that is already polluted today. No player-visible
change.

**4. `app/models/line.rb`** — `value_string` and `kind_string` handle
`moneyline`: no value segment, so `to_s` renders `"JAX ML (-285 1H)"`.

**5. `app/helpers/lines_helper.rb` and `app/helpers/wagers_helper.rb`** — replace
both `point_spread? ? … : …` ternaries with one shared `side_label(line)` doing a
`case line.kind`. `side_label` returns `"ML"` for a moneyline, used by
`line_headline` and `wager_line_label`, where `line_terms` already carries the
price alongside — so the sheet, slip and history read `"BUF ML"`. **The board
cell is different and takes the price itself** (see step 15).

*Tests:* moneyline `to_s` cases in `spec/models/line_spec.rb` (game and half);
helper specs for `side_label` across all four kinds.

### Phase 3 — policy and pricing, pure and unwired

**6. New `app/models/american_odds.rb`** — `implied_probability(odds)` and
`from_probability(p)` with round-toward-book.

**7. New `app/models/moneyline.rb`** — modelled on `Sports` in shape but not in
truthiness: `enabled?` (`MONEYLINE_ENABLED`, on only for `"1"`/`"true"`
case-insensitive, off for absent or anything else), `max_odds`
(`MONEYLINE_MAX_ODDS`, default 300), `VIG_FLOOR` derived from -110,
`PROBABILITY_CEILING` = 0.99, and `offerable?(line)` combining the switch and the
cap.

**8. New `app/services/moneyline_pricer.rb`** — `.normalize(odds_a, odds_b)`:
short-circuit when `scale == 1.0`, clamp, convert back with book rounding.

*Tests:* -415/+310 (never lowered), -110/-110 (returned identical, not
re-derived), -185/+160 (raised, result's overround ≥ floor), -105/-115 (two
favorites), -5000/+3500 (clamp prevents overflow, does not raise, emits valid
odds). Plus a sweep asserting **no pair in which neither side clamps ever comes
back with a lower overround than it went in with** — the clamp is the documented
exception in both directions, since a favorite already priced worse than -9900
is clamped *down* by design.

### Phase 4 — scrape wiring

**9. `app/services/bovada_api_client.rb#find_or_create_line:180-193`** — this is
the trust boundary, and both the validation and the normalization belong here.
`LineBuilder` sees one outcome at a time and, more importantly, sees only the
*normalizer's output* — so a bad raw price validated there has already corrupted
the other side's re-pricing through `raw_overround` and `scale`, and the
resulting integer looks plausible enough to pass any downstream bound.

For a Moneyline market: read both raw prices, map `"EVEN"` → `100`, and require
each to be an integer outside (-100, 100) and the market to have exactly two
outcomes. Then normalize the pair, then build.

**10. Failure mode is skip-and-report, never raise.** `find_or_create_line` runs
inside an unrescued `flat_map` in `parse_and_assert_lines`, so a raise aborts
every other game in the response, writes no `ScrapeRun`, and 500s the second-half
board through `LinesController`'s before-action. Skip the offending market and
report it through the existing `report_unresolved`/Honeybadger path
(`bovada_api_client.rb:137-149`) — the same discipline that path already applies
to unrecognised competitors.

**11. `app/models/LineBuilder.rb:22-24`** — keep a strict parse as a
defence-in-depth backstop, guarded on `@kind == :moneyline` exactly as
`find_or_create!` already guards the odds column, so a future malformed
spread/total payload cannot break ingestion for those kinds. If a model-level
`Line` odds bound is wanted as well, it **must** be `on: :create`. Unscoped, it
fires on `line.win!`/`loss!`/`push!` inside `LineScorer#run`'s unrescued
`find_each`, so any legacy moneyline row with odds in (-100, 100) would abort
spread and total settlement. (The scraper's own hide/unhide path is safe either
way — `bovada_api_client.rb:43` and `:50` use `update_all`, which bypasses
validations.)

**12. Migration** — `add_column :lines, :raw_odds, :integer, null: true`, plus a
`LineBuilder#raw_odds(o)` setter fed from `find_or_create_line`. Write it on
**both** branches of `find_or_create!` — set after the find, not only inside the
create block — so a row that survives a scrape carries the price that scrape
actually saw. Left in the create block alone the column answers nothing: the
block runs only on create, so every one of the ~150 currently active rows would
stay NULL forever. `raw_odds` stays nil for non-moneyline rows, so the column
keeps one audit-clean meaning.

Reviewers split on whether to instead add `raw_odds` to the `find_or_create_by!`
lookup key, on the grounds that normalization is heavily many-to-one. Rejected:
keying on it means a raw tick that does not change the offered price still mints
a new row, which makes the pending-slip invalidation in survey finding 6 strictly
worse.

*Tests:* extend `spec/services/bovada_api_client_spec.rb` with a moneyline market
fixture — normalized odds persisted, `raw_odds` retained and refreshed,
`"EVEN"` mapped to +100, a non-numeric price skipping only its own market while
the rest of the response still lands, one-sided market skipped, and spread/total
odds still exactly -110.

### Phase 5 — server-side enforcement, before any UI

**13. `app/models/wager.rb`** — one validation covering both the kill switch and
the cap. **Register it unconditionally and guard inside the body**, matching
`game_has_not_started` and `line_must_be_active` (`wager.rb:19-21`):

```ruby
validate :moneyline_is_offerable
# ...
def moneyline_is_offerable
  return unless new_record? || confirming?
  # ...
end
```

`validate :x, on: :create, if: :confirming?` would never fire in either context —
`confirming?` is `persisted? && changes["status"] == ["pending", "confirmed"]`
(`wager.rb:156-158`), and `persisted?` is false while a new record is validated —
so the kill switch and the cap would silently enforce nothing.

The guard is what keeps the admin vig-waiver working: `wager.update!(vig_waived: true)`
(`admin/vig_waivers_controller.rb:33`) on a historical moneyline wager placed
before the cap tightened is neither a create nor a confirm, so it passes.

**14. `app/controllers/bet_slips_controller.rb:17-21`** — `update` calls
`wager.confirmed!` in a bare loop with no rescue, so flipping the kill switch
while someone holds a pending moneyline wager 500s their whole slip. Mirror
`WagersController#confirm_pending` (`wagers_controller.rb:44-48`) — but mirror
its *reporting*, not just its `rescue`. A bare rescue leaves
`@bet_slip.confirmed!` and the unconditional "Your wagers have been confirmed!"
flash intact, so the player is told a rejected wager succeeded while it sits
`pending`, outside `Account#liabilities`, settling nothing. Collect the per-wager
errors, leave the slip pending when any wager failed, and surface them.

*Tests:* request specs posting to `/wagers` and `/wagers/confirm_pending` with a
`line_id` for (a) an over-cap dog and (b) any moneyline with the switch off,
**bypassing the board entirely** — that is the actual threat. Plus: the switch
off leaves `bet_lines` empty of moneyline *and* rejects the direct POST *and*
leaves a slip containing a stale pending moneyline wager unconfirmed with an
accurate message.

### Phase 6 — the board

**15. `app/models/game_lines_view_model.rb`** — `moneyline` slot on `Row`;
`moneyline_lines` mirroring `spread_lines:111-117` (contestant-attributed,
`sort_by(&:created_at).take(2)`, then by priority); `build_row` and `bet_lines`
gated on `Moneyline.offerable?`.

**The gate must null the withheld line inside `build_row`, not filter
`moneyline_lines` before pairing.** `rows` pairs positionally against
`competitors.first/.second`, so filtering first shifts a surviving favorite onto
the wrong team's row.

The board cell shows **the price** (`"-285"` / `"+240"`), not `"ML"`. The cell
carries no team — that is a separate column — and today always shows a bare
differentiating value (`"+2.5"`, `"O 47.5"`). Reusing `"ML"` would render
identically on both rows, under a header that also says ML, giving the bettor
nothing to read.

**Chump stamp: moneyline is included**, via a payout-weighted comparison.
`GameLinesViewModel#chump_total` sums each side's stake today, which is
meaningful only because both sides are -110; on a moneyline, $500 on a -500
favorite against $50 on a +400 dog would flag the favorite every time regardless
of where the money actually is. Weighting by `potential_profit` fixes that and is
**behavior-preserving for spread and total**: `LineBuilder#find_or_create!`
hardcodes -110 on every one of them, so payout-weighting scales both sides of an
existing comparison by the same 0.909 and can flip no current stamp. `Row` gets a
`moneyline_flagged` slot alongside `spread_flagged` and `total_flagged`.

**16. `app/views/lines/_game.html.haml`, `index.html.haml` and `_theme.scss:476-486`**
— third bet cell, four-column grid, columns down to roughly 4.25rem to fit a
360px phone. Add `white-space: nowrap` to `.dd-bet-btn__value`, which has no rule
today. (A one-liner is the whole fix: with the cap in place, four-figure prices
are not offered, so no ellipsis or font-scaling scheme is warranted.)

The column header row (Spread / Total / ML) goes **once at the top of `.dd-board`
in `index.html.haml`**, not in `_game.html.haml` — that partial renders per game
card, so putting it there repeats the header above every game on the slate.

**All of this is gated on `Moneyline.enabled?`** — the third cell, the header row
and the four-column grid alike, not just the per-row line data. Gating only
`build_row`/`bet_lines` would still narrow every existing spread and total button
and add a header the moment the code deploys with the switch off, which is
exactly the change to point spread and total rendering this plan forbids, and
would happen before moneyline is live at all.

*Tests:* `spec/models/game_lines_view_model_spec.rb` — moneyline rows and
`bet_lines`, empty when disabled or over-cap, and the withheld side leaving its
own row rather than shifting its partner. System spec: moneyline button renders
with the price, offcanvas opens, form carries the right `data-odds`, wager
persists at the moneyline price. **A spec asserting the board's markup and grid
are byte-identical to today while the switch is off.** The existing
`lines_board_spec`, `chump_stamp_spec` and `placing_a_wager_spec` stay green
because `create_full_card` does not add moneyline by default.

### Phase 7 — rollout

**17. Vig waiver excludes moneyline for v1.** Drop `moneyline` from the
`Line::KIND_GROUPS` entries the vig-waiver scopes consume, and from the market
dropdown in `admin/vig_waivers/new.html.haml`. Waiving on a favorite refunds
65–80% of stake (survey finding 10), far more than the -110 vig the tool was
built to return, and the day-wide "All markets" scope would sweep those
automatically.

**18. There is no rehearsal environment.** `darryn-dollars-staging` is the app
the players actually use; the Heroku app named "production" is not in service.
So the kill switch, not a separate tier, is what makes this recoverable — which
is the reason it defaults to off and the reason its truthiness is an explicit
allowlist.

Sequence:

1. Deploy to `darryn-dollars-staging` with `MONEYLINE_ENABLED` unset. Verify the
   board is byte-identical to before: no third column, no header row, unchanged
   button widths. This is the deploy that must be safe on its own.
2. Run the pre-flight `Line.moneyline.where(odds: -99..99).count` check against
   the live database, and resolve anything it returns before going further.
3. Pick a window with no game inside `Wager::WINDOW` of kickoff, so no player has
   an open slip and nothing is mid-settlement.
4. Flip `MONEYLINE_ENABLED` on. Force a scrape, compare a normalized pair against
   Bovada's live board by hand, and place, confirm and settle one wager from an
   admin account end to end.
5. If anything looks wrong, unset the variable — that is a config change, not a
   deploy, and it takes the market off the board without touching spread or
   total.

**19. One week after the flip**, review moneyline wagers grouped by line and side
(stake and `potential_profit` totals) and tighten `MONEYLINE_MAX_ODDS` if any
single line's committed payout exceeds what the book is willing to owe. The cap's
value as a mid-season dial is inert without a signal telling the operator when to
turn it, and there is no exposure view anywhere in the app.

**20. `lib/tasks/dev.rake`** — rewrite `dev:prime` on top of `DomainBuilders`,
including moneyline. The task is currently dead code (survey finding 7), so this
is a rewrite rather than an addition.

---

## Out of scope, flagged

There is **no concept of the book's aggregate exposure on one side of a line, for
any kind, anywhere in the app.** `Account#liabilities` is not that and was never
meant to be — it is the player's own stake at risk, and all three call sites use
it that way: the credit check (`wager.rb:151`), "still in play"
(`_account_history.html.haml:9`), and credit utilization (`:1`).

Moneyline is the first market where a player's stake and the book's exposure
diverge, so **the odds cap is the only thing bounding what the book can owe.**
The cap bounds a *single* bet at 3× stake; nothing bounds the aggregate. A player
can take the same side on the game, 1H and 2H moneylines of one game, and every
player can take the same dog. Across ~12 accounts at the $1,000 default credit
limit, worst-case single-game exposure goes from roughly **$10,900 at -110 to
$36,000 at +300** — a 3.3× multiplier. Building an actual exposure view is
separate work, not part of this.

Two pre-existing issues surfaced during review, neither introduced here and
neither in scope: the admin scoring routes (`mark_as_win`/`loss`/`push`,
`score_wagers`, `fetch_lines`) are GET, so they mutate money state outside CSRF
protection (they are `require_admin!`-gated, but moneyline makes the amounts a
mis-fired settlement moves considerably larger); and the 24-hour betting window
is enforced only in `GameLinesViewModel#bet_lines`, so a direct POST can place a
wager on a game days out.

---

## Deferred / Open Questions

### From 2026-09-10 review

- **Withhold only the underdog side, or the whole moneyline market, when the cap binds?** — Decisions, cap sub-decision (P1, product-lens + design-lens, confidence 75)

  On roughly one game in seven the cap removes a side, and the two branches give
  players materially different boards. Withholding only the dog leaves a live
  button on a heavy favorite — which can be a four-figure price once the clamp is
  involved, the case that makes the bet-button width question real at all — and
  produces an asymmetric row where one side is bettable and the other is blank.
  Withholding the whole market costs those games their moneyline entirely but
  keeps every rendered pair symmetric and every displayed price short. The claim
  that a one-sided market surrenders the book's edge does not hold: after
  normalization the favorite leg still carries roughly 3.7 points of edge over
  its true probability, so what is lost is balancing of action — variance, not
  expected value. An earlier draft of this plan recorded this as settled; only
  the three numeric decisions were.

- **Does a capped-out cell read as "no line" or as "closed"?** — Phase 6, board (P2, design-lens, confidence 75)

  Follows from the question above, and only arises on the withhold-the-dog
  branch. Today the empty treatment fires only when a market genuinely was not
  scraped, and it fires symmetrically on both sides — it is `aria-hidden` with a
  bare dash. A capped underdog reusing it means a deliberate risk decision is
  indistinguishable from a data gap, to sighted players and assistive technology
  alike, on a state players would hit regularly. The closed treatment already in
  the codebase says "there is a price here and you cannot bet it", which is what
  is actually true.
