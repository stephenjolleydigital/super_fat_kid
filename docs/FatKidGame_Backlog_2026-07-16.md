# FatKidGame Polish Backlog

Created: 2026-07-16

Last updated: 2026-11-04

## Current Priorities — October Playtest

Source: additional Discord notes dated 2026-07-01 through 2026-10-02, plus undated recent feedback supplied 2026-10-07. Tester: Deciheximal. Reports remain suspected issues until reproduced; dated completion notes below record subsequent development and verification.

### Working On Now

Design a stamina-increasing pickup. Decide its identity, appearance, and whether it increases maximum stamina permanently or restores stamina before implementation. Background bush artwork remains unfinished.

### Next Up

No follow-up task selected yet.

### Damage, Combat, and Respawning — High Priority

- [x] Check porcupine double hits immediately after landing; verify invulnerability starts correctly before deciding whether its duration needs increasing — completed 2026-10-09.
  - Focused landing checks confirmed no extra hit during protection. Damage invulnerability increased from 0.75 to 1.25 seconds; the repeated-hit problem from remaining on its solid back was addressed separately below.
- [x] Make damage-invulnerability flashing more obvious — completed 2026-10-09.
  - Regular alternation between full visibility and 20% opacity throughout damage protection.
- [x] Push the player off the porcupine's back when spikes deal damage — completed 2026-10-09.
  - Body remains solid. Spike hits push away from its body center at 260 px/sec sideways and 120 px/sec upward; exact-center hits push opposite player facing. Strengths are editable on the porcupine in the Inspector. Other enemies retain existing knockback through a shared optional hook in the player.
  - Landing checks from both sides and above, moving porcupines, and a normal kick passed. Developer playtested and accepted the feel; pit safety remains encounter-dependent.
- [x] Check porcupine rear damage coverage; tester could safely land on its rear end — completed 2026-10-11.
  - Developer manually reviewed the spike coverage and confirmed the reported issue is resolved; feedback likely involved a miscommunication. No further spike changes needed.
- [ ] Refine the player's hurtbox front edge; belly contact currently appears to precede kick contact. Evaluate bringing it inward, just behind the nose.
- [ ] Increase kick reach beyond the visible foot, with matching whoosh/hit feedback.
- [ ] Check the porcupine's vulnerable area height so kicks connect from the small ledge.
- [ ] Retest the pillar/porcupine encounter; both kicking and jumping over it should be practical. Adjust placement if needed.
- [x] Prevent repeated Webee kills at respawn points — completion confirmed 2026-10-30 by developer; actual completion date not recorded.
- [ ] Reassess wasp difficulty after damage protection and combat fixes.

### Controls and Ability Clarity

- [ ] Investigate weird shooting behavior while falling through a breakable platform (reported 2026-11-04). Reproduce the interaction and check the blaster animation and firing behavior during the fall.
- [x] Clarify that the sock unlocks higher jumps — completed 2026-10-18.
  - Developer reviewed the upgrade and considers it clear enough. No additional hint or encounter-placement change is needed for this item.
- [x] Clarify that running requires the Track Medal; tester tried both Shift keys before unlocking it. Preserve the successful encounter that immediately teaches running — completed 2026-10-11.
  - Developer considers this item complete. Input glyphs and tutorials are handled by their own separate system; no additional pickup hint is required for this task.
- [ ] Review when crouch unlocks; consider an earlier belt pickup or a pre-unlock Down action such as looking down.
- [x] Allow immediate movement after releasing crouch; standing-up animation may play while stationary but must be interruptible by movement — completed 2026-10-11.
  - Left/Right interrupts standing up immediately, including on the crouch-release frame; stationary standing up retains its animation.
  - Focused checks passed for both directions, stationary release, crouching, and attack locks. Manual playtest acceptance remains pending.
- [ ] Decide whether narrow platforms support dropping through and clarify their behavior.

### Hazards, Camera, and Level Readability

- [x] Add and tune a small, reversible camera-follow improvement — completed 2026-10-11.
  - Developer playtested and accepted the feel. Horizontal/vertical follow speeds are 12/14, airborne vertical dead zone is 16 pixels each way, and framing is raised by 8 additional pixels. Grounded framing recenters consistently after elevation changes.
  - Whole-pixel camera positioning, existing limits and respawn resets preserved; original-follow toggle available on Camera2D. All 40 camera checks passed. Tuning and rollback notes: `docs/Camera_Follow_First_Pass.md`. Encounter-specific mushroom and descent reviews below remain open.
- [ ] Make early pit jumps more forgiving by evaluating narrower gaps or horizontal jump reach; preserve the sock's purpose.
- [ ] Improve the first falling-apple encounter; consider a taller tree for reaction time and clearer falling-apple visibility.
- [x] Investigate the invisible bird in level 3 just before a tree; droppings appear to originate inside the screen without a visible bird — completed 2026-10-11.
  - Developer fixed the invisible bird and confirmed completion.
- [ ] Add web slowdown sound and animation; distinguish slowing from damage and wasp hits.
- [x] Review bee head contact that bounces without damage; decide whether it is intended and communicate it consistently — completed 2026-10-11.
  - Harmless head bounce is intentional and accepted; developer confirmed the existing behavior should stay as it is.
