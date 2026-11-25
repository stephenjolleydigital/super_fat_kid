# FatKidGame — AI Context (Cursor / Codex)

## Engine / Version
- Godot 4.4.1
- 2D pixel-art platformer
- Player uses CharacterBody2D (Godot 4 patterns only)

## Current Project
- This is an established platformer with multiple campaign levels, enemies, hazards, pickups, health/lives, progression, and arcade minigames. Do not treat these implemented systems as future core-slice work.
- Campaign scenes live in `scenes/levels/`; `resources/progression/campaign_catalog.tres` defines their progression order.
- Player movement includes run, jump, kick, double jump, wall jump, crouch, and blaster abilities, with unlocks and stamina/gas progression. Inspect the current scripts and settings before changing behavior.
- Existing audio, animation, HUD, title screen, and transitions should be preserved during cleanup.
- `project.godot` `[application] run/main_scene` is the configured F5 entry point. Test scenes are launched individually with F6.
- Use the backlog and story bible for task status and design decisions; this file describes working conventions and current organization.

## Art / Visual Rules
- STRICT master palette: ~98 colors (excluding transparency/clear); the files in `assets/palette/` are the source of truth for the exact list
  - Source: `assets/palette/fatkid_master_palette.png`, `.gpl`, `.aseprite` (project default)
- Do NOT create separate minigame palettes (e.g. Alien Commander) unless explicitly requested
- Prefer existing master palette colors for UI, cursors, meters, and arcade cabinet elements
- If a color must be added to the master palette, call it out clearly first — do not add silently
- Prefer per-sprite color count ~12–16 when possible
- Target resolution: 480x270 (16:9), from project.godot [display], pixel-perfect for main game
- Integer positions; no subpixel movement, filtering, smoothing, or rotation interpolation
- UI/meter elements: crisp pixel-aligned shapes; nearest-neighbor / no blur

# Biome Background Wall Standard

Every major biome should eventually have a standardized library of seamless 64×64 background wall tiles.

## Standard

Each biome should define **four wall families**, with **three subtle layout variations** for each family.

Family structure:

- Standard
  - v01
  - v02
  - v03

- Biome-Specific Family
  - v01
  - v02
  - v03

- Secondary Family
  - v01
  - v02
  - v03

- Tertiary Family
  - v01
  - v02
  - v03

Total:
12 seamless 64×64 wall background tiles per biome.

The first family should always be **Standard**.

The remaining three families should be chosen specifically for the biome rather than being identical across the entire game.

Examples:

Sewer:
- Standard
- Slime Drips
- Cracked
- Damaged

Forest:
- Standard
- Roots
- Moss
- Ancient

Cave:
- Standard
- Wet
- Crystal
- Collapsed

Castle:
- Standard
- Ornate
- Cracked
- Ruined

Guidelines:

- These are long-term production goals, not blockers.
- Gameplay and level building always take priority over completing every background variation.
- It is perfectly acceptable during development to use Standard v01 repeatedly until additional variants are needed.
- Keep all variants cohesive with subtle changes while preserving the overall biome identity.
- Variants should feel like members of the same family, not entirely different walls.
- The purpose is to reduce visible repetition while maintaining a consistent visual style.

---

## Arcade Minigames
- Alien Commander and Snack Kid Superstar live under `assets/minigames/alien_commander/` and `assets/minigames/snack_kid_superstar/`.
- Both belong to the main Godot project. Do not add nested `project.godot` files or separate project launchers.
- Preserve their self-contained scenes, scripts, data, sprites, audio, and existing development checks. Run minigame scenes with F6 from the main project.
- Both use a 256x224 internal playfield. Alien Commander defines it in `scripts/ac_playfield.gd` under its minigame folder.
- Follow the Fat Kid master palette and pixel-perfect rendering rules.
- Snack Kid Superstar saves scores under `user://snack_kid_superstar/`; its existing local score seed and round JSON data are included by the export presets. Runtime saves and audit output must not write into the project.

## Controls / Inputs
- A = move left
- D = move right
- Space = jump
- (Kick input: keep whatever is already in Input Map / Player.gd)

## Coding Rules (VERY IMPORTANT)
- Prefer FULL-FILE outputs (complete scripts), not “add these lines somewhere”
- When asked to change behavior, first:
  1) Explain what you will change (brief plan)
  2) Then output the complete updated file(s)
- Do not invent node names or scene paths.
  - Use the exact paths present in code (e.g. $AnimatedSprite2D, $SFX_Jump, etc.)
- Do not suggest Godot 3 APIs (no KinematicBody2D).
- Keep changes small and testable. Avoid giant refactors unless explicitly requested.

