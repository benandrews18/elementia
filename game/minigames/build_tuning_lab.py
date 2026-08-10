"""Build game/minigames/tuning_lab.html from the live mini-game sources.

The tuning lab is the working surface for these games: it embeds each
`.js` file verbatim, patches the `const` tunables at run time, and plays
the result. That means the lab must be REBUILT after any edit to a
mini-game, or it silently keeps testing yesterday's code:

    python game/minigames/build_tuning_lab.py

Slider defaults are read out of the sources here rather than duplicated in
the template, so a retuned constant shows up in the lab automatically. The
range/label metadata below is the only hand-maintained part; if a name in
it stops existing in its source file the build fails loudly rather than
quietly dropping the knob.

Station backdrops and the Deep Mine sprite strip are inlined as data URIs
so the published lab is fully self-contained (Artifacts can't fetch files).
"""
import base64, hashlib, json, mimetypes, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
BACKDROPS = HERE.parent / "backdrops"
TEMPLATE = HERE / "tuning_lab_template.html"
OUT = HERE / "tuning_lab.html"

# key -> (source file, title, emoji, accent, backdrop asset, [tunables])
# Each tunable: (CONST_NAME, label, unit, min, max, step[, negate])
GAMES = [
    ("ocean", "ocean-bubbles.js", "Ocean: Bubble Pop", "🌊", "#57b3e0", "ocean.webp", [
        ("DURATION_MS", "Round length", "ms", 6000, 40000, 500),
        ("SPAWN_MIN_MS", "Min spawn gap", "ms", 60, 1000, 20),
        ("SPAWN_MAX_MS", "Max spawn gap", "ms", 200, 1500, 20),
        ("SIZE_MIN_PX", "Min bubble size", "px", 16, 140, 2),
        ("SIZE_MAX_PX", "Max bubble size", "px", 30, 200, 2),
        ("RISE_MIN_MS", "Fastest rise time", "ms", 500, 6000, 100),
        ("RISE_MAX_MS", "Slowest rise time", "ms", 1200, 9000, 100),
        ("TARGET_POPS", "Pops for max score", "", 4, 80, 1),
        ("SPREAD_CANDIDATES", "Spawn spread tries", "", 1, 20, 1),
        ("SPREAD_RECENT_MS", "Spread memory", "ms", 0, 3000, 50),
    ]),
    ("forest", "old-growth-forest.js", "Old Growth Forest: Plant Trees", "🌲", "#7be495", "old-growth-forest.webp", [
        ("DURATION_MS", "Round length", "ms", 8000, 40000, 1000),
        ("TARGET_TREES", "Trees for max score", "", 1, 10, 1),
        ("SWEEP_MS_START", "Arm cycle, tree #1", "ms", 500, 4000, 50),
        ("SWEEP_MS_MIN", "Arm cycle floor", "ms", 300, 3000, 50),
        ("SWEEP_MS_STEP", "Cycle lost per tree", "ms", 0, 400, 10),
        ("GREEN_HALF_DEG_START", "Green zone, tree #1", "deg", 5, 45, 1),
        ("GREEN_HALF_DEG_MIN", "Green zone floor", "deg", 2, 30, 1),
        ("GREEN_HALF_DEG_STEP", "Zone lost per tree", "deg", 0, 10, 1),
    ]),
    ("city", "the-city.js", "The City: Stack the Stones", "🏗️", "#b3a897", "quarry.webp", [
        ("DURATION_MS", "Round length", "ms", 10000, 70000, 1000),
        ("TARGET_STONES", "Stones for max score", "", 3, 20, 1),
        ("STONE_H", "Stone row height", "px", 16, 120, 2),
        ("START_WIDTH_FRAC", "First stone width", "× stage", 0.2, 0.95, 0.05),
        ("MIN_WIDTH_PX", "Min stone width", "px", 4, 80, 2),
        ("SLIDE_MS_START", "Slide cycle, stone #1", "ms", 500, 5000, 50),
        ("SLIDE_MS_MIN", "Slide cycle floor", "ms", 300, 3000, 50),
        ("SLIDE_MS_STEP", "Cycle lost per stone", "ms", 0, 400, 10),
        ("MISS_FALL_MS", "Miss tumble time", "ms", 200, 1500, 50),
        ("BASE_TOP", "Base stone height", "px", 120, 600, 10),
    ]),
    ("observatory", "observatory.js", "Observatory: Fly the Rocket", "🔭", "#8b6fe0", "observatory.webp", [
        ("DURATION_MS", "Round cap", "ms", 5000, 60000, 500),
        ("TARGET_SURVIVE_MS", "Survive time for max score", "ms", 5000, 50000, 1000),
        ("THRUST_ACCEL", "Thrust strength", "px/s²", 200, 3000, 50),
        ("DRIFT_DECEL", "Coast-down force", "px/s²", 0, 2000, 50),
        ("MAX_VX", "Terminal speed", "px/s", 150, 2000, 20),
        ("ROCKET_SIZE", "Rocket size", "px", 12, 70, 2),
        ("ROCKET_BOTTOM", "Rocket height above floor", "px", 40, 260, 4),
        ("OOB_SLACK", "Off-edge allowance", "× rocket", 0, 0.95, 0.05),
        ("ROCK_SPAWN_MS_START", "Asteroid gap, start", "ms", 300, 3000, 50),
        ("ROCK_SPAWN_MS_MIN", "Asteroid gap floor", "ms", 150, 2000, 50),
        ("ROCK_SPEED_START", "Asteroid speed, start", "px/s", 50, 700, 10),
        ("ROCK_SPEED_MAX", "Asteroid speed cap", "px/s", 100, 900, 10),
        ("ROCK_RAMP_MS", "Time to max difficulty", "ms", 500, 40000, 500),
        ("ROCK_R_MIN", "Min asteroid radius", "px", 5, 90, 1),
        ("ROCK_R_MAX", "Max asteroid radius", "px", 10, 140, 1),
        ("BODY_SPAWN_MS", "Scenery spawn gap", "ms", 500, 8000, 100),
    ]),
    ("greenhouse", "greenhouse.js", "Greenhouse: Catch the Eggs", "🌱", "#8fc47f", "greenhouse.webp", [
        ("DURATION_MS", "Round length", "ms", 8000, 40000, 1000),
        ("TARGET_GOOD", "Good eggs for max score", "", 4, 30, 1),
        ("BAD_PENALTY", "Penalty per bad egg", "", 0, 8, 1),
        ("BASKET_W_FRAC", "Basket width", "x stage width", 0.1, 0.6, 0.01),
        ("BASKET_ASPECT", "Basket height", "x basket width", 0.5, 4, 0.1),
        ("BASKET_BOTTOM_GAP", "Basket gap from floor", "px", 0, 80, 2),
        ("EGG_W", "Egg width", "px", 10, 70, 2),
        ("EGG_H", "Egg height", "px", 10, 90, 2),
        ("CATCH_BAND", "Catch tolerance", "px", 2, 40, 2),
        ("FALL_MS_RAMP", "Time to max fall speed", "ms", 3000, 40000, 1000),
        ("FALL_SPEED_START", "Fall speed, start", "px/s", 30, 300, 10),
        ("FALL_SPEED_MAX", "Fall speed cap", "px/s", 60, 600, 10),
        ("SPAWN_MS_START", "Spawn gap, start", "ms", 200, 2500, 50),
        ("SPAWN_MS_MIN", "Spawn gap floor", "ms", 100, 1500, 50),
        ("BAD_CHANCE_START", "Bad-egg chance, start", "", 0, 0.8, 0.02),
        ("BAD_CHANCE_MAX", "Bad-egg chance cap", "", 0, 0.9, 0.02),
    ]),
    ("powerplant", "power-plant.js", "Power Plant: Untangle the Wires", "⚡", "#e8d24c", "power-plant.webp", [
        ("DURATION_MS", "Round length", "ms", 10000, 90000, 1000),
        ("TARGET_SOLVES", "Solves for max score", "", 1, 12, 1),
        ("START_WIRES", "Starting wire count", "", 2, 7, 1),
        ("MAX_WIRES", "Max wire count", "", 2, 9, 1),
        ("MARGIN", "Edge inset", "px", 10, 80, 2),
        ("HANDLE_R", "Handle size", "px", 4, 40, 1),
        ("HIT_R", "Tap target size", "px", 8, 70, 1),
    ]),
    ("deepmine", "deep-mine.js", "Deep Mine: Break the Rocks", "💎", "#c9b896", "deep-mine.webp", [
        ("DURATION_MS", "Round length", "ms", 5000, 45000, 1000),
        ("TARGET_ROCKS", "Rocks for max score", "", 2, 15, 1),
        ("HITS_START", "Taps needed, rock #1", "", 1, 25, 1),
        ("HITS_STEP", "Extra taps per rock", "", 0, 8, 1),
        ("HITS_MAX", "Taps-needed ceiling", "", 2, 40, 1),
        ("DECAY_PER_SEC", "Progress decay", "/s", 0, 10, 0.2),
        ("SHATTER_MS", "Explosion length", "ms", 200, 2000, 20),
        ("GEMS_PER_ROCK", "Diamonds per rock", "", 0, 15, 1),
    ]),
    ("bakery", "bakery.js", "Bakery: Fill the Order", "🍰", "#f0dcae", "bakery.webp", [
        ("DURATION_MS", "Round length", "ms", 10000, 60000, 1000),
        ("TARGET_CAKES", "Cakes for max score", "", 2, 15, 1),
        ("SEND_ANIM_MS", "Conveyor travel time", "ms", 200, 2500, 50),
        ("ORDER_QUEUE", "Order cards shown", "", 1, 5, 1),
    ]),
]

