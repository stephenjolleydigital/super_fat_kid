# Snack Kid Superstar / Fatkid Snack Run

A 256x224 arcade roguelite: ten stages, one life, three starting hearts. Eat the ten foods on each stage to power its exit; each food heals one heart. The 50 chest items and 14 stage perks are separate pools. Draft before stage 1 and after stages 1-9. The original player artwork is preserved.

## Play

Open the main Fat Kid project in Godot 4.4.1, then open `assets/minigames/snack_kid_superstar/scenes/Cabinet_Demo.tscn` and press F6 (Run Current Scene). The cabinet preserves its 256x224 playfield inside the main 480x270 viewport. This minigame belongs to the main project; do not add a nested `project.godot`.

```powershell
& 'C:\Path\To\Godot_v4.4.1-stable_win64.exe' --path 'C:\Path\To\super_fat_kid' res://assets/minigames/snack_kid_superstar/scenes/Cabinet_Demo.tscn
```

- WASD/arrows: move. The cannon fires automatically in the last movement-key direction you pressed, including up/down, and remembers it after release. With overlapping keys, the newest press sets the shot direction; movement still supports diagonals. Z spends a loaded Pit Olive and overrides legendary autoaim.
- Space: belly flop. E: use the nearby chest, gate or exit.
- 1/2/3 then Enter: choose a stage perk; arrows also select.
- P/Esc: pause. I: inventory; left/right browse.
- M: sound. N: music. F: screen shake. Enter initials after a run to save a score.

Scores save under `user://snack_kid_superstar`; `saves/scores.json` is the fallback seed. The main project controls window, rendering, and logging settings.

## Pixel grid and host integration

All artwork, circles, warnings and UI rasterize on the same 256x224 grid. Viewport stretch, nearest filtering, integer enlargement and pixel snapping keep the pixels sharp. The cabinet SubViewport preserves the native grid; the main project controls integer enlargement of the host window.

`scenes/Cabinet_Demo.tscn` renders the game and result overlay into a fixed 256x224 SubViewport. Its screen sprite sits at 1:1 on a separate CanvasLayer, isolated from host camera zoom and parent transforms. Set integer `origin`, or call `center_in(Vector2i(480,270))` for origin (112,23). Set optional `screen_layer` before adding it to the tree. Enlarge the whole host frame with nearest/integer scaling; do not independently scale or rotate the screen sprite.

The wrapper forwards unhandled keyboard events once. The host must suspend its platforming controls while playing. Public `game`, `host_result`, `rounds_cleared`, `result`, and `shutdown()` remain available.

For the campaign version, run level 1-1, collect the quarter near spawn, then press Up beside the arcade cabinet. Entry costs one quarter. Both games and replays are included until you leave the cabinet. Esc or Start opens the cabinet menu during play. Actual campaign art and palette were inspected read-only: the legacy minigame colors differ from the current master palette. This pass preserves those colors and the original player; it establishes a consistent pixel grid, not full palette conformity.

## Loot and pressure

Tin/Silver/Neon chests cost 8/22/48 on stage 1, reaching 33/91/199 on stage 10. Base kill income rises from 8 to 17, so every tier requires more work on later stages. Chest prompts show approximate BASE KILLS at full bounty, not the lower late reinforcement rate. Chest ranks cap at three; stage perks stack separately up to the shared effect cap of twelve. Higher chest tiers favor rarer items.

THREAT rises every 40 seconds locally, resets each stage, and caps at tier 5. Reinforcements arrive faster and grow tougher. Their coin and Snack Insurance credit rates are 100/85/55/30/12%; their score rates are 50/30/15/8/4%. Placed enemies retain full rewards. Quick exits at tiers 1/2/3 grant 2000/1000/400 points scaled by stage. There is no forced exit or lethal deadline.

Opening a key, loan or blood lock pays the price of two tin chests, once. Alarm locks retain their +30 coins and three queued enemies. Door prompts advertise the bonus. Extra loot remains a risk/reward choice; waiting to buy every chest can become dangerous.

Combo Meal, Vacuum Mouth, Nonstick Sneakers, Chomp Chomp, Spike Syrup and Floor Sauce have offensive interactions explained on their inventory cards. **Smart Sauce** (the existing legendary Sauce Grenade slot) grants cannon autoaim when owned as a chest item; it retains splash damage. Hold Z to use your remembered manual direction instead. Without a visible target, it falls back to that direction. The item pool remains 50 entries.

## Collision and movement update

Player contact and hostile bullets use a forgiving capsule centered on the visible body, rather than the feet anchor. Ordinary enemies and the boss use body-shaped oval contacts. Projectiles check the path travelled between frames, so fast shots do not skip bodies. Wall navigation, food pickup reach and intentional blast areas remain separate.

Satellite donuts now share one position/count list for rendering and damage, including all twelve at maximum combined rank. They orbit the visible body center. Wall-blocked donuts remain visible but dim; both the player-to-donut and donut-to-enemy paths must be clear to deal damage.

Two movement drafts join the original twelve:

