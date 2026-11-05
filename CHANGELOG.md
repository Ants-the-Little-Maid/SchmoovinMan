# Changelog

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