# Every game also carries these, but they're the same knob everywhere and
# would just pad each panel -- the lab has its own score->dice mapper.
SKIP_CONSTS = {"DICE_MIN", "DICE_MAX", "BACKDROP", "RESULT_HOLD_MS", "SPRITE",
               "FRAMES", "BREAK_FRAMES", "BOOM_FIRST", "BOOM_LAST",
               "GEM_BURST_MS", "GEM_FLY_MS"}

CONST_RE = re.compile(r"^\s*const\s+([A-Z][A-Z0-9_]*)\s*=\s*(-?[\d.]+)\s*;", re.M)


def constants_in(src):
    return {m.group(1): float(m.group(2)) for m in CONST_RE.finditer(src)}


def data_uri(path):
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def main():
    template = TEMPLATE.read_text(encoding="utf-8")
    sources, games, assets = {}, [], {}
    problems = []

    for key, fname, title, emoji, color, backdrop, tunables in GAMES:
        path = HERE / fname
        if not path.exists():
            problems.append(f"{key}: missing source {fname}")
            continue
        raw = path.read_bytes()
        sources[key] = base64.b64encode(raw).decode("ascii")
        consts = constants_in(raw.decode("utf-8"))

        knobs = []
        for name, label, unit, lo, hi, step in tunables:
            if name not in consts:
                problems.append(f"{key}: tunable {name} is not a top-level const in {fname}")
                continue
            val = consts[name]
            knobs.append({"name": name, "label": label, "unit": unit,
                          "def": int(val) if val == int(val) else val,
                          "min": lo, "max": hi, "step": step})
        # Flag anything tunable-looking in the source that no knob exposes.
        listed = {t[0] for t in tunables}
        for name in consts:
            if name not in listed and name not in SKIP_CONSTS:
                print(f"  note: {key} has un-exposed const {name} = {consts[name]:g}")

        games.append({"key": key, "title": title, "emoji": emoji, "color": color,
                      "tunables": knobs})

        bd = BACKDROPS / backdrop
        if bd.exists():
            assets[backdrop] = data_uri(bd)
        else:
            problems.append(f"{key}: missing backdrop {backdrop}")

    sprite = HERE / "deep-mine-rock.webp"
    if sprite.exists():
        assets[sprite.name] = data_uri(sprite)
    else:
        problems.append("deep-mine: missing deep-mine-rock.webp")

    if problems:
        print("BUILD FAILED:", file=sys.stderr)
        for p in problems:
            print("  - " + p, file=sys.stderr)
        return 1

    # Fingerprints the defaults only, so a rebuild that changed nothing
    # tunable leaves the user's slider positions alone.
    stamp = hashlib.sha1(json.dumps(games, sort_keys=True).encode()).hexdigest()[:12]

    out = template.replace("__BUILD_STAMP__", stamp)
    for token, payload in (("__MINIGAME_SOURCES_JSON__", sources),
                           ("__GAMES_JSON__", games),
                           ("__MINIGAME_ASSETS_JSON__", assets)):
        if token not in out:
            print(f"BUILD FAILED: template is missing {token}", file=sys.stderr)
            return 1
        out = out.replace(token, json.dumps(payload, ensure_ascii=False))

    OUT.write_text(out, encoding="utf-8")
    kb = OUT.stat().st_size // 1024
    print(f"wrote {OUT.name}: {kb} KB, {len(games)} games, "
          f"{sum(len(g['tunables']) for g in games)} knobs, {len(assets)} inlined assets")
    return 0


if __name__ == "__main__":
    sys.exit(main())
