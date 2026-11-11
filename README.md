# Schmoovin Man

**An endless-runner minigame for World of Warcraft: Forever.** A Tauren auto-runs through Mulgore and on across Kalimdor and beyond. Dodge, jump, duck, fly and grab tokens. Each new zone speeds you up. How long can you keep schmoovin'?

Open it with `/schmoove` or the kodo button on the minimap. Right-click the button to jump straight into a run or change settings.

## Features

- **A 3D run in its own window**, built from the game's own models and terrain. It starts in Mulgore, then visits 15 more in a random order:
  - The wilds: The Barrens, Thousand Needles, Ashenvale, Burning Steppes, Silithus, Un'Goro Crater, Winterspring, Westfall and Moonglade.
  - The capitals: Stormwind, Darnassus, Ironforge, Thunder Bluff, Orgrimmar and Undercity.
- **Three lanes, five moves**: change lane, jump, duck, and power-ups that let you fly or smash through.
- **Hazards that fit each zone**: logs, totems, ruin walls, bars to duck under, and charging kodos, devilsaurs and yetis.
- **Five power-ups**:
  - Wind Rider: fly over everything.
  - Magnet: pull in tokens.
  - Thick Hide: survive one hit.
  - Gold Rush: double token points.
  - Stampede: smash through hazards.
- **Joggers** of the Horde jog along the roadside. Overtake them and your Tauren has something to say. Fellow Tauren have something to say back, and so do famous faces such as Thrall, Cairne, Vol'jin and Sylvanas.
- **Bosses** block the road every few zones: Edwin VanCleef in Westfall, King Mosh in Un'Goro, King Magni in Ironforge and more, one for each zone outside the Horde capitals. A boss throws hazards into your lanes, with a red mark where each will land. Grab the spears that turn up and they're thrown at the boss: enough hits drive it off for a big bonus, or survive 25 seconds until it gives up. The zone clock stops while a boss is out.
- **Alliance joggers** get in your lane. Run into them to knock them flying, with a one-liner from your Tauren. They never end your run, and you can jump over them if you'd rather.
- **Scoring**: points for tokens, for time survived, and for style: +2 for every obstacle you jump over, +3 for every bar you duck under and +5 for every Alliance jogger you knock over. Bosses pay +50 a spear, +500 for driving one off and +150 for outlasting one.
- **Scores**: a personal top 10 shared across your characters, plus a guild board with guildmates who have the addon.
- **Your pace**: zones last 15, 25, 35 or 45 seconds, and runs start slow (8 yd/s, scores x0.75), normal (11) or fast (14, scores x1.25). The window comes in four sizes.
- **Options** in the game window (the start and pause screens, or `/schmoove options`): sound, ducking, zone length, starting speed, window size and a 3-2-1 countdown before a paused run goes on.
- **Hazard markers**: turn them on in Options for a coloured mark on the road under each hazard: amber to jump, blue to duck, red to keep clear.
- **Easier to see**: if a hazard, charger, coin or gem is hard to see in some zone, swap it in Options for another, with a turning preview. Each zone offers its own models plus brighter picks such as powder kegs, a barricade, red and blue jewels and a large gold pile.

Every run is fair: there is always a free lane or a way to jump or duck through. The addon's tests check this on long simulated runs.

## Controls

| Action | Keys |
|---|---|
| Change lane | A / D or Left / Right |
| Jump | W, Up or Space |
| Duck | S or Down (in the air: drop fast) |
| Pause | Esc or P, or the Pause button at the left of the title bar |
| Start / restart | Enter or R |

You can't start a run in combat, and entering combat pauses the run. Only the game's own keys are taken during a run; chat and everything else still work.

## Commands

| Command | What it does |
|---|---|
| `/schmoove` | Open or close the game |
| `/schmoove start` | Open the game straight into a run |
| `/schmoove options` | Open the options |
| `/schmoove zones 15`, `25`, `35` or `45` | Seconds per zone; shorter is harder |
| `/schmoove speed 8`, `11` or `14` | Starting speed; slow scores x0.75, fast x1.25 |
| `/schmoove duck` | Turn ducking off (high bars become blocks) or back on |
| `/schmoove sound` | Turn sound on or off |
| `/schmoove markers` | Turn the coloured marks under hazards on or off |

## Requirements

World of Warcraft: Forever (interface 16001). No libraries needed.

## Feedback and development

Bug reports and ideas are welcome on the GitHub issues page. Developer notes, test instructions and the release process are in [DEVELOPMENT.md](DEVELOPMENT.md).

## Licence

MIT. See [LICENSE](LICENSE). World of Warcraft art, models and sounds belong to Blizzard Entertainment; the addon only uses what ships with the game client.
