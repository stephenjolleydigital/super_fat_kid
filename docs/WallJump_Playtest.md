# Bubblegum wall-jump playtest

Open `res://scenes/tests/WallJumpArena.tscn` and run the current scene (F6).

- Right pickup: bubblegum (wall jump). Left pickup: taco (double jump).
- Move and jump with the normal controls.
- **R**: restart, retaining collected upgrades.
- **F1**: clear the arena's wall-jump, double-jump, blaster and run upgrades, then restart.
- **F2**: move to the outside area with blaster, run medal, slope, ledge and mushroom.

## Current behavior and tuning

Bubblegum unlocks wall jumping for the running game. Hold toward a wall while falling to slide. Airborne contact shows the cling cue; a wall jump requires 0.05 seconds of visible cue, and a jump pressed during that cue waits. A wall jump needs no directional input. Each launch spends that side until landing or contacting the opposite wall. Wall jumps do not spend or restore the taco's double jump.

Tune the Player node in `scenes/player/player.tscn`; defaults are in `scripts/player/Player.gd`:

- Jump buffer: 0.12 s; ground and wall coyote time: 0.10 s each.
- Early-release speed: 50% of launch magnitude; ground minimum rise: 24 px.
- Wall-slide speed: 120 px/s; deceleration: 3,000 px/s².
- Wall launch: 1.1 × run speed outward and 1.1 × current jump impulse upward.
- Outward protection: 0.16 s; steering recovery: 0.10 s.
- Cling cue: 0.05 s; ground proximity for the hold pose: 32 px below the feet.

Tune wall audio on the player's `SFX_WallCling`, `SFX_WallSlide`, `SFX_WallJump`, and `SFX_WallImpact` nodes. Push-off and impact play together. Preserve the wall-slide loop import settings and the four wall-audio `.wav.import` files.

## Hands-on checks

1. Before collecting gum, check that walls do not slow falls or grant jumps. After collecting it, compare holding toward a wall, neutral contact, and rising contact.
2. Launch from both walls, with and without directional input. Check the cling cue, outward push, steering recovery, and shorter jumps on early release.
3. Try repeated launches from the same segmented wall: sliding remains available, but another launch requires landing or opposite-wall contact. Alternate walls to climb.
4. Collect the taco and try wall jump then double jump, and the reverse. Compare tapped/held ground jumps and jumps queued just before landing.
5. Use F2 to check shooting, kicks, slope/corner contact and mushroom bounces. Releasing Jump should not shorten a mushroom launch.
6. Listen for one cling per catch, a smooth slide loop, and both push-off layers. Check that slide sound stops when sliding ends, and pause/restart does not leave stale audio.
