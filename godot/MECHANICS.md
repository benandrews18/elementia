# New mechanics: ideas (draft, 2026-11-27)

This draft is the input for queue step 6. godot-grill settles the open
decisions first; the outcome goes into PLAN.md's Decisions. The user's lead:
choosing between 2-4 options gives players a strong sense of control, even
when the choice is to take on more difficulty.

## Catalysts

A catalyst changes a reaction without being used up, which fits a
chemistry game. A catalyst is a run-long passive card. You hold up to 5;
when you're full, a new one replaces one you pick.

**Gathering (dice)**
- *Lodestone:* each roll's first die is always a Metal element.
- *Rain Barrel:* +1 die at the Ocean and the Greenhouse.
- *Lucky Pip:* once a visit, tap a die to roll it again.
- *Field Notes:* every station you visit for the first time rolls +2 dice.

**Converting and costs**
- *Philosopher's Stone:* Convert costs 2, not 3.
- *Isotope:* an Unknown Element counts as two of the element you pick.
- *Bunsen Burner:* the first craft each visit pays no suit cost.
- *Bulk Order:* a tier 1 craft makes two cards.

**The Display Mat (the Balatro core)**
- *Matched Set:* suit combos count as one card bigger.
- *Station Pride:* station combos give ×1.5 more.
- *Recipe Book:* a full recipe played together scores ×4, not ×3.
- *Collector:* each completed collection adds +2 mult.
- *Chain Reaction:* each play in a check adds +0.25 mult for the rest of
  the check.
- *Minimalist:* ×2 if the mat ends with an empty slot (a risk).
- *Noble Display:* Metal cards score +5 points each (one per suit:
  *Greenhouse Glass* for Organic, and so on).

**The hand**
- *Steady Hands:* +1 discard.
- *Deep Pockets:* hand size 8.
- *Free Sample:* the first element draw each check is free.

**Travel and the Market**
- *Express Pass:* one more visit before the next check.
- *Market Regular:* Market squares pay two "?".

**Volatile catalysts (strong, with a cost: from events or higher Stakes)**
- *Overclock:* +2 dice a roll, but suit costs +1.
- *Unstable Compound:* ×2 mult, but a random hand card is discarded after
  each play.
- *Glass Cannon:* +50% score, but one fewer card on the mat.

## When catalysts are awarded (proposal)

- **After every Lock In: pick 1 of N**, where N follows the tier you
  reached. Just through gives 2 choices; the best tier gives 4. A better
  check means more control, not just more points. You can always skip and
  take 1 "?" instead.
- **Crafting a capstone:** a pick of 3 from a "rare" set (stronger effects).
- **Station events** (below): sometimes a Volatile catalyst as one of the
  choices.

That's about 8 picks in a 24-turn run, so builds take shape by mid-run.

## Stakes (chosen at the start, each adds to the ones before)

Names to fit the lab theme: lab coats, or safety-goggle colours.

1. **White:** the game as it is.
2. **Red:** the first check pays no bonus dice.
3. **Green:** breakpoints rise faster (+15% a check).
4. **Black:** some catalysts on offer are Fixed: they can't be replaced.
5. **Blue:** one fewer discard.
6. **Purple:** breakpoints rise even faster.
7. **Orange:** some catalysts are Fragile: they break after 3 checks.
8. **Gold:** Convert costs 4, and some catalysts cost an element each
   check to keep.

Winning on a Stake unlocks the next one. The best Stake won shows on the
title screen and in History.

## Mission mode

- A mission is a fixed seed (the same dice and shops for everyone) plus 3-5
  target items, often including post-capstone ones.
- The goal is to make them all in as few turns as possible. Stars are given
  by turns used (for example 3 stars at 18 turns or fewer). Checks still
  happen, so a weak mat can still end the run.
- Missions are hand-made, a handful to start (one per capstone path), each
  with a short brief from Professor Mouse. Later, perhaps a weekly mission
  from a date seed.

## Station events

- Arriving at a station sometimes (around 1 visit in 4, never during the
  tutorial) opens an event card with 2-3 choices. Some examples:
  - **Traveling Merchant:** trade 3 elements for a catalyst pick, or walk
    on.
  - **High Tide (the Ocean):** lose 2 elements, or skip this roll for an
    Unknown Element.
  - **Lab Accident:** take a Volatile catalyst, or clean up (lose a turn's
    roll).
  - **Festival:** this roll doubles, but the next trip costs an extra turn.
  - **Power Cut (the Power Plant):** Reactive crafts cost +1 until you
    leave, or pay 1 Metal to fix it.
- Events bend the run without ending it. Each has a "safe" choice.

## Notes for building

- The rules go in `core/` (a `Catalysts` table in game_data.json, with code
  only where an effect needs it). Recorded runs hold no catalysts, so the
  rules lock stays as it is until catalysts are switched on.
- The simulator (`tests/sim.gd`) needs a simple picking policy, so the
  breakpoints can be tuned again with catalysts in play.
- Old saves load with no catalysts and the White Stake.
