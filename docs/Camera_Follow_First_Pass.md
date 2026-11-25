# Camera follow tuning

Open `scenes/player/player.tscn`, select **Camera2D**, and adjust these Inspector settings. Defaults live in `scripts/player/player_camera.gd`.

- **Improved Follow Enabled**: uncheck for direct follow. Can also be toggled in the Remote Inspector during play.
- **Horizontal Follow Speed = 12**: higher values catch up faster; no horizontal dead zone.
- **Vertical Dead Zone Pixels = 16**: airborne half-height, giving a 32-pixel band. Grounded framing recenters on each platform.
- **Vertical Follow Speed = 14**: airborne response outside the dead zone.
- **Landing Settle Speed = 9**: grounded response; lower values settle more gently.
- **Framing Height Pixels = 8**: extra upward framing in improved mode, added to the player's existing -32 Y offset. Set to 0 to remove the extra height.

The script rounds camera positions to whole pixels and disables native smoothing and drag. Existing camera limits still apply, although framing/shake offsets can extend beyond them. Vertical lag is capped at 40 world pixels during falls.

Scene replacement and respawn reset follow automatically. Moves exceeding 64 pixels in one physics tick snap automatically. For scripted teleports of any size, call `Player/Camera2D.reset_follow()` immediately after moving the player, before revealing the scene.

## Playtest

Use a current level such as `scenes/levels/Level_1_1.tscn`. Compare improved and direct follow while running, reversing, jumping, landing at different heights, wall jumping, falling, bouncing on mushrooms, and restarting after death. Check platform/hazard visibility, level edges, and foreground/parallax shimmer at your normal integer window scale.