- [ ] Review vertical camera movement during mushroom bounces; keep the mushroom visible long enough to read its bounce animation, then verify the animation itself.
- [ ] Review the platform-to-coin descent and pit below; improve downward visibility and landing space where holding Left caused an unseen pit fall.

### Blocked / Waiting

- [ ] Review the pictured item's placement/access — waiting for the missing image or exact level/item identification. Both tester and developer found collection frustrating; do not guess the encounter.

### Feedback to Preserve

- Keep the existing visual direction; tester repeatedly praised the game's appearance and progress.
- Retain enemies with intentionally harmless contact; this feedback does not request universal contact damage.
- Landing pause felt acceptable after a short adjustment.
- Mushroom-launch expression remains low priority; see §2.

### Reported Development Progress

Developer reported these complete on 2026-09-20; recorded from notes, not a new playtest verification.

- [x] Add level-clear banner — completed 2026-09-20.
- [x] Add level-clear jingle — completed 2026-09-20.
- [x] Add jump and landing dust — completed 2026-09-20.
- [x] Add ground blaster-shot animation — completed 2026-09-20.
- [x] Convert JDSY track to chiptune — completed 2026-09-20; arrangement and further work remain in §12.1.

---



## Quick Wins

Safe, contained unfinished tasks for a short polish pass. Favor editor visibility, audio, UI, placement, and verification over large systems.



### 1. Fix or hide the persistent “Sock-jump upgraded” toast text visible in the Godot editor — completed 2026-08-04

- Original backlog item: Fix or hide the persistent “Sock-jump upgraded” toast text visible in the Godot editor
- Likely files: `scenes/ui/UI.tscn`, `scripts/ui/ui.gd`
- Estimated risk: Low
- Explanation: `UpgradeToast` now has scene-level `visible = false`; runtime `play_upgrade_toast()` still shows it during gameplay.



### 2. Fix the pause-menu close-game sound effect being cut off when the game exits — completed 2026-08-04

- Original backlog item: Fix the pause-menu close-game sound effect being cut off when the game exits
- Likely files: `scripts/ui/ui.gd`, `scenes/ui/UI.tscn`
- Estimated risk: Low
- Explanation: CLOSE GAME now awaits `SfxUiConfirm.finished` before `quit()`, so the confirm SFX is not cut off.



### 3. Improve title-screen select sound effect — completed 2026-10-09

- Original backlog item: Improve title-screen select sound effect
- Likely files: `scenes/ui/TitleScreen.tscn`, `scripts/ui/title_screen.gd`, `assets/audio/sfx/ui/`
- Estimated risk: Low
- Explanation: Resolved the reported loudness by setting title-menu selection to `-8 dB`. Title confirm/Start and pause selection/confirm/open/close also use `-8 dB`; existing sounds and playback timing are preserved.



### 4. Improve title-screen start sound effect — completed 2026-08-16

- Original backlog item: Improve title-screen start sound effect
- Likely files: `scenes/ui/TitleScreen.tscn`, `scripts/ui/title_screen.gd`, `assets/audio/sfx/ui/`
- Estimated risk: Low
- Explanation: START on the main title screen now plays a dedicated `sfx_ui_start_game_01` at `-3 dB`, with the START flash retimed to keep the transition fast and snappy. An attempted fade-out was removed because it cut the sound short; the scene change ends it naturally. Options/Exit still use `sfx_ui_confirm_01`. Tested in-game and accepted.



### 5. Prevent the player from falling from the sky when a level starts — completed 2026-08-04

- Original backlog item: Prevent the player from falling from the sky when a level starts
- Likely files: `scripts/Player.gd`
- Estimated risk: Low
- Explanation: Opening `jump_land` was a fake floor rising-edge on load. Landing presentation now runs only when `just_landed and state == State.AIR`, so grounded level starts stay in idle.



### 6. Start by placing bushes in Level 1_1

- Original backlog item: Start by placing bushes in Level 1_1
- Likely files: `scenes/levels/Level_1_1.tscn`, `assets/backgrounds/outdoor/bushes/`
- Estimated risk: Low
- Explanation: Bush art already exists (`bush_small/medium/large_01.png`) and only needs decorative placement in the level scene.



### 7. Fix or improve clouds appearing completely static when the player is standing still — completed 2026-08-05

- Original backlog item: Fix or improve clouds appearing completely static when the player is standing still
- Likely files: `scripts/backgrounds/outdoor_bg.gd`, level Background nodes
- Estimated risk: Low
- Explanation: Clouds now drift at `0.5 px/sec` while preserving camera parallax, so they keep moving when the camera is still.



### 8. Verify that falling apples damage the player / enemies / heal when landed / damage when kicked — completed 2026-08-04

- Original backlog item: Apple interaction verification checklist in §12.3
- Likely files: `scripts/objects/apple.gd`, `scenes/objects/Apple.tscn`, a test level with apples
- Estimated risk: Low
- Explanation: Code inspection confirmed kick, fall damage, heal, and enemy damage paths; no apple files were changed.



### 9. Tune the timing, duration, and damage area of the toxic gas — completed 2026-08-04

