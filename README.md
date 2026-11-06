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
- **Alliance joggers** get in your lane. Run into them to knock them flying, with a one-liner from your Tauren. They never end your run, and you can jump over them if you'd rather.
- **Scoring**: points for tokens, for time survived, and for style: +2 for every obstacle you jump over, +3 for every bar you duck under and +5 for every Alliance jogger you knock over.
- **Scores**: a personal top 10 shared across your characters, plus a guild board with guildmates who have the addon.
- **Your pace**: zones last 15, 25, 35 or 45 seconds, and the window comes in four sizes.

Every run is fair: there is always a free lane or a way to jump or duck through. The addon's tests check this on long simulated runs.

## Controls

| Action | Keys |
|---|---|
| Change lane | A / D or Left / Right |
| Jump | W, Up or Space |
| Duck | S or Down (in the air: drop fast) |
| Pause | Esc or P |
| Start / restart | Enter or R |

You can't start a run in combat, and entering combat pauses the run. Only the game's own keys are taken during a run; chat and everything else still work.

## Commands

| Command | What it does |
|---|---|
| `/schmoove` | Open or close the game |
| `/schmoove start` | Open the game straight into a run |
| `/schmoove zones 15`, `25`, `35` or `45` | Seconds per zone; shorter is harder |
| `/schmoove duck` | Turn ducking off (high bars become blocks) or back on |
| `/schmoove sound` | Turn sound on or off |

## Requirements

World of Warcraft: Forever (interface 16001). No libraries needed.

## Feedback and development

Bug reports and ideas are welcome on the GitHub issues page. Developer notes, test instructions and the release process are in [DEVELOPMENT.md](DEVELOPMENT.md).

## Licence

MIT. See [LICENSE](LICENSE). World of Warcraft art, models and sounds belong to Blizzard Entertainment; the addon only uses what ships with the game client.
