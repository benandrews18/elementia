# Whole-game review (2026-11-27)

godot-prompter (code review, optimization, scene organization, audio-system)
and ponytail. Measured with `tests/tmp/bench.tscn` (desktop, late-run save)
and `tools/sim.py --runs 80 --seed 3`.

## Fixes

1. **A tap rebuilds whole screens.** Every `Game.state_changed` frees and
   rebuilds the open screen and panel. Desktop cost per tap: station 43 ms,
   Display Mat 30 ms, map 20 ms, Codex 20 ms (2,325 nodes). A phone is
   about 3-5x slower, so 100-200 ms. That spike lands on the first frames
   of the animation the tap starts (craft fly, card play), which is why
   motions can look like they stutter when they start.
   - Coalesce: `_redraw()` sets a dirty flag and rebuilds once at the end
     of the frame (`call_deferred`), never twice in a frame.
   - Saving is off the tap path: `Progress.save_all()` (6-12 ms) is
     deferred, at most one write per frame.
   - Restyle instead of rebuild for the commonest changes (pin and track
     toggles only recolour a badge).
2. **Juice hooks every Control ever made.** `node_added` puts a meta and a
   `gui_input` connection on every Control, about 1,000 per mat redraw.
   Instead, one `_input` finds the pressed control (`gui_get_hovered_control()`
   and walks up to the first pressable one). That single place is also
   where the tap sound goes.