## Player Script Notes (current style)
- Player is controlled by a state machine:
  - GROUND, WINDUP, AIR, LANDING, ATTACKING, HURT, DEAD
- Player uses animation-driven transitions and brief control locks
- Kick attack uses a kick hitbox Area2D (KickHitbox) enabled/disabled by code
- SFX nodes exist as AudioStreamPlayer2D children of the Player:
  - SFX_Jump, SFX_Land, SFX_KickWoosh, SFX_KickHit; use the exact current scene node names

## Folder Structure Expectations
- `scenes/player/player.tscn` is the shared player scene; `scripts/player/` contains its controller, camera, wall movement, and stamina/gas helpers, with `.uid` sidecars kept alongside scripts.
- `scenes/levels/` contains campaign levels. `scenes/tests/` contains retained arenas/showcases, including `WallJumpArena.tscn`, `CrumblingPlatformTest.tscn`, and `Level_1_1_FoliageTest.tscn`.
- `scripts/ui/` contains HUD scripts, including `hearts.gd`; `scripts/tests/` contains arena scripts.
- `scripts/game_state.gd`, `scripts/music_manager.gd`, and `scripts/scene_transition.gd` remain shared project services. Autoload configuration is in `project.godot`.
- `assets/` contains art/audio and the self-contained minigame folders; `resources/` contains debug and campaign configuration. Respect existing reusable resource locations unless relocation is requested.
- `.godot/` is engine-generated metadata; do not edit it manually.

## Art Readiness and Generated Foliage
- `generated_` marks art that still needs editing/review. Keep this prefix until the user approves the art for use. Do not silently promote generated art into campaign levels.
- Original outdoor trees remain in `assets/backgrounds/outdoor/trees_far/` and `trees_near/`. Far originals: `tree_far_small_01`, `tree_far_medium_01`, `tree_far_large_01`. Near originals: `tree_apple_01`, `tree_near_small_01`, `tree_near_medium_01`, `tree_near_large_01`.
- V02/V03 experimental trees and their reusable scenes are under the respective `assets/backgrounds/outdoor/generated_trees/` and `scenes/backgrounds/outdoor/generated_trees/` folders.
- Generated bushes and ground cover are under `generated_foliage/bushes/` and `generated_foliage/ground_cover/` in both outdoor assets and scenes.
- Later generated libraries are named `generated_foliage_v04`, `generated_foliage_v05`, and `generated_foliage_v06` in both outdoor assets and scenes.
- Level 1-1 uses the original tree placement and excludes the generated bushes/ground cover. Preserve the experimental appearance in the foliage test scenes; new art is brought into the level one piece at a time when the user chooses it.
- Aseprite foliage source folders V03-V06 were moved to `C:/GameProjects/Fatkid_Aseprite_Projects/`. The obsolete foliage-generator scripts were removed after backup; do not recreate them during routine cleanup.

## Project cleanliness
- Do not add unsolicited automated test suites, AI work-log documents, or project-local backup/checkpoint folders.
- Preserve the existing wall-jump arena, crumbling-platform test, foliage previews, and minigame checks. These are intentional development tools. Do not delete them solely because campaign scenes do not reference them.
- Preserve the backlog and story bible; follow their existing update rules.
- A static search finding no reference is not sufficient evidence to delete a resource. Check paths, UIDs, dynamic loads, exports, and manual editor/test use.
- The mall sandbox and its environment background, tilesets, and platform art are retired. Preserve the Mall Cop enemy, its projectile, artwork, sounds, and scripts for future use, along with all shared gameplay content.
- For approved moves, update references and guidance, retain UIDs, refresh the Godot import cache through the editor, and verify the affected scenes load.
- Remove empty folders only after checking hidden contents. Keep temporary verification scripts/results outside the project and remove them afterward.
- Update existing guidance instead of creating duplicate notes. Keep feature guides limited to current tuning and practical usage.

## Safety / Workflow
- Do not assume a backup exists; preserve unrelated staged and uncommitted work.
- For anything affecting multiple files:
  - Provide a short plan first
  - Then generate changes file-by-file
- If unsure about current project setup, ask for the relevant file contents or references.

## Tone / Output Preference
- Be concise, direct, and practical.
- Use bullet points and checklists.
- Avoid long explanations unless requested.

---

## Shorts Pickup — SpriteFrames (pickup_shorts_frames.tres)

Spritesheet: **res://assets/sprites/pickups/pickup_shorts.png** — 7 frames total (first 4 = idle, last 3 = collect/shrink).

**Godot editor steps:**