- **Roller Rink:** oil immunity; continuous movement builds up to +10% running speed per pick over one second. Stopping resets the buildup.
- **Bounce House:** each pick reduces flop cooldown by 0.25 seconds, adds a 0.5-second speed burst after flopping, and grants one Pizza Turbo rank.

Both stack up to three picks and respect the existing movement caps. The chest pool remains 50 items. Directional shooting and Smart Sauce are unchanged.

## Final course

The stage-10 exit starts King Calzone (a minigame-only, non-canon placeholder name). Dodge charge lanes, gaps in pizza volleys and marked meatballs; attack during green OPEN recovery windows. Three phases have healing pizza drops, damage budgets and stun immunity. Recovery contact is safe; moving contact is dangerous.

Four arena spike tiles hurt both sides. Boss spike damage bypasses armor and its damage budget, but retains the hit cap and phase floors. An independent half-second spike cooldown prevents rapid weapon hits from multiplying spike ticks. Shield breaks during the fight can wind the boss for 1.4 seconds and cancel pending meatballs, at most once every six seconds. Intro/phase transitions cannot be interrupted this way. Pizza drops avoid spikes. Victory celebrates briefly before reporting the result.

## Verification

Latest collision/satellite/movement update: **610 economy/contact/perk + 52 boss + 13 raster = 675 checks passed**, with zero raster mismatches. Native wall/open previews confirmed the complete twelve-donut ring and dim blocked satellites. Tests cover hit/near-miss boundaries, fast projectiles, satellite wall corners, movement stacking/caps, and wall/guard/conveyor stops. Temporary previews were removed. Human feel and balance still need playtesting; no new campaign matrix was run.

Prior directional shooting update: **484 economy/aiming + 47 boss + 13 raster = 544 checks passed**. Covers all eight movement keys, remembered direction after release, newest-key priority, ignored key-repeat, no default target seeking, legendary autoaim/Z override, new-run reset, and cabinet input. The loaded olive marker follows the remembered shot direction. Historical campaign results below predate this control change.

Use `Godot_v4.4.1-stable_win64_console.exe` from the main project root:

```text
--headless --path . --script res://assets/minigames/snack_kid_superstar/tests/test_economy.gd
--headless --path . --script res://assets/minigames/snack_kid_superstar/tests/test_boss.gd
--path . --script res://assets/minigames/snack_kid_superstar/tests/test_rendering.gd
--headless --path . --script res://assets/minigames/snack_kid_superstar/tests/full_run_audit.gd
--path . --script res://assets/minigames/snack_kid_superstar/tests/full_run_audit.gd -- --tour
--path . --script res://assets/minigames/snack_kid_superstar/tests/visual_playtest.gd
--path . --script res://assets/minigames/snack_kid_superstar/tests/boss_playtest.gd
```

The raster test requires a real renderer: it compares all 57,344 native pixels against a 1:1 placement inside 480x270 and all 516,096 enlarged pixels against exact 3x3 blocks. It also checks camera/parent isolation and single keyboard delivery. `-- --capture` writes temporary `.render-*.png` images under tests.

The campaign audit uses normal damage and input, but knows the map. Default: three seeds, three build preferences and four policies (rush/selective/full/camp). Filter with `--policy=selective --seed=19 --build=assault`; `--hesitant` adds reaction delays and missed flops. Optional `--policy=extra` seeks up to four affordable nearby chests and early, safer side rooms. The full policy exhausts food before farming and can spend HP on locks: its failures cannot alone establish human difficulty. Reports go to stdout.

The boss fixture injects ten perks and six item ranks, then runs normal combat; it is not an earned campaign. Add `-- --build=scrappy --hesitant` for a weaker fixture. With a real renderer, `--capture` writes a native `.boss-live.png` after eight seconds. The facing fixture isolates movement and directional shooting. Keep resource `.import` and `.uid` sidecars.

Previous autoaim-build checks: **461 economy/UI/vault + 45 boss + 13 raster = 519 passed**, with zero pixel mismatches. Added checks cover single vault payouts, failed unlocks, native-width chest prompts, trap caps/phase immunity, shield stagger cooldowns, and spike/weapon cooldown isolation. A native capture from moving combat was inspected; the weak hesitant boss fixture won in 58.9 seconds with one heart left.

Historical results from the previous default-autoaim build (not current directional controls): the 36-run matrix won 7/9 rush, 8/9 selective, 1/9 full-loot attempts and 2/9 camping runs. The immediately preceding baseline won 8/9, 8/9, 0/9 and 5/9 respectively. This is a mixed balance result, not a universal difficulty improvement: selective guard boss fights fell from 187.6/101.2/48.7 seconds to 94.2/60.8/47.3, while rush guard fights still took 125.8/102.7/150.4 seconds. Full-loot attempts averaged 19.6 items versus 15.3 before. A separate final nine-run extra-loot comparison won 9/9, averaged 31.2 items, and finished bosses in 20.7-56.2 seconds. These are fixed-seed bot outcomes, not population win rates.

That earlier build's Cursor read-only review confirmed the spike cooldown fix and found no remaining blockers. Its provisional assessment remains **7/10**: defensive rush fights can run long, full-loot camping is dangerous, the boss name awaits canon review, and human difficulty/readability/fun still need player feedback.