- Original backlog item: Tune the timing, duration, and damage area of the toxic gas
- Likely files: `scripts/objects/BounceToxicMushroom.gd`, `scenes/objects/BounceToxicMushroom.tscn`
- Estimated risk: Low
- Explanation: Gas duration, damage window, size, and cooldown were implemented, tested in-game, and accepted; no separate gas scene required.



## 1. Bugs, Annoyances, and Small Fixes

These are good early targets because they are contained and unlikely to destabilize larger systems.



- [x] Prevent the player from falling from the sky when a level starts

- [x] Fix or hide the persistent “Sock-jump upgraded” toast text visible in the Godot editor

- [x] Fix the pause-menu close-game sound effect being cut off when the game exits

- [x] Improve title-screen select sound effect — completed 2026-10-09.
  - Title and pause menu selection, confirm, Start, and pause open/close sounds unified at `-8 dB`.

- [x] Adjust apple fall/ground-impact and player ground-landing sound volumes — completed 2026-10-09.
  - Apple fall and ground impact reduced by 3 dB to `-3 dB`. Player landing was halved from `-4 dB` to `-10.02 dB`, then raised 2 dB to `-8.02 dB`. Scene settings verified; no playback behavior changed.

- [x] Improve title-screen start sound effect
  - START now plays a dedicated `sfx_ui_start_game_01` at `-3 dB` with a retimed flash and a fast transition; generic confirms still use `sfx_ui_confirm_01`.

- [ ] Implement the newer player fart sound effects
  - Status: Double jump still plays a single wired `SFX_Fart` stream (`fart.wav`); no confirmed set of newer alternate fart takes found in use.

- [x] Fix or improve clouds appearing completely static when the player is standing still
  - Clouds now drift at `0.5 px/sec` while preserving camera parallax.



## 2. Existing Player Polish

Do these before adding too many more movement or combat systems.



- [ ] Create a better player idle animation

- [ ] Tune or remake the player fart animation

- [ ] Make the fart animation faster if that improves the feel

- [ ] Clean up the player’s existing movement presentation where needed

- [ ] Improve the three-frame kick animation; consider a fourth frame and improve the kick whoosh.

- [ ] Consider a landing/shooting animation for jump shots fired just before landing — later polish.

- [ ] Consider a distinct mushroom-launch expression: hair up, wide eyes, open mouth ("WoaAAAh!") — low priority, separate from the normal jump pose.

- [ ] Consider a boss-encounter shock/awe animation inspired by Battletoads — optional polish.

Animation workflow note (2026-09-30): change a small number of animations at a time so mistakes remain easy to isolate.



## 3. Existing World 1 Visual Polish

These improve content that already exists and can be handled before building major new systems.



- [ ] Clean up title-screen artwork

- [ ] Place bushes and other decorative objects in World 1 levels
  - Status: Bush PNGs exist under `assets/backgrounds/outdoor/bushes/`, but no bush nodes are placed in World 1 level scenes yet.

- [ ] Start by placing bushes in Level 1_1
  - Status: Same as above — assets ready, Level_1_1 has no bush instances.

- [ ] Clean up the existing bush artwork if needed

- [ ] Make some foreground-style tree objects larger because the current proportions feel strange

- [ ] Decide whether the background tree layers in Level 1_1 should read more clearly as trees or as mountains

- [ ] Rework the Level 1_1 background layers accordingly

- [x] Implement the secondary World 1 sky background

- [x] Make Levels 1_2 and 1_3 use the same outdoor sky/cloud/hill background as Level 1_1
  - Same sky/cloud/hill stack, parallax, and cloud idle drift as Level 1_1; FarTrees/NearTrees were not copied.

- [ ] Finish fall/autumn trees for Levels 1_4, 1_5, and 1_6
  - Status: `tree_apple_01` appears in later World 1 levels; unclear whether autumn tree art is considered finished for 1_4–1_6.

- [ ] Add the completed autumn trees to Levels 1_4, 1_5, and 1_6
  - Status: Some apple/near-tree sprites are already placed; a dedicated finished autumn set is not clearly complete.

- [ ] Improve the HUD hearts

- [ ] Improve the HUD money display

- [x] Create a reusable finish flag with timed rise and completion sound effects — completed 2026-09-01
  - `FinishFlag.tscn` now owns its animation, `-8 dB` sound playback, midpoint timing, and one-shot guards; Level 1_1 uses the reusable object.

- [ ] Place the reusable finish flag in the remaining levels
  - Status: Other existing levels still use their original invisible `EndTrigger` nodes and need the reusable flag positioned at their exits.



## 4. Existing Hazards and Enemy Polish

Finish incomplete content before designing too many new hazards or enemies.



- [ ] Finish the bramble hazard
  - Status: No bramble scene, script, or sprite set found in the project.

- [ ] Finish the spike hazard
  - Status: No dedicated spike hazard scene/script found (hedgehog contact spikes are enemy-only).

- [x] Add a damage hitbox to the gnome boss’s hands or arms during casting
  - Active during casting and tested in-game.

- [ ] Make the casting hitbox prevent the player from standing close and spamming attacks
  - Status: Casting arm/hand damage hitbox now exists; confirm it adequately prevents close-range attack spam.

- [ ] Continue boss improvements — developer's ongoing development note, not a specific tester complaint; choose the next concrete improvement before expanding scope.

