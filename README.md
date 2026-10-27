# Experiment 06: Containment

COMP 440 Project 4 - Team 6. A playable Godot 4 foundation on `BaseGame`.
You are an escaped experiment scavenging the equipment needed to survive three
laboratory trials and reach the surface.

Open `project.godot` with **Godot 4.7.2** and press **F5**, then **Begin Experiment**.
The complete lab is generated at runtime; no asset downloads or add-ons are required.
The project uses the Compatibility renderer and Godot Physics for a portable base.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Shift | Sprint (no stamina cost) |
| Space, then Space in the air | Jump / double jump |
| Hold left mouse | Repeated melee attacks |
| Hold right mouse | Block with the held item; face the incoming attack |
| E | Take equipment, swap the current item, read a file, or use a terminal |
| Q | Drop the held item at your feet |
| F | Toggle flashlight |
| Escape | Pause or close a story file |
| R on the results screen | New run |

Start **empty-handed**. Look toward the illuminated wrench on the first workbench
and press E. Every weapon is a physical lab pickup; there are no loadouts, inventory
spawns, or unarmed attacks. You carry one item. Swapping drops your previous item
with its remaining integrity. Damaged items keep their condition when picked up again.

## Playable loop

1. **Neural Recovery:** find a wrench or specimen tray, learn the creature's attack
   windup, and clear three escaped subjects to release the first trial lock. A
   scientist's recording can be read at the side workbench.
2. **Containment:** fight five subjects among broken chambers and find Subject 06's
   file on the archive terminal. Clearing the trial **and** reading the file releases
   the next lock. The file reveals that you are an experiment.
3. **Transit Lock:** scavenge a security baton, clear six subjects, and use the
   surface override. A dead subject beside the sealed exit shows an earlier failed
   escape. The override completes the run and records the escape time locally.

Menus and story files pause the simulation and all gameplay timers. Timers begin
when a trial is entered; a room's trial timer stops when its final enemy dies. Total
escape time includes travel between trials, excluding pauses. The next room brings
living players up to at least 65 HP. Restart begins again at the first room.

## Combat and movement

Ground speed is 9 m/s, sprint is 12.5 m/s, and air steering and a second jump keep
movement responsive. Jump buffering and coyote time make edges forgiving. Small
camera sway, speed FOV, weapon swings, impact cues, and hit markers provide feedback.

Mutants pursue using a room-aware AStar grid, navigate around furniture, wind up
for 0.6 seconds, lunge, and then recover. Walls block melee and enemy attack sight
lines. A guard protects a frontal arc, reduces damage, and consumes stamina and
item integrity. Stamina regenerates; integrity does not. A broken item disappears,
so another tool must be found. Blocking slows movement and prevents attacking.

| Found item | Damage | Reach | Swing interval | Guard reduction | Integrity |
| --- | ---: | ---: | ---: | ---: | ---: |
| Service wrench | 36 | 2.7 m | 0.42 s | 65% | 100 |
| Pressure pipe | 52 | 3.25 m | 0.65 s | 55% | 110 |
| Specimen tray | 24 | 2.55 m | 0.34 s | 92% | 150 |
| Security baton | 43 | 2.9 m | 0.36 s | 75% | 120 |

## Narrative mechanics

**Flow State:** stages require 2, 3, then 4 kills inside 12, 10, and 9 second windows.
Each stage's timer starts on its **first kill**. Expiration or an unblocked hit clears
the current chain; already unlocked stages remain. Stages increase movement speed
by 12%, 25%, then 40%. A guarded hit preserves the chain.

**Room ranking:** all eight ranks have explicit thresholds. For a target time T,
SSS is at most T/2, SS at most 2T/3, S at most 5T/6, A at most T, B at most 1.25T,
C at most 1.5T, D at most 2T, and E is anything slower. Room targets are 60, 80,
and 90 seconds. The last earned rank gives 16, 14, 12, 10, 9, 8, 7, or 6 seconds
of Return from Death time in the **next** room. The starting allowance is 10 seconds.