3. **Endless pulse tweens** (the opening's Track glow, the clue wobble)
   keep the screen redrawing at 60 fps for as long as they run, which costs
   battery. Stop them after a few pulses, or pulse slowly.
4. **Per-frame polling.** `Tutorial._process` scans the App's children every
   frame, and `Hints._process` polls on a timer forever. They're cheap now,
   but they'd be better driven by signals (`state_changed`, panel opened).
5. **Private members used from outside:** `App.current._hub` (12 places),
   `_hand_mat`, `_panel_node`, `_market_playing`, `_go_map`. Make them
   public names or methods, so a rename can't silently break other files.
6. **Bench into the checks.** `tests/tmp/bench.gd` is git-ignored scratch.
   Make it `check.py perf`, which fails over a budget, so a slow redraw is
   caught like a golden.
7. **Docs.** PLAN.md is 1,809 lines and its "Where we are" still says step
   20. Trim it to the current state, the queue and the decisions; the
   history lives in git and the CHANGELOG.
8. Still open from earlier reviews:
   - bigger tap areas for small buttons (9);
   - the phone keyboard covers the Dev Panel's fields (M6-9);
   - a save version before any store build (5, M6-10);
   - re-measure the station and the mat on the phone (12, see 1).

Checked and fine:
- the Lock-In count can't be closed halfway (its blocker eats Back);
- the awaits re-check `is_instance_valid`;
- the shader materials are cached;
- tweens are killed before a new one starts (`Juice._tween`);
- `load()` of scenes is cached by Godot.

## Recommendations (professional polish)

- **Split the two big files by job.**
  - `display_mat.gd` (1,637 lines) becomes the mat grid, the combo chips,
    the Lock-In sequence, the hand play, the bench and the Inventory list.
  - `app.gd` (1,293 lines) becomes the screen and panel router, plus a
    CheckFlow node (travel → shutter → challenge → Lock In) and a
    MarketFlow node.
- **More layout in scenes, less in code.** For example, `display_mat.tscn`
  has only 5 nodes and the App has no scene. Fixed parts (bars, headers,
  buttons, fixed panels) go into `.tscn` files so they can be moved in the
  editor; code keeps only the lists.
- **A Theme resource.** `Tok.box(...)` styles built in code become a
  `theme.tres` with type variations (CardBox, GoldPill, ParchmentPanel).
  Colours and radii are then edited in one place, in the Inspector.
- **Folders by feature.** `ui/overlays/` holds 44 scripts, so group them as
  `ui/check/`, `ui/station/`, `ui/market/`, `ui/windows/` and so on. Move
  them in the Godot editor so the `.uid` references follow.
- **Comments say why, not when.** 186 comments carry "(the user, date)"
  history. That belongs in git; it makes the code harder to read for
  someone new.
- Fixed motions move to AnimationPlayer (M8, review 16) so they can be
  tuned in the editor.
- Sound (below), a loading or splash screen, profiling on the phone with
  Godot's remote profiler.
- A colour-blind check of the suit colours (the glyphs already help).

## Gameplay (from the sim)

- **Early checks are mostly luck.** At round 3 the simulated scores run from
  4 (p10) to 315 (p90), and at round 15 from 502 to 5,359. Smoothing ideas:
  - a guaranteed tier 1 card in the first hand;
  - a minimum first-check reward;
  - fewer, steadier dice early.
- **Late breakpoints vs a real player:** your two runs score well under the
  sim's median from round 18 on (round 24: 2,916 and 5,225 against the
  sim's 9,732). Only two runs, so this is a hint, not proof. Watch it as
  more runs come in (`sim_guide`).
- **Score size:** totals grow about 1,000x across a run. For kids,
  consider leading with the tier reached (bronze, silver, gold) and putting
  the raw number second.

## Mechanics for replayability

1. **Catalysts** (Balatro's jokers): pick 1 of 3 passive cards at some
   checks that bend a rule, e.g.:
   - "Noble-gas items score ×2";
   - "Converting costs 1 less";
   - "+1 discard".
   This is the biggest lever for runs that feel different.
2. **Daily seed:** everyone gets the same dice and shops that day, and
   testers compare scores. Cheap, since Rng is seeded already.
3. **Stakes:** after a win, unlock harder levels, each adding one rule
   (higher breakpoints, one less discard, pricier converts).
4. **Starting kits:** a few lab coats, each with a different start (a
   station, extra dice of one suit, a starting catalyst).
5. **Station events** (already planned after check orders): a small
   surprise at some visits (a sale, a double roll, a trader).
6. **Discovery meta:** a fact card the first time an element or item is
   made, filling a periodic-table album across runs. It fits the learning
   goal and gives long-term progress.

## Sound plan (next big task)

**Pattern** (audio-system skill):
- Buses: Master (HardLimiter) → SFX, UI, Music.
- One `Sfx` autoload with a pool of 8 `AudioStreamPlayer`s.
- `data/sounds.json` (editable): name → files (a few takes), volume, pitch
  range, cooldown.
- Rejected: an `AudioStreamPlayer` node in each scene. Sounds would be
  scattered across scenes, there would be no shared cooldown, and Settings
  would be harder.

**Triggers:**
- Game signals (`crafted`, `rolled`, played, locked in) and the Juice press
  hook, so screens hardly change.
- Per-sound cooldowns, so twelve bounces don't make twelve clicks.

**Feel:**
- Short (under 0.4 s, except celebrations), quiet (-14 to -18 dB), soft
  highs, at most about 3 at once.
- Each play gets a little random pitch (±4%), so no sound repeats exactly.
- Sequences climb a scale: the Lock-In beats rise a semitone each, like
  Balatro's chips.

**Settings:** Sound and Music switches (or sliders) in prefs.

**Web:** nothing plays before the first tap (the browser's audio unlock).

| Moment | Sound |
|---|---|
| Any button press | a soft wooden tick |
| Tray / window open, close | a paper whoosh; a soft pop in, quieter out |
| Dice roll | a rattle per die (staggered), a tick as each lands, a glassy blip on each reveal |
| Gather | a plink per element flying into the Inventory, rising; a thump on the bounce |
| Craft | a bench clink, small pops as elements are spent, a bright two-note chime (richer for higher tiers) |
| Pin / Track | a paper tap / a magnifier ting |
| Travel / arrive | a map slide and dust puff / a soft whoosh and a small bell |
| Card draw / play / discard | a card slide / a card set down / a flick |
| Lock-In beats | a chip clack rising a semitone a beat; a separate tone for × beats; a stamp on the total |
| Breakpoint passed / missed | a tiny fanfare / a soft low "womp" (never harsh) |
| Market square / row | a tick / a chord |
| Collection, capstone, Unknown | sparkle and chord; a mystery shimmer |
| Can't do that | a dull soft bonk |
| Professor Mouse speaks | a tiny chirp |
| Music (optional) | a gentle loop, low, ducked during Lock In |

**Open decisions:**
- Where the sounds come from:
  - CC0 packs (e.g. Kenney's Interface, Casino (cards, chips) and Impact
    packs), which need your OK to download;
  - sounds synthesized by a script (no downloads, but less organic);
  - a mix of the two.
- Music, or none for now.
