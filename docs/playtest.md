# BaseGame playtest route

Use F5 to launch the game from Godot. The checklist below covers the manual feel
and presentation checks that automated state/physics tests do not replace.

- Start a fresh run. Confirm empty hands and a visible wrench on the first bench.
- Aim at the wrench and press E. Run, sprint, jump, and double jump around the bed.
- Circle a creature, observe its lean before a lunge, and hold right mouse while
  facing it. Try the same guard with your back turned. The rear attack should hurt.
- Hold left mouse to chain swings. Check that walls and the solid bench stop hits.
- Swap to the tray on the side bench. Find the dropped wrench and pick it up again.
- Read the scientist recording. Check that the room timer freezes until closing it.
- Kill two subjects quickly. Confirm Flow 01 and a perceptible speed increase.
- Finish the first trial. Check its rank and walk through the released gate.
- In Containment, inspect broken chambers and read the Subject 06 archive file.
- Confirm the second lock requires both the file and all five enemies to be cleared.
- Allow fatal damage with an enemy still alive. Defeat it before the signal timer
  expires and check the recovery feedback. On a second activation, two kills are due.
- Reach Transit, find the security baton, and inspect the failed subject near exit.
- Try the override before clearing the trial. It should remain locked.
- Clear Transit and use the override. Confirm victory, three room ranks, total time,
  and a local leaderboard entry. Restart and verify personal bests survive.
- Pause, mute audio, resume, and restart. Resize the game window to check the HUD.

Tuning priorities: first pickup timing, readability of the mutant windup, guard
stamina/integrity under a group attack, speed at Flow 03, and trial target times.
Adjust `equipment.gd`, `trial_rules.gd`, and the movement constants in `player.gd`.