- [x] Make the bird killable — completed 2026-10-19.
  - Existing player attacks kill it in one hit: hurt → fall → ground-impact explosion → removal. Falling and explosion are harmless; poop stops on defeat. New sheet, aligned collision/hurtbox, and kick hitstop integrated; developer playtested and confirmed it works.
- [x] Use camera-based bird activation and tidy the Level 1-4 encounter — completed 2026-10-19.
  - Adjustable 32-pixel activation margin with separate offscreen cleanup. Replaced the original Hedgehog2 with Bird3 above its position; remaining hedgehogs are numbered left to right.
- [x] Create and integrate bird hurt/death and ground-explosion sound effects — completion confirmed 2026-10-30; actual completion date not recorded. Hurt and ground-impact explosion audio are wired into the bird scene and script.

- [ ] Make the BeeSwarm killable eventually
  - Status: BeeSwarm activates and damages on contact; no killable HP/hurt path in `bee_swarm.gd`.



## 5. Title Screen and Options

The base menu should be stable before adding a large number of settings.



- [x] Add sound controls to the Options menu
  - Master and Music volume controls work and settings persist.

- [ ] Decide what other settings belong in Options

- [ ] Add other appropriate Options menu settings

- [ ] Further polish title-screen presentation and feedback



## 6. World 2 Foundations

Build the environment and reusable systems before heavily decorating individual levels.

### Environment Art

#### Sewer Wall Background Library

- [x] Standard v01
- [ ] Standard v02
- [ ] Standard v03

- [ ] Slime Drips v01
- [ ] Slime Drips v02
- [ ] Slime Drips v03

- [ ] Cracked v01
- [ ] Cracked v02
- [ ] Cracked v03

- [ ] Damaged v01
- [ ] Damaged v02
- [ ] Damaged v03

Use Standard v01 repeatedly for current development. The remaining variants are long-term polish work and should never block gameplay implementation or level construction.



- [ ] Create background art for Level 2_1

- [ ] Create background art for Level 2_2

- [ ] Create background art for Level 2_3

- [ ] Continue World 2 background art for later sewer levels

- [ ] Decide whether the sewer tileset needs to be created, expanded, or rebuilt

- [ ] Create or expand the sewer tileset

- [ ] Create reusable sewer background objects

- [ ] Add pipes and other sewer environment pieces

- [ ] Add pipes that drip toxic fluid
  - Status: `ToxicCeilingDrip` hazard exists, but no pipe prop/scene that emits drips was found.

- [ ] Turn the dripping toxic fluid into a gameplay hazard
  - Status: `ToxicCeilingDrip` already damages via `enemy_attack` while falling; still needs pipe-mounted placement for World 2.



## 7. Toxic Mushroom

The mushroom sprite already exists, so behavior and effects come next.



- [x] Program the toxic gas emitted by the toxic bounce mushroom

- [x] Create the toxic gas effect or scene

- [x] Make the toxic gas damage the player

- [x] Connect the gas effect to the toxic mushroom animation and behavior

- [x] Tune the timing, duration, and damage area of the toxic gas



## 8. Checkpoint System

This is a reusable gameplay system and should be designed before placing checkpoints throughout many levels.



- [ ] Design a cool mid-level checkpoint system

- [ ] Decide whether the checkpoint should resemble a flag, post, sign, or another memorable object

- [ ] Take inspiration from classic Mario checkpoint systems without directly copying them

- [ ] Implement checkpoint activation

- [ ] Implement checkpoint respawning

- [ ] Create checkpoint art and animation

- [ ] Add checkpoint sound effects after the system and animation are working

- [ ] Place checkpoints around the halfway point of appropriate levels



## 9. Future Player Abilities

These should be implemented carefully and one at a time.



### Wall Kick

- [ ] Design the wall-kick ability

- [ ] Create the item that permanently unlocks wall kick

- [ ] Create the wall-cling pose or animation

- [ ] Create the wall-kick pose or animation

- [ ] Implement wall detection

- [ ] Implement wall cling

- [ ] Implement wall kick

- [ ] Ensure wall kick does not reset the taco/fart double jump

- [ ] Tune wall-kick control and momentum

- [ ] Add wall-kick sound effects only after the movement works correctly



### Fire Fart

- [ ] Design the fire-fart upgrade

- [ ] Create the fire-fart animation

- [ ] Implement fire-fart behavior

- [ ] Add damage, collision, and visual effects

- [ ] Add fire-fart sound effects after behavior and animation are stable

### Later Combat Ideas

- [ ] Finish the planned aerial kick animation/upgrade; define the unlock and behavior before final animation.
- [ ] Consider a belly attack as a future ability — idea only.



## 10. Possible Later Systems

These may affect many scripts and levels, so they should wait until the current player systems are stable.



- [ ] Consider implementing a stamina system

- [ ] Decide what actions would consume stamina

- [ ] Decide whether stamina genuinely improves the game

- [ ] Prototype stamina in isolation before integrating it widely

- [ ] Avoid committing to stamina until its effect on movement, combat, upgrades, and level design is understood



## 11. Enemy Ideas and Unsorted Art

These are discovery tasks, not immediate production commitments.



- [ ] Review accidental enemy designs found in Aseprite projects