**Return from Death:** fatal damage starts a timed fighting window. Successive
activations within the run need **1, 2, 3, 5, 8, then 13 kills**. Later activations
stay at 13 until additional content is designed. Revival attacks deal 30% more damage.
Enough kills restore 55 HP; another hit during revival costs signal time instead of
HP. Running out of time ends the experiment. Enemies are finite, so a late revival
may be impossible if too few subjects remain. The exit requires a restored signal.

**Records:** personal room bests and the top five successful escape times persist
in `user://trial_records.cfg`. These are local records, with no online service.

The supplied story checkpoint informed the premise, four narrative beats, found
moments, and three mechanics. Its coursework submission directions are not game
requirements. Prototype balancing and additional UI/archive text are documented
here as implementation choices; the checkpoint's provisional text count is not
treated as a limit on interface or tutorial text.

## Art direction and current scope

Original low-poly primitive art combines retrofuturist lab architecture, dark
enamel, ivory wall panels, wood, brass, cool utility lights, amber signage, and
broken containment equipment. The visual reference is *Prey* and the movement
reference is TF2's Scout. No art, maps, sounds, names, or characters are copied
from either game. Lighting, faceted mutants, a shadow-casting flashlight, and
synthesized machinery/impact cues establish a first visual and audio pass.

This is a complete short prototype for the team to extend. Enemy meshes, rooms,
weapon animation, and synthesized audio are foundation assets. The scientist
recording is subtitled text with an audio cue; recorded speech, authored textures,
additional enemy types, controller support, checkpoint saves, and online rankings
are future work. The three trials form one continuous level.

## Code map

| File | Responsibility |
| --- | --- |
| `scenes/main.tscn` | Launch scene |
| `scripts/main.gd` | Run state, room progression, story, flow, revival, record persistence |
| `scripts/player.gd` | Character movement, view, interaction ray, melee, directional guard |
| `scripts/enemy.gd` | Pursuit, windup, lunge, recovery, hit reaction |
| `scripts/equipment.gd` | Found-item definitions and balancing |
| `scripts/trial_rules.gd` | Room targets, eight ranks, speed stages, revival balancing |
| `scripts/lab.gd` | Three-room layout, pickups, doors, props, AStar grid, static mesh batching |
| `scripts/world_art.gd` | Reusable primitive meshes, materials, weapon/mutant models |
| `scripts/pickup.gd` | World items and retained durability |
| `scripts/interactable.gd` | Story and exit terminals |
| `scripts/hud.gd` | Menus, HUD, story viewer, results, leaderboard |
| `scripts/lab_audio.gd` | Original synthesized ambience and gameplay cues |

Collision layers: 1 = environment, 2 = mutants, 4 = interactables, 8 = player.
Input actions are installed idempotently by `main.gd` before the player is created.
To add equipment, add a definition to `Equipment.ITEMS`, a model to
`WorldArt.equipment_model()`, and an actual pickup to a room. To move furniture,
use `_obstacle()` or `_table()` so collision and the AI grid stay aligned.

## Verification

With the Godot executable on PATH (or substitute its full path):

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/smoke_test.gd
godot --headless --path . --script tests/enemy_test.gd
```

The smoke test exercises real movement and interaction rays, melee obstruction,
directional guarding, breakage/drop, flow, revival, story locks, ranking bonuses,
pause, record persistence, victory, and death. The enemy test runs actual physics
to check pursuit around a workbench and the complete guarded attack sequence.
Tests use their own records file and do not overwrite a player's leaderboard.

To capture the rendered menu, gameplay, containment room, archive, revival HUD,
and results layout (results use sample data for visual verification):

```powershell
godot --path . --script tests/capture_preview.gd
```

Captures go to the ignored `tmp/previews/` folder. The script also reports frame
rate after shader warmup with enemies frozen for a repeatable render measurement.
This command requires a graphics
display; headless tests do not. An optional absolute output directory can be passed
after `--`. Verification was performed with Godot 4.7.2 and the Compatibility
renderer on Intel UHD Graphics.
