# Schmoovin Man: developer notes

How the addon is built, what was checked, and why things are the way they are. The player-facing overview is [README.md](README.md); version history is [CHANGELOG.md](CHANGELOG.md).

**Status:** version 0.11.1 (2026-11-11): hazard markers, chargers and bosses centred on their lane, and nine fixes from a review of the whole addon (see [CHANGELOG.md](CHANGELOG.md)). 0.11.0 (2026-11-09) added the Options screen, starting speeds with a score multiplier, per-zone model picks and the resume countdown. 0.10.0 (2026-11-08) added bosses, the fight camera and the HUD layout that keeps the road clear.

- **Tests:** all pass on 0.11.1 locally; 0.11.0 passed in GitHub Actions. See [Test results](#test-results).
- **In game:** 0.11.1 has been played by the author, with the hazard markers and the charger centring checked (confirmed 2026-11-11). The released 0.11.0 was played and checked before it (confirmed 2026-11-10), including the Options screen, model picks, resume countdown, starting speeds, the ducking pose, hazard sizes, saved scores and the guild board.
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

GitHub Actions runs both (short versions) on every push and before every release.

## Releasing

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) (v2.7.0 or later) from `.github/workflows/release.yml`:
- Push a tag such as `v0.7.0`. The workflow runs the tests, then packages the addon.
- `.pkgmeta` leaves out the tests and developer docs.
- `@project-version@` in the TOC becomes the tag.
- Interface `16001` is detected as Forever, and the file is uploaded to CurseForge under game type 88568. WoWInterface has no Forever category, so that upload is skipped.

Uploads need:
- The CurseForge project ID in the TOC as `## X-Curse-Project-ID`.
- A CurseForge API token in the repository secret `CF_API_KEY`.

Without them, the workflow still builds the zip and attaches it to the GitHub release.

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
| Speed | Starts at 11 yd/s (or 8 or 14, see Options), rises 0.03 yd/s every second, and jumps 2.2 yd/s on entering each zone, up to 38 yd/s. A slow start multiplies the final score by 0.75 and a fast one by 1.25 (`Tuning.startSpeeds`); saved runs record their starting speed |
| Obstacles | Low (jump), high bar on two posts (duck, from zone 2), block, two-lane wall (from zone 2), charging creature (from zone 3), combos from zone 4 |
| Tokens | Gold coins 10 points, gems 50. Lines, jump arcs and sky lines while flying |
| Time points | 10 per second, plus 2 per second for each zone reached |
| Move points | +2 per low obstacle jumped and +3 per high bar ducked, when it's in your path and you make the move. Flying, Stampede smashes, shield hits and invulnerable pass-throughs don't count. +5 per Alliance jogger knocked over |
| Bosses | The first boss comes in a random zone from 3 to 6, and the next 3 to 6 zones after each fight. A zone without a boss (Thunder Bluff, Orgrimmar, Undercity for now) passes it on to the next zone that has one. Each of the other 12 zones has its own, in `Data/Zones.lua`. The boss turns up 4 seconds into its zone, 58 yards up the road. The chase camera's view spans only about 28 degrees top to bottom (measured from a screenshot), so a boss that far out stands above its top edge: while a boss is out the camera moves over 1.2 seconds to a fight view (5.5 yards up and 10 behind the runner, tilted 12.5 degrees, field of view 1.2) that shows even a 6-yard boss under the boss bar, at the cost of the runner hiding 9 yards of its lane rather than 6. Fog is measured from the camera, so the fog also draws back until the boss is at most 15% of the way into it. The zone clock (zones, speed-ups) stops until it leaves. It throws that zone's hazards, picked from the same fair patterns as usual (a charger becomes a block); each leaves its hand 2.4 seconds before reaching you (from no more than 54 yards ahead) and lands 1.1 seconds before (about 1 second near top speed), with a red mark where it will land. Spears turn up in safe spots: a lane with nothing solid within 0.45 seconds, from which the rest of the chunk can still be passed. Grab one and it's thrown at the boss. Spears needed: 3 in zones 3 and 4, then one more every 2 zones; a fight offers 1.6 times that. Enough hits drive it off (+500, plus +50 a spear); otherwise it gives up after 25 seconds (+150). No Wind Rider is placed where its flight could still be on when a boss turns up. Numbers are in `Tuning.boss` |
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
| 0.11.1 (2026-11-11, fengari) | All 27 Lua files parse as Lua 5.1. Logic tests, with CI's settings: 461 of 461 with 25 s zones and 449 of 449 with 15 s zones, with new checks that an entity keeps the zone it arrives in, that drained events come back once and that Alliance joggers keep out of a charger's lane. The smoke test passed, now also covering hazard markers and that a wrong `/schmoove zones` or `/schmoove speed` value leaves the setting alone. A run that crashes and is then closed, the crash text and each character's own best have no test of their own |
| GitHub Actions (Lua 5.1.5) | 0.11.0: logic tests and smoke test passed on `main` and on tag `v0.11.0` (2026-11-09) |
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
| Wind rider mounting | Flights have been seen in game: a playtest found the runner staying giant after one, fixed in 0.9.1. Flights have looked fine since (confirmed 2026-11-10). Falls back to sitting the Tauren on top if attaching fails |
| Hazard markers, charger and boss centring | Checked in game on 0.11.1 (confirmed 2026-11-11). `/schmoove measure` (not in the help) lists the chargers and boss on screen with their box measurements, for any that still sit off their lane |
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
