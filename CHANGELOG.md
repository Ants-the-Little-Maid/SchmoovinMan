# Changelog

## 0.12.0 (2026-11-12)

- Combos: jumps, ducks, ramps and Alliance knocks in a row build a combo. Every five raise what a move pays (x1.5, x2, up to x3). Thick Hide breaking ends it. If you go six seconds without a move while there's something to do, it starts to run down by two every two seconds. The score panel shows it, and game over shows your best.
- Pits: a new hazard from zone 2. A pit runs right across the road, two or three tiles long, with fire at the bottom and a wooden ramp at its edge in one or two lanes. Get to a ramp and it throws you over, through a line of coins; any other lane drops you in. Green arrows run up each ramp.
- Zone twists: every zone but Mulgore now has a rule of its own, named on the zone banner.
  - The Barrens: stampede country. Charging creatures turn up a zone sooner and more often, sometimes two abreast.
  - Ashenvale: a trail of wisps shows one safe way through each group of hazards. They're worth a point each.
  - Burning Steppes: lava vents on a glowing patch between hazards. Keep out of their lane.
  - Silithus: sandstorm gusts that hide the road ahead for a few seconds.
  - Un'Goro Crater: power-ups turn up about twice as often.
  - Thousand Needles: a crosswind that drifts you sideways in the air.
  - Winterspring: an icy road, where lane changes slide. Hazards are spaced further apart to allow for it.
  - Westfall: Defias loot. More coin lines, and some coins are gems.
  - Moonglade: jumps float higher and longer by moonlight. Hazards are spaced further apart to allow for it.
  - Stormwind: crowded streets, with far more Alliance joggers to knock over.
  - Darnassus: you're given Thick Hide on the way in.
  - Ironforge: steam vents between hazards. Keep out of the steam.
  - Thunder Bluff, Orgrimmar and Undercity: Cairne, Thrall or Sylvanas runs ahead of you beside the road and throws gifts back into your lanes, with a green mark where each will land: coins, and Stampede, Gold Rush or Thick Hide.

## 0.11.1 (2026-11-11)

- Hazard markers: an Options setting (or `/schmoove markers`), off by default, that puts a coloured mark on the road under each hazard: amber to jump, blue to duck, red to keep clear.
- Charging creatures and bosses stand in the middle of their lane. Some, in Un'Goro, Ashenvale and the Barrens, ran off to one side.
- Game over now names what charged you in every zone, such as "Charged by a City guard", using the model that was on screen. The eight newer zones used to say "a beast".
- A run that has just crashed is saved if you close the window or enter combat in the moment before the game-over screen. It used to pause, and Restart or Quit then lost the score.
- `/schmoove zones` and `/schmoove speed` with a missing or wrong number now leave the setting alone and list the choices, instead of putting it back to Normal.
- The first hazards after a zone change use the new zone's models, not the old zone's.
- Guild board: a character's own best is shared even when your other characters hold all ten personal places.
- Guild board: a score waiting to be sent is dropped if you leave the guild, instead of being retried for the rest of the session.
- Alliance joggers no longer jog in a lane a charging creature is coming down.
- The camera follows lane changes and flights at the same pace at any frame rate.
- Less memory churn while running.

## 0.11.0 (2026-11-09)

- Options: a settings screen in the game window, opened from the start and pause screens, the minimap menu or `/schmoove options`. It covers sound, ducking, zone length, starting speed, window size and the resume countdown. Opening it mid-run pauses the run.
- Starting speed: start slow (8 yd/s, score x0.75), normal (11) or fast (14, score x1.25). Choose it on the start screen, in Options, in the minimap menu or with `/schmoove speed 8`, `11` or `14`. The game-over total shows the multiplier.
- Easier to see: swap any hazard, charger, coin or gem that's hard to see in a zone for another, in Options, with a turning preview. Brighter extras include powder kegs, a barricade, red and blue jewels and a large gold pile. "Reset to Default" puts a zone's usual models back.
- Resuming a paused run counts down 3, 2, 1 first, so nothing hits you straight away. It can be turned off in Options.
- A new run's camera starts in place, instead of drifting down from the last run's Wind Rider flight.
- Fixed the camera staying in its boss-fight view, with the fog drawn back, for the rest of a run if a boss's model couldn't load.

## 0.10.0 (2026-11-08)

- Bosses: every few zones a boss blocks the road and throws hazards into your lanes, with a red mark where each will land. Grab the spears that turn up to throw them at it: enough hits drive it off for +500 (and +50 a spear), or survive 25 seconds until it gives up for +150. The first comes in zone 3 to 6 and the next 3 to 6 zones after each fight. Spears needed start at 3 and rise by one every 2 zones. The zone clock stops while a boss is out.
- Twelve bosses, one for each zone outside the Horde capitals: Verog the Dervish, Arnak Grimtotem, Ursangous, Volchan, Krellack, King Mosh, Rak'shiri, Edwin VanCleef, Omen, Highlord Bolvar Fordragon, Tyrande Whisperwind and King Magni Bronzebeard.
- Game over shows bosses driven off and outlasted, with their points.
- In a boss fight the camera drops a little, levels out and widens so you can see the boss up the road, under the boss bar, and the fog draws back from it. Before, bosses stood above the top of the view, and Volchan, the Burning Steppes fire elemental, was lost in the fog as well.
- Roadside scenery no longer reaches onto the road: big pieces, such as the trees in Un'Goro Crater, stand further out so it's clear where you can run.
- The pause button in the title bar now says "Pause" (or "Resume"), sits at the left end away from the size and close buttons, and is greyed out outside a run.
- The HUD keeps the road clear: run time, zone, speed and the next-zone bar moved into the score panel, and the top middle now holds only banners (zone, boss) and the boss bar during a fight.

