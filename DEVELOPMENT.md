# Schmoovin Man: developer notes

How the addon is built, what was checked, and why things are the way they are. The player-facing overview is [README.md](README.md); version history is [CHANGELOG.md](CHANGELOG.md).

**Status:** version 0.13.0 (2026-11-18): a top speed of 48 yd/s and harder late zones (twelve new layouts, easy ones turning rare, lone obstacles in the gaps from zone 8), a Thousand Needles crosswind that carries you a lane over in the air, a skid on Winterspring's ice, and the Wind Rider flying right under you (see [CHANGELOG.md](CHANGELOG.md)). 0.12.2 (2026-11-13) released what was meant to be 0.12.1: Horde leaders in place of bosses, the visible crosswind, pits that differ by zone, the combo timer, Wind Rider seating and chargers centred by their running box (see [CHANGELOG.md](CHANGELOG.md)). 0.12.0 (2026-11-12) added combos, pits with ramps, and a twist for every zone but Mulgore (see [CHANGELOG.md](CHANGELOG.md)). 0.11.1 (2026-11-11) added hazard markers, chargers and bosses centred on their lane, and nine fixes from a review of the whole addon (see [CHANGELOG.md](CHANGELOG.md)). 0.11.0 (2026-11-09) added the Options screen, starting speeds with a score multiplier, per-zone model picks and the resume countdown. 0.10.0 (2026-11-08) added bosses, the fight camera and the HUD layout that keeps the road clear.