- [ ] Save the promising designs into a clearly named concept folder

- [ ] Discard or archive weak designs

- [ ] Decide whether any of the designs fit World 1, World 2, or a later world

- [ ] Do not create full animations or sound effects until an enemy concept is selected and its gameplay role is defined



## Suggested General Order

1. Fix small bugs and editor annoyances

2. Finish incomplete existing hazards and enemy behavior

3. Polish current player animations and sound

4. Improve existing World 1 visuals and HUD

5. Finish core Options menu functionality

6. Build World 2 environmental foundations

7. Complete the toxic mushroom behavior

8. Build the checkpoint system

9. Implement one new player ability at a time

10. Revisit large systems like stamina only after the core game is stable



# 12. Discord Ideas and Future Features



Source date range: 2026-02-18 to 2026-07-16  

Discord username: Death Keeper



These notes came from older Discord discussions. Some are active ideas, while others are only possibilities. Items here should not automatically take priority over the earlier backlog sections.



---



## 12.1 Audio and Music Ideas



### Boss Victory Theme



- [ ] Compose a short boss-victory theme

- [ ] Use the triumphant feeling of “For Shovelry!” from Shovel Knight as inspiration

- [ ] Keep the melody and arrangement original

- [ ] Decide whether all bosses use one shared victory theme or receive variations



### Music and Sound Tools to Revisit



- [ ] Test Dawesome LOVE to see whether it is useful for converting existing tracks into a chiptune style

- [ ] Revisit Bfxr for quick retro sound-effect generation

- [ ] Only adopt new audio tools when they improve the current Reaper workflow

- [ ] Finish arranging and refining the JDSY chiptune conversion; conversion reported complete 2026-09-20.



---



## 12.2 Enemy and Boss Concepts



### Sewer Boss Concept



- [ ] Locate and review the saved sewer-boss concept images

- [ ] Decide whether the design still fits the current World 2 direction

- [ ] Define the boss’s gameplay role and attacks before creating final animation

- [ ] Avoid producing sound effects until the boss behavior exists



### Mushroom Mimic



- [ ] Create a mushroom mimic based on the existing bounce mushroom

- [ ] Make it initially resemble a normal bounce mushroom

- [ ] Have it transform into a small mushroom creature

- [ ] Make the revealed creature chase or attack the player

- [ ] Give the player enough warning for the trick to feel fair

- [ ] Reuse existing mushroom assets where practical before creating new ones

- [ ] Add final animation and sound only after the behavior works



### Splitting Slime Variant



- [ ] Create a slime variant that splits into two smaller slimes when defeated

- [ ] Decide whether the original slime dies or transforms
  - 2026-07-01 clarification: reskin the existing slime and split into two smaller slimes "on death."

- [ ] Give the smaller slimes reduced size, health, or attack strength

- [ ] Prevent repeated splitting from causing uncontrolled enemy multiplication

- [ ] Decide whether this belongs in World 2 or a later world



### Mall Cop Donut Drop



- [ ] Decide whether the mall cop should always drop a donut on death

- [ ] Check whether guaranteed healing would make mall-cop encounters too rewarding

- [ ] Consider using a high drop chance instead of a guaranteed drop



### Bird and BeeSwarm



These are already listed earlier in the backlog.



- [x] Eventually make the bird killable — completed 2026-10-19.
  - Completed; see §4 for combat, activation, encounter placement, and completed bird sound effects.

- [ ] Eventually make the BeeSwarm killable
  - Status: Same as §4 — contact hazard only; not killable yet.



---



## 12.3 Apple Interaction Expansion



Most of the apple system already exists. Treat this as a checklist for remaining behavior rather than a request to rebuild it.



- [x] Verify that falling apples damage the player

- [x] Verify that falling apples damage enemies

- [x] Verify that landed apples heal the player

- [x] Verify that kicked apples damage enemies

- [ ] Decide whether enemies should be able to eat landed apples for health
  - Status: Landed-apple code already attempts `_heal_enemy` / enemy collect; decide whether that stays intentional.

- [ ] Decide which enemy types would logically interact with food

- [ ] Consider an achievement for killing an enemy with a kicked apple

- [ ] Preserve memorable apple interactions even if they only appear in a few designed situations



---



## 12.4 Enemy and Environmental Interactions



- [ ] Allow selected enemies, hazards, food items, and projectiles to interact with one another

- [ ] Favor authored, readable interactions over trying to simulate every possible combination

- [ ] Add enemy-versus-enemy damage only where it creates clear and entertaining results

- [ ] Test each interaction for accidental exploits or softlocks



### Webee Secret



- [ ] Recover or redefine the planned Webee secret interaction

- [ ] Decide whether it is an environmental interaction, hidden animation, collectible trigger, or joke

- [ ] Do not implement it until the intended behavior is clearly described



---



## 12.5 Collectibles, Secrets, and Optional Content



### Collectible Paintings



- [ ] Consider adding collectible paintings or illustrations

- [ ] Create paintings themed around:

  - outdoor areas

  - sewer areas

  - dungeon areas

  - mall areas

- [ ] Consider paintings based on enemies, items, characters, or game events

- [ ] Create a gallery or collection menu where found paintings can be viewed

- [ ] Decide whether collectible paintings must follow the normal game palette