## 0.9.1 (2026-11-07)

- Fixed the runner staying giant after a Wind Rider flight, for the rest of the session.
- The runner now loads its Classic look straight away, without the "3 model(s) didn't load" message.

## 0.9.0 (2026-11-06)

- Eight new zones: Westfall, Moonglade, and the capitals Stormwind City, Darnassus, Ironforge, Thunder Bluff, Orgrimmar and Undercity. Each has its own ground, sky, scenery, hazards and charging creature. Runs still start in Mulgore.
- Famous Horde joggers: Thrall, Cairne Bloodhoof, Vol'jin, Sylvanas, Varimathras, Eitrigg, Magatha, Hamuul, Drek'Thar and Saurfang now and then jog by the road. Your Tauren greets each in their own words, and they answer back.
- The game-over guild badge only shows when the run is your character's new best, with the place it now holds. Before, every run showed where its score would rank, so a short run could read "#3 in guild" while you held #1.
- Fixed a female troll jogger appearance that isn't in Forever ("didn't load" message).
- Alliance joggers on the track: run into them to knock them flying, for +5 points and a one-liner. They never end your run, and they never jog through a hazard. Game over shows your knocks next to jumps and ducks.

## 0.8.2 (2026-11-06)

- Fixed characters with a surname, such as "Ants Man", being saved as just "Ants". Your own guild messages came back under the full name, so you showed up twice on the guild board, and the game-over guild rank counted you against yourself. Runs and board entries saved under the first name move to the full name the first time you log in.

## 0.8.1 (2026-11-06)

- Winterspring's charging yeti now uses Classic yeti models. The old one isn't in Forever, so it was swapped for a backup with a "didn't load" message.
- Fewer Tauren joggers: about one in six, down from one in three.

## 0.8.0 (2026-11-06)

- Jump and duck points: +2 for every obstacle you jump over and +3 for every bar you duck under, when it's in your path. Shown on the game-over screen as "Jumps and ducks".
- Right-click the minimap button for a menu:
  - **Start a run**: opens the game straight into a run, or brings back a paused one.
  - Zone length, window size, ducking and sound.
- `/schmoove start` does the same quick launch.

## 0.7.2 (2026-11-06)

- Fixed invisible hazards, coins and scenery introduced in 0.7.1: models waited for a "geometry ready" signal that Forever never sends for props, so they stayed hidden (while hazards could still hit you) and were then reported as failed. Models now show as soon as they load; that signal only causes a 1-second wait.
- The runner's usual appearances load again instead of falling back to the Orgrimmar Brave.
- A model that fails to load is reported once, not once per copy.

## 0.7.1 (2026-11-06)

- Fixed the runner (and joggers) sometimes showing tiny, seen by a player on a first run:
  - Models are measured only once their geometry has loaded.
  - Characters are measured by their own size, not the extra room the game reserves for animations.
  - A character's size is kept within sensible limits.
- Models get 10 seconds to stream in before a backup is used (was 3).
- Settings changed during a run (`/schmoove duck`, `/schmoove zones`) now wait for the next run, as the messages say.
- Guild board: each character shares only its own best, not the account's.
- The window refits if your screen resolution or UI scale changes.
- Less memory churn while running.

## 0.7.0 (2026-11-06)

- New multi-lane hazards:
  - Logs to jump across the whole road.
  - Two-lane walls with a jump in the third lane.
  - Full-width bars to duck under.
  - Two-lane underpasses.
  - Hurdle runs.
- Hazards side by side are drawn as one barrier, so it's clear they block those lanes together.
- With ducking turned off, the full-width duck patterns never appear.

## 0.6.x

- Classic WoW look: dialog-box frames, tooltip-edged HUD, red panel buttons, the round close button and real chat bubbles.
- Passing a fellow Tauren is a two-way exchange: you compliment them, they answer.
- New lines for overtaking orcs and trolls.
- High bars stand on posts.
- Hazards are measured and centred properly and made smaller, so they no longer hide the road or spill across lanes.

## 0.5.0

- Orc, Troll and Tauren joggers along the roadside, and a speech bubble when you pass them.

## 0.4.0

- Zones last 25 seconds by default, with a choice of 15, 25, 35 or 45 on the start screen or with `/schmoove zones`.
- A calmer, paler road in Mulgore.

## 0.3.0

- Camera re-aimed, wider road, lighter centre tracker, bigger coins.

## 0.2.0

- Smaller coins, camera further back, four window sizes, lane markings, cleaner ground.

## 0.1.0

- First release: the run, eight zones, five power-ups, personal and guild scores.