1. Open **res://scenes/pickups/pickup_shorts_frames.tres** (double-click in FileSystem).
2. In the bottom panel, **SpriteFrames** tab:
   - Click **Add frames from sprite sheet** (or **New Sprite Frames** then attach the texture).
   - Select **res://assets/sprites/pickups/pickup_shorts.png**.
   - Set **Frame size** to your single-frame size (e.g. if 7 frames in one row: width = image_width / 7, height = image height; adjust if your layout differs).
   - Click **Add 7 Frames** (or add row-by-row until all 7 frames are in the default animation).
3. **Rename or replace the default animation** to **idle**:
   - In the left list, select the default animation (e.g. "default") → rename to **idle**.
   - Ensure it contains **only frames 0–3** (first 4). Remove extra frames from this anim if needed (right-click frame → remove, or clear and re-add 0–3).
4. **Add animation "collect"**:
   - Click **Add Animation** → name it **collect**.
   - Add **frames 4, 5, 6** (last 3) to this animation. Set **Loop** off for collect.
5. Save the resource (Ctrl+S). The Pickup_Shorts scene’s AnimatedSprite2D already uses this resource; it will play "idle" at start and "collect" on pickup.

## Playtest Progression (direct level launches)

- Settings: `res://resources/debug/playtest_settings.tres` (edit in the Inspector). Applied by the `PlaytestBootstrap` autoload when a campaign level is the first scene of a debug run (Run Current Scene or main scene). Title screen, test arenas, New Game, transitions, deaths, and Continue never trigger it. Release builds ignore it.
- Modes:
  - **Automatic** (default): mandatory chest rewards and completion events from every catalogued level before the launched one. Read from the actual chest `reward_scene`s, so changing a chest's item changes later starting loadouts.
  - **Custom**: the seven ability toggles, `extra_max_hp`, and resource stage (None / Stamina / Gas). Records no chest history, so all chests stay collectible; an HP chest adds on top of the chosen HP. This is intended.
  - **Off**: ordinary progression.
- Campaign order: `res://resources/progression/campaign_catalog.tres`. To add a level, append a `CampaignLevel` entry in campaign order with its `scene_path`. Order is never inferred from filenames or level links.
- Optional/secret chest: set `required_for_progression = false` on the TreasureChest; Automatic starts skip it. Required chests need a unique `chest_id` and an ability pickup or Pizza Heart reward.
- Non-chest progression: add it to the catalog entry's **Completion Events** (stamina curse, gas transmutation, `completion_upgrade_ids`). Level 1-6 uses these for the curse, gas, and the Taco double jump. Do not add special cases to Player initialization.
- Invalid catalogs, chests, or settings print a `PLAYTEST:` error and leave ordinary progression untouched; nothing is partially granted. New ability IDs must also be added to `PlaytestSettings.ABILITY_IDS`.

## Backlog Maintenance

- Treat `docs/FatKidGame_Backlog_2026-07-16.md` as the single authoritative backlog for FatKidGame.
- When I complete, abandon, postpone, discover, or significantly change a task, remind me to update the backlog when appropriate.
- Do not interrupt for every small edit.
- Only remind me when a meaningful task state changes, such as:
  - after completing a task
  - before making a backup
  - before ending a work session
  - after discovering several new issues
  - after changing the project plan
- At those moments, briefly ask: “Should we update the backlog before moving on?”
- Do not repeatedly ask about the same update.
- Do not edit the backlog automatically unless I ask.
- When I ask to update it, inspect the existing file first.
- Avoid duplicate tasks.
- Preserve completed items and project history.
- Use concise, actionable wording.
- Mark completed tasks as:
  - [x] Task — completed YYYY-MM-DD
- For rejected tasks, preserve them with strikethrough and a short note rather than deleting them:
  - [ ] ~~Task~~ — decided against YYYY-MM-DD
- Put uncertain ideas under wording such as “Consider,” “Evaluate,” or “Decide whether.”
- Respect dependencies.
- Do not recommend sound, animation, or polish for a system, enemy, hazard, or item that does not exist yet.
- Prefer finishing and stabilizing existing work before opening large new systems.
- Keep risky project-wide systems later unless they are currently necessary.
- Keep only one main task under “Working On Now” unless I explicitly choose more.
- Suggest no more than two tasks under “Next Up.”
- Put blocked work under “Blocked / Waiting” with a short reason.
- Keep the backlog filename unchanged.
- Update the “Last updated” date inside the backlog when substantive edits are made.
- Preserve the Discord source date range and existing design notes.
- Do not reorganize or rewrite the entire backlog unless I explicitly request it.