- [ ] Allow palette exceptions when strict remapping damages the artwork

- [ ] Consider subtle animation for special paintings

- [ ] Decide whether collecting all paintings unlocks a secret spell or reward

- [ ] Do not commit to a completion reward until the collectible count is known

Art workflow note (2026-07-18): evaluate [SpriteFusion Pixel Snapper](https://github.com/Hugo-Dz/spritefusion-pixel-snapper) for grid cleanup of generated paintings. The ice-castle painting was being cleaned up and remapped to the master palette; completion not reported. Tool capabilities have not been verified in this backlog update.

### Treasure-Chest Magician

- [ ] Consider a Ghouls 'n Ghosts-inspired magician that appears from a chest and temporarily transforms the player into an animal; still award the chest treasure.
- [ ] Decide the transformation duration and whether firing is disabled; implement behavior before producing final effects.



### Dwarven Scrolls



- [ ] Create collectible dwarven scrolls

- [ ] Preserve the joke that many dwarven scrolls exist, but only one is on planet Earth

- [ ] Decide whether scrolls contain lore, jokes, hints, spells, or collectible text

- [ ] Decide whether the Earth scroll has a gameplay function or is purely comedic



### Kickable and Bombable Walls



- [ ] Add selected kickable secret walls
  - Status: `BreakableWall_Left/Right` already exist as kick-breakable walls; secret-wall authoring/placement is still open.

- [ ] Add selected bombable secret walls

- [ ] Give destructible walls readable visual clues

- [ ] Decide whether some walls can be destroyed by both methods

- [ ] Avoid teaching players to attack every wall in the game



---



## 12.6 Player Movement and Upgrade Ideas



### Petroleum Jelly Slide Upgrade



- [ ] Design a Petroleum Jelly Tin upgrade item

- [ ] Unlock sliding after collecting it

- [ ] Trigger sliding by crouching while running

- [ ] Decide whether sliding can damage enemies

- [ ] Use sliding to pass under low obstacles where appropriate

- [ ] Decide whether the player can jump out of a slide

- [ ] Tune slide speed, stopping, turning, and momentum

- [ ] Implement movement behavior before creating final animation and sound

- [ ] Decide whether sliding is a committed upgrade or only an experimental idea



### Crouch-Cancel Jump Technique



- [ ] Preserve the ability to cancel crouching into a jump if it feels good

- [ ] Consider granting a small height or distance benefit

- [ ] Keep it as optional movement tech rather than a normal progression requirement

- [ ] Make sure accidental crouch-cancel behavior does not lock animations

### Temporary Ghost Form

- [ ] Consider a kickable tombstone that sends a ghost projectile into the player, granting five seconds of invincibility and flight for platforming challenges — optional future system.

### Feather Safety Item

- [ ] Consider a feather granted by a rare bird drop or Body-attribute level-up; decide the acquisition route first.
- [ ] Prototype Spelunky-style fall protection: when descending speed reaches the fall-damage threshold, wings slow descent until landing, once per level.
- [ ] Define consumption/reset rules alongside §12.10; defer until the relevant drop, attribute, and fall-damage dependencies are settled.



### Fart Particle Trail



This overlaps with the earlier fart-animation and fire-fart tasks.



- [ ] Consider adding pixel-art fart particles during fart-powered movement

- [ ] Make the particles drift upward and fade

- [ ] Emit particles mainly during actual fart abilities rather than constantly

- [ ] Consider changing fart particles through Butt-stat upgrades

- [ ] Consider interactions between fart clouds and fire

- [ ] Integrate this with the fire-fart upgrade rather than creating a separate conflicting system

- [ ] Avoid generic smooth particles that clash with the pixel-art style



---



## 12.7 Food, Hunger, Gas, and Stamina Ideas



These systems could affect movement, combat, UI, food balance, and level design. They should remain experimental until the core player systems are stable.



### Overfull Debuff



- [ ] Consider an “Overfull” condition when the player eats while already full

- [ ] Temporarily slow or briefly stun the player after overeating

- [ ] Consider reducing stamina recovery while Overfull

- [ ] Consider a Body-stat perk that grants immunity to Overfull

- [ ] Decide whether the mechanic creates an interesting choice or merely punishes healing pickups



### Hungry Debuff



- [ ] Consider a “Hungry” condition after remaining at low health without eating

- [ ] Make Hungry reduce gas-resource recovery

- [ ] Cure Hungry immediately when food is eaten

- [ ] Define a clear delay before Hungry activates

- [ ] Communicate Hungry through UI, animation, or sound

- [ ] Avoid implementing Hungry until food frequency and gas recovery are stable



### Resource-System Decisions



- [ ] Decide whether stamina and gas are separate resources

- [ ] Decide which actions consume stamina

- [ ] Decide which fart abilities consume gas

- [ ] Decide how each resource recovers

- [ ] Avoid implementing Overfull or Hungry before the resource model is finalized



---



## 12.8 Weapons, Mana, and Character Builds



### Mana Resource



- [ ] Consider combining bomb ammunition and energy-weapon ammunition into a Mana resource

- [ ] Connect Mana primarily to Brain-oriented builds

- [ ] Decide how Mana is restored

- [ ] Decide whether bombs and energy weapons should actually share one resource

- [ ] Avoid implementing Mana before bombs and at least one energy weapon exist



### Brain Perks



- [ ] Consider a Brain perk that grants immunity or resistance to bombs

- [ ] Clarify whether it affects the player’s bombs, enemy bombs, or all explosions

- [ ] Avoid making major explosive hazards harmless



### Core Combat Principle



- [ ] Keep the game beatable using kick and punch
  - Revisit this older direction: 2026-08-01 notes favor a blaster instead of punch for game feel. Blaster work is already underway, including the ground-shot animation reported complete 2026-09-20; do not duplicate the weapon system.

- [ ] Treat later weapons as alternate tools or build options

- [ ] Avoid making enemies or progression gates that secretly require a later weapon



### Possible Later Weapons



These are concepts, not active production tasks.



- Zapper or energy gun

- Sword

- Bombs



---



## 12.9 Minigames and Progression Gates



### Minigame Door Unlocks



- [ ] Allow certain doors to open after completing an arcade minigame

- [ ] Decide whether the player enters an arcade machine, terminal, or separate challenge scene

- [ ] Make failed minigame attempts quick to restart

- [ ] Avoid interrupting normal platforming too frequently

- [ ] Decide whether minigame gates control main progression, secrets, or optional rewards



### Existing Arcade Minigame Notes



- [ ] Review the older arcade-minigame design document
  - Status: Alien Commander exists under `assets/minigames/alien_commander/` and is not wired into main level flow yet.

- [ ] Compare it with the current Alien Commander implementation

- [ ] Identify which ideas are complete, outdated, or still useful

- [ ] Avoid accidentally creating two overlapping versions of the same minigame



---



## 12.10 Saves, Death, Lives, Continues, and Checkpoints

Implementation update (2026-10-21): three lives including the current attempt; normal death restarts the level, zero shows Game Over. Unlimited free Continue restores three lives/full health at world start, including 1-1 from the World 1 boss. Money, abilities, max-HP bonuses, collected world lives, and chest state persist; fresh title-screen Start clears the playthrough. Ordinary quarters still respawn.

- [x] Add lives HUD, immediate +1 collection with pause-aware flight effect, persistent placed lives, and recoverable death transitions — completed 2026-10-21.
- [x] Keep opened chests open and preserve unclaimed permanent rewards; suppress claimed chest rewards — completed 2026-10-21.
- [ ] Place and balance extra-life pickups; each placed instance needs a unique pickup_id.
- [ ] Add enemy extra-life drop chances using transient pickup mode. Extra lives are not chest rewards.
- [ ] Playtest overall difficulty and quarter farming with world-start Continues; future arcade checkpoints may shorten replay.
- Verification: 41 temporary Godot 4.4.1 runtime checks passed, including injected transition-failure recovery; native 480×270 HUD and Game Over renders inspected. Missing/duplicate-ID and prohibited-chest tests emitted their expected errors. Difficulty and encounter balancing still need human playtesting.
- Practical setup: each level's SessionEntry specifies world_start; each chest has a unique chest_id. IDs must remain stable for future saves. Missing/duplicate identities disable rewards and report errors.




Reference direction: a structure similar to Kero Blaster.



This should be designed alongside the checkpoint system already listed earlier.



- [ ] Study how Kero Blaster handles saves, lives, continues, death, and item respawning

- [x] Decide whether FatKidGame should use lives — approved and implemented 2026-10-21.

- [x] Decide what resets when the player dies — approved and implemented 2026-10-21.

- [x] Decide what persists after death — approved and implemented 2026-10-21.

- [x] Decide what resets after a continue or game over — approved and implemented 2026-10-21.

- [ ] Decide whether permanent upgrades ever need to be recollected

- [x] Decide how quarters behave after death — approved and implemented 2026-10-21.

- [ ] Decide how checkpoints interact with lives and continues

- [x] Document the final death and persistence rules before applying them across all levels — approved and implemented 2026-10-21.

Updated direction (2026-07-01): the intended structure is almost exactly like Kero Blaster for continues, lives, saves, and item respawning on death. Exact rules still need documentation; the reference is a design intention, not a verified specification.

Updated lives economy (2026-09-15): lives should be plentiful, with resource management providing the constraint.

- [ ] Design a collectible currency that awards an extra life for every ten collected; decide whether this is distinct from quarters.
- [ ] Use collectible trails to guide players and hint at secrets, inspired by Donkey Kong Country.
- [ ] Consider requiring currency to save; decide cost, availability, and safeguards before implementation.



---



## 12.11 NPC and Dialogue Direction



- [ ] Make most NPC conversations optional

- [ ] Allow players to walk past NPCs without entering dialogue

- [ ] Give NPCs useful hints, jokes, flavor, or world information

- [ ] Avoid placing essential controls or instructions only in optional dialogue

- [ ] Keep most conversations concise

- [ ] Consider a visual indicator for NPCs with especially useful information

- [ ] Decide later whether NPCs can offer side quests

Reaffirmed 2026-07-02: most conversations should be optional and provide useful hints; players should be able to breeze past them to keep playing.



---



## 12.12 Aseprite and Art Organization



This expands the earlier task about accidental enemy designs.



- [ ] Organize Aseprite project files

- [ ] Separate active production art from experiments

- [ ] Create or maintain clear folders for:

  - player

  - enemies

  - bosses

  - items

  - hazards

  - tilesets

  - backgrounds

  - UI

  - concepts

  - archived work

- [ ] Use consistent filenames

- [ ] Use clear version suffixes only when necessary

- [ ] Review accidental enemy designs

- [ ] Move promising enemy concepts into a dedicated concept folder

- [ ] Archive or delete obvious failed experiments

- [ ] Avoid leaving important finished source files buried inside unnamed Aseprite projects



---



## 12.13 Palette and Art-Direction Notes



Older Discord notes refer to the original approximately 32-color palette. The current expanded master palette and current project rules take priority.



- [ ] Preserve a cohesive global palette

- [ ] Add colors when genuinely necessary

- [ ] Avoid forcing art into bad-looking remaps solely to obey an outdated color limit

- [ ] Consider controlled palette exceptions for collectible paintings and special illustrations

- [ ] Document any global tinting, fading, or color-modulation effects used in Godot



### Side-View Perspective Rule



- [ ] Keep playable surfaces readable as flat side-view platforming geometry

- [ ] Avoid decorative perspective that makes floors appear traversable in depth

- [ ] Use pseudo-depth mainly in backgrounds and noninteractive scenery

- [ ] Keep AI-generated and hand-drawn assets visually coherent

- [ ] Make sure decorative objects do not confuse the player about collision



---



## 12.14 Design References and Principles



### Celeste Reference



Use Celeste as a focused reference when studying:



- movement feedback

- animation efficiency

- readable hazards

- respawn speed

- hidden movement techniques

- economical polish



- [ ] Reference specific solutions rather than copying Celeste broadly

- [ ] Compare the game’s movement and hazard feedback to Celeste when something feels unclear



### Momentum and Player Feel



- Preserve deliberate momentum as part of the game’s identity

- Accept that the player may feel heavier than a conventional platform hero

- Make the controls learnable and consistent

- Avoid confusing “weighty” with sluggish, delayed, or unreliable

- Test movement with new players who do not already understand the intended physics

### Screen Shake Preference

- [ ] ~~Use routine screen shake as general gameplay feedback~~ — mostly disabled by developer 2026-07-24; disliked in testing. Keep the existing separate script available.
- [ ] Consider localized ground shaking for specific events, inspired by Ghouls 'n Ghosts, rather than enabling broad camera shake by default.



### Memorable Interaction Principle



- Keep unusual interactions even when they only work in a few designed scenarios

- Treat small interactions as memorable flourishes rather than systems that must work everywhere

- Prefer a small number of polished interactions over a universal simulation

- Use Spelunky as inspiration for readable environmental chain reactions without copying its full systemic complexity



---



## 12.15 References and Tools to Revisit



These are resources, not automatic production tasks.



- Bfxr

- Instatileset

- Tileset Builder

- Leonardo.ai

- Pixel Engine

- SpriteLoop

- Dawesome LOVE

- Kero Blaster

- Celeste

- Vagante

- Spelunky



- [ ] Test a new tool only when it solves a current production problem

- [ ] Avoid changing workflows simply because a new AI art or animation tool looks impressive

- [ ] Back up the project before testing tools that modify game assets or project files

### Export Size — Near-Finish Evaluation

- [ ] Measure final exported build size before considering a custom Godot build with unused modules removed.
  - Developer notes cite a roughly 50 MB game and a Reddit claim of a roughly 30 MB export baseline; these are unverified observations, not requirements. Evaluate the benefit near completion before committing to engine-build maintenance.



---



## 12.16 Already Implemented or Partially Implemented Ideas



Do not create duplicate tasks for these without first checking the current game.



- Sewer slime already exists

- Toxic mushroom bounce, baked `gas_release` visual, gas damage/animation wiring, and accepted duration/window/size/cooldown are implemented

- Bounce mushroom already exists

- Apple falling, healing, kicking, and enemy damage are verified in code

- Fire fart is already listed earlier

- Stamina is already listed earlier as a possible later system

- Accidental enemy designs are already listed earlier

- Checkpoints are already listed earlier

- Spikes are already listed earlier

- Breakable or kickable walls already exist in some form

- Fart animation and new fart sound effects are already listed earlier

- Toxic mushroom behavior is already listed earlier



---



## 12.17 Ideas Requiring Clarification Before Production



- [ ] Define the Webee secret interaction

- [ ] Locate and review the sewer-boss concept images

- [ ] Decide whether collectible paintings are definitely part of the game

- [ ] Decide whether dwarven scrolls are lore, jokes, hints, or gameplay items

- [x] Decide whether lives and continues are still wanted — approved 2026-10-21; implemented rules are in §12.10.
  - Direction reaffirmed by July/September notes: Kero Blaster-style lives/continues with plentiful extra lives. Resolve exact persistence and currency rules in §12.10 rather than reopening the broad choice.

- [ ] Decide whether stamina and gas both exist

- [ ] Decide whether Mana is still intended for bombs and energy weapons

- [ ] Decide whether enemies should eat apples

- [ ] Decide whether sliding is a committed upgrade

- [ ] Decide whether NPCs will offer side quests