- **Release:** 0.13.0 is tagged `v0.13.0` (2026-11-18); GitHub Actions releases a `v*` tag to GitHub releases and CurseForge once its tests pass. 0.12.2 was released on 2026-11-13 (tag `v0.12.2` on commit `153650d`), to GitHub releases and CurseForge. It holds the changes first tagged as `v0.12.1` (on commit `da31db1`), plus a steadier test. GitHub Actions failed one check on `v0.12.1` with 15 s zones, so its release job never ran and nothing reached GitHub releases or CurseForge. That check ("Un'Goro has more power-ups") compared power-ups from a single run and came out 2 against 2 under Lua 5.1; it now counts over five seeds. The `v0.12.1` tag was left where it is rather than moved, so there is no 0.12.1 release; don't reuse that version.
- **Tests:** all pass on 0.13.0 locally (801 of 801 and 789 of 789 with CI's two settings, and the whole-addon test). Earlier, in GitHub Actions, the `v0.12.1` tag failed the check above, and `main` passed once it was fixed (commit `2ab942b`). See [Test results](#test-results).
- **In game:** none of 0.13.0 has been seen in game yet: the crosswind that carries you a lane over in the air (asked for on 2026-11-15), the Wind Rider seat and flight camera (raised again on 2026-11-15 from the author's screenshot), the Winterspring skid and its drawing, the 48 yd/s top speed, the new layouts and lone obstacles, and bosses standing further off at high speed. In 0.12.2, the leaders, zone pits, combo timer, Wind Rider seating and charger centring were built against the author's reports from play (2026-11-12); its crosswind streaks and gauge, and the fixes from that review, haven't been seen in game either. The Barrens thunder lizard (display 1532) still runs about 1.3 yards off its lane; the next step is a `/schmoove measure` taken with it in a side lane, which shows whether the game applies its scale to its position. 0.12.0 has been played by the author, who found the combos, pits, ramps and zone twists working well (confirmed 2026-11-12). 0.11.1 was played before it, with the hazard markers and the charger centring checked (confirmed 2026-11-11). The released 0.11.0 was played and checked before it (confirmed 2026-11-10), including the Options screen, model picks, resume countdown, starting speeds, the ducking pose, hazard sizes, saved scores and the guild board.
- **Still true from earlier versions:** `IsGeoReady` is only waited on for 1 second when it explicitly returns false. In Forever it never turns true for props loaded by file ID, and waiting on it in 0.7.1 hid them. Characters are measured by their active box with scale kept between 0.5 and 2.0, after a tester saw a tiny runner.

## Running the tests

The game logic is plain Lua 5.1 with no WoW API, so it runs outside the game. From the repository root:

```bash
lua tests/schmoovin_spec.lua . 20 10
```

Arguments: addon folder, seeds, minutes per run, and optionally seconds per zone (for example `15` for the hardest setting). The smoke test loads every file in TOC order against stub WoW functions and plays a run:

```bash
lua tests/schmoovin_smoke.lua . "$(grep -E '\.lua' SchmoovinMan.toc | tr -d '\r' | paste -sd,)"
```

GitHub Actions runs both (short versions) on every push and before every release, on Lua 5.1.5: `.github/workflows/release.yml` runs the logic tests at 25 s zones, again at 15 s zones (`. 4 5 15`), then the smoke test. A tag only packages if all three pass.

Without a local Lua, the tests run under fengari (Lua 5.3 in JavaScript). Two things differ from CI:
- 5.3-only calls (such as two-argument `math.atan`) pass locally and fail in CI. Use `math.atan2`, which the smoke test shims.
- Numbers from the random generator can come out differently, so a seeded run that passes locally can meet different spawns in CI. A check that compares counts from bot runs should add them up over several seeds, not rely on one run (the Un'Goro power-up check failed this way on the `v0.12.1` tag).

## Releasing

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) (v2.7.0 or later) from `.github/workflows/release.yml`:
- Push a tag such as `v0.7.0`. The workflow runs the tests, then packages the addon.
- `.pkgmeta` leaves out the tests and developer docs.
- `@project-version@` in the TOC becomes the tag.
- Interface `16001` is detected as Forever, and the file is uploaded to CurseForge under game type 88568. WoWInterface has no Forever category, so that upload is skipped.

Uploads need:
- The CurseForge project ID in the TOC as `## X-Curse-Project-ID`.
- A CurseForge API token in the repository secret `CF_API_KEY`.

Without a token, the workflow skips CurseForge and still attaches the zip to the GitHub release. A token that's set but rejected is different: the packager stops with "Error fetching game version info" and nothing is released, not even to GitHub (this happened with the first token on 2026-11-08). Make a new token at authors.curseforge.com (API tokens), put it in the secret, then rerun the failed job on the same tag.

## Hazard rules

- A hazard may cover several lanes. Same-kind hazards side by side in one row are drawn as one barrier: each piece widens to fill its lane so they meet, and a high bar across several lanes has posts only at its outer ends.
- A single-lane hazard stays narrow, so the lanes beside it read as open.
- Every row leaves a free lane or a jump/duck route. The fairness tests check this for every pattern and for 10-minute spawn runs, with ducking on and off.

Sizes for a single-lane hazard:

| Hazard | Height | Width | Depth |
|---|---|---|---|
| Low | 0.9 | 1.5 | 1.6 |
| High bar | 0.7, 1.7 up | 1.8 | 1.0 |
| Block | 2.0 | 1.5 | 1.8 |
| Wall | 2.2 | 1.8 | 1.6 |
| Charger | 2.3 | at most 2.0 | |

All sizes are in yards; a lane is 2.6 wide. Hit boxes are unchanged. Sizes are the `TARGET` table at the top of `Render/Renderer.lua`. Checked in game on 0.11.0 (confirmed 2026-11-10).

## Target

| | |
|---|---|
| Client | Forever only |
| Build checked against | 1.60.1.70790, interface 16001 (matches the installed client's `.build.info`) |
| Blizzard UI source | `Gethe/wow-ui-source` branch `forever` at `eac30af597e5aaa43a60f6675ef5fdcea100375f` |
| Installed to | `World of Warcraft\_forever_\Interface\AddOns\SchmoovinMan` |

Every WoW method the addon calls was checked against the generated API docs at that commit. Those declarations don't prove how the game behaves.

## Commands

| Command | What it does |
|---|---|
| `/schmoove` or `/schmoovin` | Opens or closes the game |
| `/schmoove start` | Opens the game straight into a run, or brings back a paused one |
| `/schmoove sound` | Turns sound on or off |
| `/schmoove markers` | Turns hazard markers on or off (also in Options). Off by default |
| `/schmoove duck` | Turns ducking on or off. Off swaps every high bar for a block, so runs stay fair |
| `/schmoove zones 15`, `25`, `35` or `45` | Seconds per zone; the start screen's Zones button cycles the same choices |
| `/schmoove speed 8`, `11` or `14` | Starting speed (Slow, Normal, Fast); the start screen's Start button cycles the same choices |
| `/schmoove options` | Opens Options (also on the start and pause screens and in the minimap menu) |

Left out of the help, for development: `/schmoove measure` lists the chargers and boss on screen with their box measurements, where the game says each was placed, and which model a boss that isn't showing is waiting for; `/schmoove measure all` loads and checks every zone's charger models (see [Test results](#test-results)); `/schmoove flight` lists how the runner sits on the wind rider and how the flight camera looks, with the wyvern's box height and scale once one has flown that session, and `/schmoove flight lift 2.5` (or `seat`, `back`, `look`, `tilt` in degrees) changes one until a reload.

The minimap button (kodo icon) also opens or closes the game. Drag it to move it.

The S, M, L and XL buttons in the title bar set the window to 75%, 100%, 130% or 160% of 960 x 600. Your choice is remembered, and the window never grows past your screen.

## Controls

| Action | Keys |
|---|---|
| Change lane | A / D, Left / Right |
| Jump | W, Up, Space |
| Duck under high bars | S, Down. Pressed in the air, you drop fast and duck on landing |
| Pause | Esc or P, or the Pause button at the left of the title bar (greyed out outside a run and once the runner has crashed, "Resume" while paused). While paused, P resumes and Esc closes the window |
| Start or restart | Enter or R (Space also starts from the start screen) |

Only these keys are kept from the rest of WoW while a run is live; anything else (chat, screenshots) still works. You can't start a run in combat, and entering combat pauses the run. Closing the window pauses it too.

## How a run works

| | |
|---|---|
| Zones | Mulgore first, then the other 15 in a random order, with no repeats until all have been seen: The Barrens, Thousand Needles, Ashenvale, Burning Steppes, Silithus, Un'Goro Crater, Winterspring, Westfall, Moonglade, Stormwind City, Darnassus, Ironforge, Thunder Bluff, Orgrimmar and Undercity. The cities use Classic tilesets and racial props; city chargers are guards (Stormwind, Ironforge) or local beasts |
| Zone length | 25 seconds by default (Normal). Frantic 15, Relaxed 35 and Marathon 45 are on the start screen. Each zone is one difficulty step, so shorter zones bring speed-ups and new obstacles sooner. Time spent fighting a boss doesn't count toward a zone. Saved scores record the zone length used |
| Speed | Starts at 11 yd/s (or 8 or 14, see Options), rises 0.03 yd/s every second, and jumps 2.2 yd/s on entering each zone, up to 48 yd/s (`Tuning.maxSpeed`; 38 until 2026-11-17). With 25 s zones and the Normal start that's reached on entering zone 14, where 38 was reached in zone 10. A slow start multiplies the final score by 0.75 and a fast one by 1.25 (`Tuning.startSpeeds`); saved runs record their starting speed |
| Obstacles | Low (jump), high bar on two posts (duck, from zone 2), block, two-lane wall (from zone 2), charging creature (from zone 3), combos from zone 4, harder layouts from zone 6 to 12 (see Late zones) |
| Late zones | Rows and gaps stop shrinking in zone 9 (`tempoMin` 0.62, `gapMin` 0.8 s), and they can't shrink further: at that tempo the `gauntlet` layout's jumps are 0.775 s apart against the fairness check's 0.75, and a gap has to leave 0.75 s between a jump at the end of one chunk and one at the start of the next. So what gets harder after that is (1) the speed, until zone 14; (2) twelve layouts that unlock two a zone in zones 6 to 10 and two more in zone 12, with rows close to the fairness limits at the tightest tempo: `staircase`, `pillars` (6), `chargerWave`, `duckWeave` (7), `wallWeave`, `funnel` (8), `hopSkip`, `stepsAcross` (9), `crossJump`, `upDown` (10), `onslaught`, `gateRun` (12). Four need ducking; with ducking off there's still one new in each of those zones. Coins lie in the open lane of the weaves, to show the way; (3) easy layouts turning rare: a pattern with `rareFrom` is a third as likely (`Patterns.RARE`) from that zone, which is zone 7 for five zone-1 layouts and zone 9 for five from zone 2, so about 41% of picks in zone 6 are easy ones and about 13% in zone 14. The power-up layout never turns rare; (4) stragglers (`Tuning.straggler`, `World:SpawnStraggler`): from zone 8 the gap after a chunk sometimes holds one more obstacle on its own, to jump, duck or step round, 20% of the time in zone 8 and 5% more each zone up to 50%. It stands half a gap after the chunk (0.4 s or more, against 0.29 s to step out of its lane) and 0.4 s of clear road is added after it (so 0.8 s to the next chunk: time to cross the road, or to land from a jump over it and jump again); both stretch with a zone's `spacing`. There's none after a pit, in a crosswind (a jump just blown may still be over the lane it left), in a boss fight, or where a vent or a leader's gift has the spot. An Alliance jogger can still come in the same gap, in another lane (`World:SpawnAlliance` keeps out of any lane with something solid on the stretch they jog over). After the tightest layouts there's often no such lane, so a jogger that finds none waits for the next gap (`World.allianceWaiting`) and they come about as often as before. Boss fights: fifteen layouts, five of them older (`gauntlet`, `logJump`, `limbo`, `underpass`, `hurdles`), leave no spot for a spear at the tightest spacing (`World:SpearRoom`). Once a throw has placed fewer spears than its share (`spearPlan.behind`), the boss throws only layouts that leave one until the fight's spears are all out, so a late fight still offers enough to drive it off. In `duckWeave` the bars are 0.31 to 0.35 s apart in different lanes, so a duck pressed early for the first may end as the second arrives: pressing duck again restarts it (`Runner:Input`), and the test bot now does that too. Past 38 yd/s a boss stands further off and a sandstorm gust pulls the fog in less (see Bosses and Zone twists), so neither gives less warning than it did at the old top speed. The fog itself is no further off, so at 48 yd/s you see 1.5 to 1.8 s of road ahead, where at 38 it was 1.8 to 2.2 |
| Tokens | Gold coins 10 points, gems 50. Lines, jump arcs and sky lines while flying |
| Time points | 10 per second, plus 2 per second for each zone reached |
| Move points | +2 per low obstacle jumped and +3 per high bar ducked, when it's in your path and you make the move. Flying, Stampede smashes, shield hits and invulnerable pass-throughs don't count. +5 per Alliance jogger knocked over |
| Combos | A clean move (a jump or duck that scores, a ramp taken, or an Alliance knock) adds to the combo. The first 5 pay as usual, the next 5 x1.5, and so on up to x3, rounded (`Rules.ComboMultiplier`, `Tuning.combo`). Thick Hide breaking ends it. After 5 seconds without a move it runs down by 2 every 2 seconds; a bar under it on the score panel shows the time left (`World:ComboLeft`). Only time with something ahead to jump, duck, ride or knock counts: not a Wind Rider flight, nor the clear road before a boss or at a zone change. Tokens, time and boss points are untouched, so scores stay comparable with older ones |
| Pits | From zone 2 (`pit = { fewest, most }` tiles on a pattern, whose one row is ramps `R` and edges `X`). A pit runs right across the road, 2 or 3 tiles of 8 yards. A lane with a ramp throws you over on contact, with no key press, in an arc 2.6 yards high that ends 0.15 s past the far edge (`World:CheckRamp`, `Runner:Launch`); lanes can still be changed in the air, and a jump already under way becomes the throw. It pays +5 and counts as a clean move. A lane with no ramp has the pit's edge (role `pitedge`), which is what you fall in at; the fairness check treats it as a block. Thick Hide or Stampede carries you across. Air coins lie along each ramp's flight. Drawn by hand in perspective, with no models (`Renderer:AddPit`, `AddRamp`, quads through `Ground:Quad`): a pale rim, then as much of the hole's inside as shows past its near edge from the camera (far wall, sides and a floor 2.2 yards down). What's down it depends on the zone (`zone.pit` in Data/Zones.lua: fire, water, ice, tar, slime, a silithid burrow or a chasm): a colour, the zone's ground texture over it and the far wall, and bands of a brighter colour streaming across; game over names it, and each ramp as a wooden slope 2.6 yards long rising 1.3 to the pit's edge, with green arrows running up it. Ramps are drawn after every pit, as they stand up over its edge. A boss never throws one, and no Alliance jogger follows one |
| Zone twists | One special rule in some zones (`Tuning.twists`, `World:Twist`), named on the zone banner. **Winterspring**, ice: lane changes take 0.2 s, not 0.14, and rows and gaps are 1.25 times as far apart, which is the same proportion the fairness check's allowance for a lane change grows by, so whatever can be passed elsewhere can be passed there. Arriving in a lane on the ground, the runner skids 0.7 yards past its middle (`skid`), slowing from the speed it came in at, and comes back over 0.4 s (`skidBack`; `Rules.Skid`, `Runner.slide`). A lane change that ends in the air doesn't skid, and one that ran less than a lane before it arrived (turned back partway) skids that much less. The skid is shorter than a pick-up's reach (1 yard) and stops short of anything in the next lane (the nearest is a ramp, 1.1 yards off), and a new lane change takes what's left of it off as fast as the change goes, so with the same keys nothing is hit or picked up that wouldn't be without it: it changes how a lane change looks and feels, and the fairness check needs nothing new. Drawn by `Renderer:AddIce`, before anything else on the road, so pits, hazard markers and landing marks lie over it: pale glints fixed to the road, some sparkling, left out where they'd lie across a pit; two scraped lines left where the runner slides; and a spray of ice on the side it's sliding to, as strong as the runner's sideways speed. That speed is `Runner.vx`, worked out in the game's own steps; the runner's lean goes by it too, so both look the same at any frame rate. **Burning Steppes**, lava vents: 45% of the time a vent stands in the gap after a chunk, in any lane, with 0.8 s of extra clear road after it, so there's time to step out of its lane before and to reach any lane after. **Silithus**, sandstorm: every 11 s a 5 s gust pulls the fog in by 40% of its range and hazes the view; drawing only, and it dies down for a boss fight. It never leaves less than 1.15 s of road in sight (`gustSee`), which only matters past 39 yd/s: at 48 the fog comes in 20 yards, not 30. **Thousand Needles**, crosswind: it turns round every 4 s (`blowEvery`), and in the air (a jump, a ramp's throw, the drop after a Wind Rider, but not on one) it carries you one lane over, the way it blew when you left the ground (`Runner.blow`). The push follows `Rules.Blown`: by the square of the time, a whole lane over an ordinary jump's 0.7 s, so at the top of a jump you're a quarter of a lane across and still over what you jumped; it stops at the road's edge. Coming down more than half a lane across puts you in the next lane, less brings you back (a jump cut short by ducking). Lane changes still work in the air, on top of it. To keep it fair, the fairness check takes a `wind` on each thing to jump: the jump only counts as a way through if the lane it's blown to holds nothing at that row but something else to jump, and it lands there (`at` is the lane to be in for the row, `lane` the one landed in); steering against the wind isn't counted on. For 0.5 s after that row (`LIMITS.blowClear`) the jump may still be over the lane it left, so a row in that time can't be passed if that lane holds a block, wall or bar; no pattern has rows that close today, so this only guards new ones. Chunks there (and the boss's throws) are picked with `World:PickForWind`: the pick, its mirror image, either up to 0.7 s later, or another pick, until `World:WindFits` passes; a pattern with nothing but tokens if nothing does. A boss's throw is only put off if it still ends before the boss gives up. `WindFits` also keeps anything to jump, and any ramp, from arriving in the first 0.65 s after a turn (`blowQuiet`): a jump can leave the ground up to 0.56 s before what it clears, and a ramp throws you as it's first touched, so every jump and throw takes off in the wind it was laid for. A ramp's air coins lie along the blown flight, measured from when the ramp is first touched. It's shown by 14 streaks blowing across and over the road (`Renderer:AddWind`, quads with no model, thinning out around each turn) and a gauge under the tokens with its direction and the time to the next turn (`World:Wind`). **The Barrens**, stampede country: patterns with a charger weigh 3 times as much and start a zone sooner, and `chargerPair` (two abreast, `twist = "chargers"` on the pattern) is only used there. **Ashenvale**, wisps: after each chunk `World:SpawnWisps` asks the fairness check for a way through and lays wisps along it, one 0.3 s before each row in the lane to be in and one at the row where that spot is free (role `wisp`, a token worth 1, drawn as a light with no model). **Un'Goro**, crystal pylons: the power-up pattern weighs 3 times as much and power-ups may come 6 s apart, not 12. **Westfall**, Defias loot: token-only patterns weigh 2.5 times as much and 8% of ground coins are gems. **Moonglade**, moonlight: gravity 22 and jump speed 9.9 (a 0.9 s jump, not 0.7), with rows and gaps 1.3 times as far apart, so two jumps the fairness check allows 0.75 s apart are at least 0.95 s apart there. **Stormwind**, crowded streets: an Alliance jogger follows 90% of chunks, not 35%. **Darnassus**, moonwell: Thick Hide on entering, if you have none. **Ironforge**, steam vents: the lava-vent rule, drawn as a grate and a plume with no model. **Leaders in place of a boss** (Thunder Bluff, Orgrimmar, Undercity; not a twist): Cairne, Thrall or Sylvanas (the famous joggers' models) runs 24 yards ahead beside the road. From 2.5 s after they turn up, about every 6 s, in the gap after a chunk, a gift is thrown to land in a random lane with 1 s of extra clear road after it (`World:SpawnGift`): their power-up (Stampede, Gold Rush, Thick Hide) and a line of 4 coins take turns. A gift is a `thrown` entity like a boss's hazard, launched from no further than the leader (`throwMax`), with a green landing mark, and can be taken once it has landed. While a leader runs, `world.escort` counts gifts thrown (when a gift's first piece leaves the hand) and caught (once per gift, a line of coins included); the HUD shows a green bar in the boss bar's slot with those counts and the time until the zone ends (`World:EscortLeft`), and the leader shouts lines from `Assets.quips.escort` over their head every few seconds, cheering a catch. Mulgore and the capitals have no twist |
| Bosses | The first boss comes in a random zone from 3 to 6, and the next 3 to 6 zones after each fight. In Thunder Bluff, Orgrimmar and Undercity, which have no boss, a boss due there is a leader instead (`Tuning.escorts`, `World:StartEscort`): Cairne, Thrall or Sylvanas turns up at the same moment, with a "Here to help" banner, and runs ahead for the rest of the zone; the zone clock doesn't stop, the road isn't cleared and normal chunks keep coming, and the next boss is due 3 to 6 zones later as after a fight. Each of the other 12 zones has its own, in `Data/Zones.lua`. The boss turns up 4 seconds into its zone, 58 yards up the road. The chase camera's view spans only about 28 degrees top to bottom (measured from a screenshot), so a boss that far out stands above its top edge: while a boss is out the camera moves over 1.2 seconds to a fight view (5.5 yards up and 10 behind the runner, tilted 12.5 degrees, field of view 1.2) that shows even a 6-yard boss under the boss bar, at the cost of the runner hiding 9 yards of its lane rather than 6. Fog is measured from the camera, so the fog also draws back until the boss is at most 15% of the way into it. The zone clock (zones, speed-ups) stops until it leaves. It throws that zone's hazards, picked from the same fair patterns as usual (a charger becomes a block); each leaves its hand 2.4 seconds before reaching you (from no more than 54 yards ahead) and lands 1.1 seconds before (about 1 second from 38 yd/s up), with a red mark where it will land. Faster than 38 yd/s (`Tuning.boss.farSpeed`) the boss stands further off and throws from further, in step with your base speed (`Rules.Far`): 73 yards off at 48 yd/s, throwing from 68, so a throw still leaves its hand 1.42 s before it reaches you and lands 1 s before. The fog draws back that much further. A leader runs further ahead in the same way, so a gift still lands 0.4 s ahead of you. Spears turn up in safe spots: a lane with nothing solid within 0.45 seconds, from which the rest of the chunk can still be passed. Grab one and it's thrown at the boss. Spears needed: 3 in zones 3 and 4, then one more every 2 zones; a fight offers 1.6 times that. Enough hits drive it off (+500, plus +50 a spear); otherwise it gives up after 25 seconds (+150). No Wind Rider is placed where its flight could still be on when a boss turns up. Numbers are in `Tuning.boss` |
| Joggers | Orcs, Trolls and Tauren of both body types jog along either side of the road at 45% of your speed, one every 30-70 yards. They're scenery: they never block you. Tauren are about one jogger in six (their `weight` in `Data/Assets.lua`), since they look like the runner and stand out. Ten famous Horde faces (Thrall, Cairne, Vol'jin, Sylvanas, Varimathras, Eitrigg, Magatha, Hamuul, Drek'Thar, Saurfang) turn up now and then, with their own lines and replies |
| Alliance joggers | In the gap after a chunk, 35% of the time, an Alliance civilian (human, dwarf, gnome or night elf) jogs away from you in a lane at 45% of your speed. The lane is one with nothing solid along the stretch they'll cover before you reach them, so they never run through a hazard. Running into one knocks them flying for +5 and a one-liner; jumping over them or being in another lane leaves them be. They never end a run |
| Speech bubbles | Passing an orc or troll, your Tauren says something for 2.2 seconds, over its own head: "On your left!" or "On your right!" (matching the jogger's side) half the time, otherwise a line such as "OUTTA MY WAY I GOTTA SCHMOOVE". Passing a fellow Tauren, your Tauren compliments them a few yards before reaching them ("Hey Schmoover!", "Lookin' schmoove!"...), and they reply over their own head a moment later ("SCHMOOVIN GOOD!", "Could it be? The Schmoover!?"...). The compliment and reply lists are only used with Tauren. All lines are in `Data/Assets.lua` under `quips` |
| Power-ups | Wind Rider (fly over everything, 8 s), Magnet (10 s), Thick Hide (absorbs one hit), Gold Rush (tokens x2, 12 s), Stampede (smash through, 5 s, from zone 3) |

All numbers are in `Data/Tuning.lua`.

## Options and accessibility

Options opens over the start or pause screen (opening it mid-run pauses the run); Esc or Done closes it.

| | |
|---|---|
| Game | Sound, Ducking, Resume countdown, Zone length, Starting speed and Window size. Ducking, zone length and starting speed apply from the next run, as with the commands |
| Hazard markers | Off by default. On, each hazard on the road has a mark under it, drawn like a boss throw's landing mark (`Renderer:AddHazardMarker`): amber for jump, blue for duck, red for keep clear, nearly the width of its lane and 0.6 yards longer than the hazard front and back. Side-by-side pieces of one barrier get marks that meet |
| Resume countdown | On by default: after Resume, a big 3, 2, 1 in the middle of the view and nothing moves (keys wait) until it ends. Pausing during it stops it |
| Models | For each zone, the model each hazard (low, high bar, block, wall), charger, coin and gem uses, with a turning preview. The choices are the zone's own models, the shared fallbacks and brighter extras (`ns.ExtraModels` in `Data/Zones.lua`: a fused powder keg, the Tirisfal barricade, a powder keg and a beer keg, a large gold pile, red and blue jewels and the Blackrock museum gem). A pick is saved per zone (`SchmoovinManDB.models`), goes first in that role's chain from then on, and falls back to the usual model if it isn't in the client; the preview says "Not in this client" for those. Every model has a `name` for this list. `Render/Models.lua` builds the chains |

## Scores

Your top 10 is saved for the account and shared across your characters. The guild board swaps best runs with guildmates who have the addon, using hidden addon messages on the guild channel:
- A new personal best is shared straight away.
- Ten seconds after you log in, the addon asks guildmates for their bests.
- Nothing is sent inside instances. A blocked or throttled message waits and retries.

Scores are trusted as sent, with no cheat protection. WoW only writes saved data on `/reload` or logout.

## Files

| File | Role |
|---|---|
| `Data/Tuning.lua` | Every gameplay number |
| `Data/Assets.lua` | Runner, wind rider, token and power-up models; animation IDs; sounds |
| `Data/Zones.lua` | Per-zone ground textures, sky, fog, lighting, scenery, obstacle models and chargers |
| `Render/Models.lua` | Which model each hazard, charger, coin and gem uses, with Options picks first |
| `UI/Options.lua` | The Options screen and its model preview |
| `Game/*.lua` | The simulation: pure Lua with no WoW API, tested outside the game |
| `Render/*.lua` | ModelScene, ground and model drawing, adapted from Dop's Decor Draft |
| `UI/*.lua` | Window, HUD, screens and the game loop |
| `Social/*.lua` | Personal scores and the guild board |

Asset IDs came from the community listfile (release 202611050009) and wago.tools tables, looked up on 2026-11-06. Every ID was confirmed to exist in those sources. Each model role has a list of backups: if a model doesn't load in the Forever client, the next one is used, and chat lists the ones that failed at the end of the run. Models are scaled from their bounding box, so they don't need hand-tuned sizes.

## Style

Since 0.6.0 the window uses the game's classic art rather than the mock-up's flat colours, as requested on 2026-11-06:

| Part | Art |
|---|---|
| Window and main boxes | Dialog-box frame and background, with the dialog header plate behind the title |
| HUD panels | Tooltip edge and background, tinted warm gold |
| Buttons | Red panel buttons (`UIPanelButtonTemplate`) and the round close button (`UIPanelCloseButton`) |
| Bars | The standard status bar texture, tinted per power-up |
| Speech bubble | The game's chat bubble backdrop and tail |

If the backdrop or button templates are missing, the flat look is drawn instead. Layout and contents are unchanged; the mock-up page itself still shows the flat style.

## Accepted layout

A design mock-up was approved on 2026-11-06. It shows the live run, a zone change with the wind rider, the start screen, the paused screen and game over with personal and guild boards, all in the 960 x 600 window.

| Mock-up | Built | Why |
|---|---|---|
| Web fonts (Cinzel, Alegreya Sans) | The game's Friz Quadrata font | Addons use game fonts |
| Sketched 3D view | Real models, terrain textures and fog | The sketch only showed placement |
| Round SVG coin icon on the token counter | The game's coin icon | Real art |
| Zone change as an instant switch | A fog-coloured flash covers the switch | Simpler than a full crossfade of the ground |
| One window size | S, M, L and XL size buttons in the title bar | Asked for after the 0.1.0 look |
| Plain road | Dashed lane lines and solid road edges | Lanes weren't clear enough in 0.1.0 |
| Timer and zone details top centre; boss bar under them; banners mid-screen | Run time, zone, speed and next-zone bar in the score panel (top left); the top centre holds only banners and, in a boss fight, a slim see-through boss bar that fades in as the banner goes | Asked for after the 0.10.0 boss look: the boss bar and banners covered the road and the boss |
| Lanes 2 yards apart | Lanes 2.6 yards apart, road 7.8 yards wide | Asked for after the 0.2.0 look |
| Zone length fixed | Zones button beside Start run | Asked for after the 0.3.0 look |

## Test results

| Check | Result |
|---|---|
| Lua syntax | 0.11.0: all 27 Lua files (25 addon, 2 test) parse as Lua 5.1 (luaparse 0.3.1), rechecked 2026-11-10 |
| 0.13.0: late zones (2026-11-17, fengari) | All 27 Lua files parse as Lua 5.1. Logic tests, with CI's settings: 801 of 801 with 25 s zones and 789 of 789 with 15 s zones. New checks: the speed is still rising in zone 13 and capped in the end; a boss stands no further off up to 38 yd/s and then in step with the speed, and at 48 a throw leaves and lands as long before it reaches you as at 38 (by the numbers and in a run); new layouts unlock in each of zones 6 to 10 and in 12, with ducking off too; the tightest layouts leave no spot for a spear and easier ones do, and every fight from zone 12 on (15 s zones, two seeds) offers enough spears; an Alliance jogger with no clear lane waits for the next gap; an easy layout is a third as likely from its `rareFrom` zone, and easy ones are under 20% of picks in zone 14; the planning bot plays every layout with a hazard on its own, at 48 yd/s and the tightest spacing, one way round and then the other, and two whole runs that start at 48 yd/s; stragglers turn up from zone 8 and never sooner, each with half a gap clear before it and its extra after, none after a pit or in a crosswind, never a bar with ducking off; a road with one after every chunk passes the fairness check, and the bot gets past them at 48 yd/s in Mulgore, on ice and in moonlight. The whole-addon test passed, and now checks that in a fight at 48 yd/s the boss is drawn 73 yards off, clear of the fog, with its head under the boss bar, and that a sandstorm gust at 48 yd/s leaves 1.15 s of road in sight. Not seen in game |
| 0.13.0: crosswind, ice skid and Wind Rider (2026-11-15 and 16, fengari) | All 27 Lua files parse as Lua 5.1. Logic tests, with CI's settings: 627 of 627 with 25 s zones and 615 of 615 with 15 s zones. New checks cover the crosswind: a jump lands one lane downwind (either way), is still over what it jumped at the top, stops at the road's edge, comes back if cut short, keeps the wind it took off in, and can be steered against; a ramp's throw and the drop after a Wind Rider are carried too, a flight isn't; the fairness check's handling of blown jumps; four minutes of Thousand Needles on three seeds with nothing to jump just after a turn, every chunk passable and still plenty to jump; and the bot surviving 150 s of it on three seeds, its boss included. The bot now lets the wind finish carrying a jump before it steers. The smoke test passed, now also pressing jump in the wind and landing a lane over, and placing the wyvern by `seat` and `lift`. A code review the same day found and fixed five things, each with a check now: ramps weren't kept out of the quiet spell after a turn, so 8 of 377 ramps in a probe had their coins laid for the other wind; pit coins were measured from the ramp's arrival, not from when it's first touched, so the trail sat up to a yard off the flight (they were still picked up); a boss's throw put off for the wind could land inside the breather before the boss gives up (2 of 1337 in a probe); the fairness check counted a blown jump as in its landing lane at once (`LIMITS.blowClear` now covers the half second it may still be over the lane it left; no pattern today has rows that close); and `/schmoove flight` could report the box of a wyvern model other than the one flown. Also: the chunk used when nothing fits the wind is picked as a token-only pattern, not by its place in the list, and the smoke test puts back the zone it makes windy. The ice skid was added on 2026-11-16, with fifteen checks by the end of the day, among them: Winterspring gives its runner the skid and no other zone does; the curve goes out to its length, no faster than the lane change before it, and comes back; at its furthest it is in reach of everything in its own lane, out of reach of everything in the next, and on the road; a lane change on ice reaches the lane as soon as before, skids past it and settles; one that ends in the air, or off the ice, does not skid; and with the same keys a skidding runner and a plain one are only ever apart within the skid length of the middle of one lane. The whole-addon test draws the glints, the scraped lines and the spray, and checks the lines are gone once they are out of view. A code review the same day found twelve things, all fixed; those with a check now: glints were painted over pits (the ice is now drawn first, and no glint lies across a pit); the spray and the runner's lean went by how far the runner moved since the last frame, so the spray flickered above 120 frames a second and the lean changed with the frame rate; a lane change turned back at once ended in a full skid; a twist with `skid` and no `skidBack` would have raised an error; the same-keys check made its keys with a generator that gives other numbers on Lua 5.1, and now uses `ns.Random`; and of two jumps landing in one lane the fairness check could keep the wind-blown one, which is the more restricted. Not run in GitHub Actions yet |
| 0.12.1, released as 0.12.2 (2026-11-13, fengari) | All 27 Lua files parse as Lua 5.1. Logic tests, with CI's settings: 571 of 571 with 25 s zones and 559 of 559 with 15 s zones. New checks cover leaders only turning up in place of a boss, their gifts and counts, the combo timer, the crosswind's direction and turns, pit themes and Wind Rider placement. The smoke test passed, now also covering the leader's bar and shouts, the charger running box, `/schmoove measure all`, and the wind streaks and gauge. How the streaks look has no test. After the tag failed in CI (below), the Un'Goro power-up check counts over five seeds; 559 of 559 and 571 of 571 again |
| 0.12.0 (2026-11-12, fengari) | All 27 Lua files parse as Lua 5.1. Logic tests, with CI's settings: 553 of 553 with 25 s zones and 541 of 541 with 15 s zones. New checks cover the combo multiplier and its run-down, pits and ramps, and each zone's twist: that it does what it says and stays fair by its numbers, with bot runs through the Barrens, Moonglade, Ironforge and Thunder Bluff. The smoke test passed, now also drawing a pit and ramp, a steam vent, a wisp and an escort with a gift in the air. How the hand-drawn pieces look has no test: that was checked in game |
| 0.11.1 (2026-11-11, fengari) | All 27 Lua files parse as Lua 5.1. Logic tests, with CI's settings: 461 of 461 with 25 s zones and 449 of 449 with 15 s zones, with new checks that an entity keeps the zone it arrives in, that drained events come back once and that Alliance joggers keep out of a charger's lane. The smoke test passed, now also covering hazard markers and that a wrong `/schmoove zones` or `/schmoove speed` value leaves the setting alone. A run that crashes and is then closed, the crash text and each character's own best have no test of their own |
| GitHub Actions (Lua 5.1.5) | `v0.12.2` (2026-11-13): logic tests at 25 s and 15 s zones and the smoke test passed, and the release job uploaded to CurseForge and GitHub. `v0.12.1` (2026-11-13): logic tests at 25 s zones passed; at 15 s zones 558 of 559, failing "Un'Goro has more power-ups" (2 against 2), so the smoke test and release were skipped. After the fix, `main` (`2ab942b`) passed: 571 of 571, 559 of 559 and the smoke test. 0.11.0: logic tests and smoke test passed on `main` and on tag `v0.11.0` (2026-11-09) |
| 0.11.0 logic tests (`tests/schmoovin_spec.lua`, fengari, 2026-11-10) | With CI's settings: 458 of 458 with 25 s zones (6 seeds x 5 minutes) and 446 of 446 with 15 s zones (4 seeds x 5 minutes). Checks added in 0.11.0 cover slow and fast starts: their speed, the score multiplier, fair spawns and the bot surviving them |
| 0.11.0 smoke test (`tests/schmoovin_smoke.lua`, fengari, 2026-11-10) | Passed. Added in 0.11.0: `/schmoove speed`, the resume countdown, every Options row, model picks, their preview, that every zone and role offers named choices, and that resuming or starting a run closes Options |
| History: 0.7.0 logic tests | With the multi-lane patterns: 396 of 396 passed with 25 s zones (20 seeds x 10 minutes); 356 of 356 with 15 s zones (10 seeds x 10 minutes); ducking on and off in both. The duck-only patterns are confirmed impossible without ducking and never picked with it off |
| History: 0.7.0 smoke test | Passed, plus grouped high bars showing only outer posts, including every window size, the Zones button, `/schmoove zones`, joggers and speech bubbles, the Tauren exchange (your compliment, then their reply) and that orcs never get Tauren lines, posts under high bars, and the backdrop, panel button and close button templates. |
| API names | Every widget and ModelScene method called is declared in Forever's generated docs at the pinned commit |
| Asset IDs | Every file ID and display ID exists in the listfile and wago.tools tables. Forever doesn't ship all of them: the ones found missing in play were replaced (0.8.1, 0.9.0, 0.9.1), and each role keeps backups for any others |
| UIForever simulator | Not run |
| Load in the Forever client | Loaded and played from 0.1.0 (2026-11-06) to the released 0.11.0 (confirmed 2026-11-10) |
| Tauren model, animations, ducking pose | The runner has been seen in game: the tiny runner (fixed in 0.7.1) and the missing later-expansion looks (fixed in 0.9.1) came from playtests. The ducking pose is checked (confirmed 2026-11-10) |
| Model sizes, ground textures, fog | 0.1.0: coin piles too big, camera too close, lanes unclear, moving diagonal lines (playtest). Reworked in 0.2.0 and 0.3.0 after further looks. Models missing from Forever were reported and replaced in 0.8.1 and 0.9.0. Hazard sizes are checked (confirmed 2026-11-10) |
| Wind rider mounting | Flights have been seen in game: a playtest found the runner staying giant after one, fixed in 0.9.1. On 2026-11-12 the author saw the runner apart from the wyvern, facing the camera, with the wyvern sometimes below the view. Since then the runner is never attached (`AttachToMount` isn't used): it's placed in the riding pose on the wyvern's back, and the wyvern is centred side to side on its body under the runner. On 2026-11-13 the author saw the wyvern still too far under the runner, with the runner cut off at the knees by the bottom of the view; their reference picture shows the rider between the wing roots, with the body and tail behind, seen from above and behind. The flight camera had looked at a spot 1.5 yards above the runner's feet, which put the feet at the bottom edge. Now (`FLIGHT` in `Render/Renderer.lua`): the runner sits 45% of the wyvern's height up (was 60%), the wyvern is 0.6 yards back so the runner sits forward on it, and the camera looks 0.5 yards below the runner's feet, which by the camera's geometry keeps sky coins about 30 yards ahead in view. `/schmoove flight` (left out of the help) lists and changes these until a reload, for fitting them in game. On 2026-11-15 the author's screenshot of that build showed the wyvern still about 1.9 yards under where the runner sits (its head and wings at the very bottom of the view, the runner's feet 0.55 yards below its own origin and its seat 0.46 above, by the camera's geometry): the wyvern's box is measured standing and says little about where its back is in flight. So the wyvern is now also raised `lift` = 2.2 yards, and sits 1.0 yards back (was 0.6): in the author's reference picture of a wyvern and rider, the rider is at the wing roots, about a quarter of the way back from its nose. `/schmoove flight` now prints the wyvern's box height and scale, which is what's needed to turn `seat` and `lift` into one number. Not yet seen in game |
| Hazard markers, charger and boss centring | Checked in game on 0.11.1 (confirmed 2026-11-11). `/schmoove measure` (not in the help) lists the chargers and boss on screen with their box measurements, for any that still sit off their lane. On 2026-11-12 Un'Goro's devilsaur measured centred standing (middle 0.00) but -0.33 over all animations, so centring on the all-animation box moved it 0.17 yards off; chargers are now centred on their box while running (`runY`, read 0.3 s into the run), falling back to the all-animation box until then. `/schmoove measure all` loads every zone's charger models up the road in the fog, runs each and prints its middles standing, over all animations and running, marking any whose boxes disagree by more than 0.1 yards for a look in game, and any that don't load. Not yet seen in game |
| Boss fights | The fight camera was checked in game on 0.10.0 (2026-11-08) |
| Options, model picks, resume countdown, starting speeds | Checked in game on 0.11.0 (confirmed 2026-11-10) |
| Guild board with another player | Works with other players (confirmed 2026-11-10) |
| Scores after `/reload` and restart | Checked in game (confirmed 2026-11-10) |
| Screenshot comparison with the mock-up | Not run |

The logic tests cover scoring, the speed curve (ramp, zone bumps, cap), zone order, runner jump and duck sizes, power-ups, shield and crash rules, guild message parsing, and fairness:
- Every pattern is passable at its hardest tempo, with ducking on and off.
- Ten minutes of spawns for each of 20 seeds is passable, with ducking on and off.
- A planning bot plays those same runs and must survive all ten minutes.

## Known limits

- Skyborne joggers were asked for, but Skyborne isn't in the game data: only unreleased file names exist, with no NPC appearances. Female Tauren stand in for now.
- The ground is a grid of small cells fixed to the world. Each shows part of one texture tile, so nothing relies on texture wrapping, and cells near the camera are 1 yard deep so their perspective bend doesn't show.
- The ground is drawn behind the models, so a model below ground level still shows in front of it.
- Scenery is flat-placed beside the track; it doesn't follow hills. Once a piece's size is known it moves out until its whole box, as turned, is at least 1.5 yards clear of the road edge.
- The guild board only knows guildmates who've been online with the addon since you last logged in, or who shared a new best while you were online.
- Ducking uses the stealth-run animation. If the Tauren has none, the game shows its fallback.
