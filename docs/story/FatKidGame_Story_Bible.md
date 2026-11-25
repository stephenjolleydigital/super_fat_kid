# FatKidGame Story Bible

**Version:** 0.1  
**Created:** 2026-07-17  
**Purpose:** Practical story, world, dialogue, quest, progression, and story-connected gameplay reference for FatKidGame.

---

## 1. How to Use This Document

This is a working production document, not a final lore encyclopedia.

Use it to:

- Keep story ideas connected to actual levels, mechanics, items, NPCs, bosses, and implementation tasks.
- Preserve small jokes, visual gags, inventory descriptions, and optional interactions.
- Separate implemented facts from plans, strong ideas, loose brainstorms, and archived concepts.
- Avoid accidentally treating every brainstorm as canon.
- Track decisions that affect art, level design, dialogue, code, and progression.
- Keep the story foundation strong enough to build from without polishing every detail too early.

### Status Labels

Use these labels whenever adding or changing an idea:

- **Locked / Implemented** — Already in the game or firmly established.
- **Current Plan** — The intended direction, but still adjustable.
- **Strong Idea** — A promising idea worth preserving and developing.
- **Loose Idea** — A brainstorm that should not be treated as canon.
- **Needs Decision** — A choice that matters and has not been resolved.
- **Contradiction to Resolve** — Two sources or plans disagree.
- **Cut / Archived** — No longer active, but preserved for history.

### Scope Rule

Do not expand every idea into a large system or long explanation.

A funny inventory description, one-room interaction, strange NPC, or single-use visual joke can be valuable without becoming a major mechanic.

### Story Quality Target

Aim for a strong, usable 70–80% foundation. Only over-polish decisions that would cause major future rework if left unclear.

---

# 2. High-Level Premise

## Current Premise

**Current Plan**

School lets out. Fat Kid begins the game trying to get home.

What starts as a normal trip through the school grounds and neighborhood gradually turns into a larger journey. After reaching home, Fat Kid leaves again and heads toward a sewer entrance guarded by a Gnome. Defeating or bypassing the Gnome leads into the sewer and begins World 2.

The exact reason Fat Kid must enter the sewer is not yet established.

## Story Shape

**Current Plan**

The game should use a simple central journey supported by:

- Short scenes
- Level-to-level transitions
- Expressive animation
- Inventory items
- Optional NPC interactions
- Small quests
- Environmental details
- Boss encounters
- Shops
- Arcade machines
- Running jokes
- Permanent upgrades that feel connected to the world

The game should not rely on long cutscenes, heavy exposition, or a complicated mythology.

## Immediate Story Goals

1. Establish Fat Kid’s normal world: school, neighborhood, home, Mom.
2. Give the player an optional early quest with the Report Card.
3. Create a believable but funny reason for Fat Kid to leave home again.
4. Connect the Gnome and sewer entrance to that reason.
5. Let World 2 expand the mystery or problem without requiring a giant plot reveal.

---

# 3. Tone and Creative Rules

## Core Tone

**Locked / Implemented**

FatKidGame should feel:

- Funny
- Strange
- Charming
- Slightly grubby
- Suburban
- Midwestern
- Retro
- Physical
- Gamey
- Memorable
- Occasionally gross
- Sincere underneath the jokes

The humor should feel like it naturally belongs in the world. Not every line needs to be a punchline.

## Storytelling Rules

**Current Plan**

- Keep dialogue short enough for a side-scrolling action platformer.
- Avoid generic fantasy exposition.
- Let Fat Kid’s actions and animations communicate personality.
- Use awkward, mundane, and specific details.
- Preserve strange little ideas even when they do not affect the main plot.
- Make locations feel connected rather than like unrelated stages.
- Keep readable side-view geography.
- Avoid realistic architecture that becomes confusing in a flat 2D game.
- Let players walk past most NPCs without being forced into conversation.
- Do not hide essential control information only in optional dialogue.
- Prefer a small number of memorable interactions over a universal simulation.
- Do not force every enemy, item, or room to have a lore explanation.

## Fat Kid’s General Character Direction

**Current Plan**

Fat Kid can be:

- Mischievous
- Impulsive
- Hungry
- Opportunistic
- Slightly rude
- Derpy
- Surprisingly capable
- More expressive through behavior than speeches

He should not become cruel, hateful, or exhausting.

---

# 4. Current Canon Snapshot

## Game Structure

**Locked / Implemented**

- Genre: Retro-style 2D action platformer.
- Engine: Godot 4.4.1.
- Viewport: 480×270.
- Tile size: 16×16.
- Visual style: Pixel-perfect, SNES/Genesis-era readability.
- The game uses a unified master palette.
- Quarters persist as currency.
- Permanent abilities are tied to collectible items.
- World 1 currently contains six levels.
- World 2 begins in the sewer.

## World 1 Progression

**Current Plan**

- **Level 1-1:** School grounds / beginning of trip home.
- **Level 1-2:** Neighborhood or nearby outdoor route.
- **Level 1-3:** Arrival at Fat Kid’s house.
- **Home sequence:** Mom and Report Card quest payoff.
- **Level 1-4:** Beginning of route from home toward sewer.
- **Level 1-5:** Progress toward sewer entrance.
- **Level 1-6:** Gnome boss near or at sewer entrance.
- **After Level 1-6:** Fat Kid enters sewer.

## Time of Day

**Current Plan**

- Levels 1-1 through 1-3: Brighter daytime atmosphere.
- Levels 1-4 through 1-6: Warmer fall-evening atmosphere.

This gives World 1 a visual transition and implies time passing.

## Existing or Planned Items

**Locked / Implemented**

- Donut
- Taco
- Shorts
- Belt
- Sock
- Track Medallion
- Pizza Heart
- Quarters

**Current Plan**

- Report Card
- Wall movement upgrade

**Loose Idea**

- Fire Fart
- Petroleum Jelly Tin slide upgrade
- Bombs
- Sword
- Zapper / energy weapon
- Mana
- Stamina
- Gas resource

## Existing Characters

**Current Plan**

- Fat Kid
- Mom
- Report Card Kid
- Gnome boss

## Existing World 2 Enemies and Hazards

**Locked / Implemented or Partially Implemented**

- Sewer Slug
- Sewer Slime
- Sewer Snail
- Slime puddles
- Toxic bounce mushroom
- Toxic gas concept
- Sewer walls, pipes, grates, water, sludge, and related environment pieces

---

# 5. World Map and Geography

## General Geography Rule

**Current Plan**

Locations should feel connected in a simple side-scrolling way.

The world does not need a fully realistic overhead map, but the player should understand that they are moving through neighboring places.

A location can be stylized, compressed, or exaggerated as long as its entrance and exit make sense.

## Current Route

```text
School
  ↓
School Grounds / Nearby Streets
  ↓
Neighborhood / Outdoor Route
  ↓
Fat Kid's House
  ↓
Backyard / Outskirts / Evening Route
  ↓
Sewer Entrance
  ↓
Sewer
  ↓
Unknown Later Destination
```

## School

**Current Plan**

The game begins immediately after school lets out.

Possible readable side-view elements:

- School exit doors
- Fence
- Playground edge
- Sidewalk
- Bus area
- Sports field edge
- Dumpster
- Utility shed
- Students leaving
- Sign or marquee

The school should establish the ordinary suburban world before the adventure becomes stranger.

## Route Home

**Needs Development**

Levels 1-1 through 1-3 should feel like a continuous route.

Possible connective spaces:

- School edge
- Residential sidewalk
- Small wooded shortcut
- Drainage ditch
- Back lots
- Fences
- Yards
- Small businesses
- Utility areas
- Park or field

Do not finalize all geography until the current level layouts are reviewed.

## Fat Kid’s House

**Current Plan**

Fat Kid’s house should be a recognizable recurring location.

Possible functions:

- Story checkpoint after Level 1-3
- Mom interaction
- Report Card quest payoff
- Inventory reactions
- Future optional dialogue
- Small hub
- Place for arcade machine, bedroom, fridge, TV, or storage
- Visual changes as the game progresses

### House Presentation Rule

Because the game is a flat side-scroller:

- Prioritize readable doors, floors, and interaction zones.
- Avoid realistic perspective that implies movement into depth.
- Use cutaway rooms or a simple front-facing side view.
- Keep the first version small.

## Route to Sewer

**Needs Decision**

Levels 1-4 through 1-6 need a clear physical progression from home to sewer.

Possible route pieces:

- Backyard
- Alley
- Drainage channel
- Creek
- Construction area
- Utility corridor
- Wooded edge
- Municipal fence
- Sewer outflow
- Pump station
- Storm drain route

The final route should connect to why Fat Kid goes there.

## Sewer

**Current Plan**

World 2 is a sewer biome with:

- Brick and masonry walls
- Pipes
- Grates
- Sludge
- Toxic drips
- Water
- Slime
- Mushrooms
- Maintenance remnants
- Larger sewer creatures

The sewer should feel gross and dangerous, but still playful and readable.

## Mall

**Loose Idea / Future Placement**

The project identity strongly includes suburban and mall-themed elements.

The mall may be:

- A later world
- A major hub
- A destination connected to the sewer
- A place reached after traveling underground
- A separate chapter

Do not place it in the world map permanently yet.

---

# 6. Level-by-Level Story Progression

## World 1 Overview

**Current Plan**

World 1 begins as a trip home and ends with Fat Kid entering the sewer.

The first half introduces the normal world and early upgrades. The second half creates urgency, evening atmosphere, and movement toward the Gnome boss.

---

## Level 1-1 — Leaving School

### Status

**Current Plan / Partially Implemented**

### Story Purpose

- Introduce Fat Kid.
- Establish that school just ended.
- Begin the trip home.
- Introduce the normal suburban world.
- Quietly place the Report Card in inventory.
- Teach basic movement and food healing.

### Current Gameplay

**Locked / Implemented**

- Donut appears early.
- Pizza Heart currently appears in a chest near the end, though placement may change.
- Quarters can be collected.

### Strong Story Opportunities

- A school sign or bell establishes dismissal time.
- Other students leave in the background.
- Fat Kid may check his inventory and discover the Report Card without being told.
- Report Card Kid may appear late in this level or early in Level 1-2.
- The first quarter pickup can visually establish currency without dialogue.

### Environmental Details

**Loose Ideas**

- Lost lunchbox
- Crushed snack bag
- School poster
- Sports banner
- Bent fence
- Abandoned homework page
- Kid waiting for a ride
- Teacher locking a door
- Bus leaving without Fat Kid

### Needs Decision

- Exact start scene
- Whether Fat Kid is late leaving school
- Whether Report Card Kid appears here or in Level 1-2
- Whether Pizza Heart should remain here

---

## Level 1-2 — Neighborhood Route

### Status

**Current Plan / Partially Implemented**

### Story Purpose

- Continue the trip home.
- Expand the neighborhood.
- Introduce an optional NPC interaction.
- Give the player a movement upgrade.

### Current Gameplay

**Locked / Implemented**

- Sock upgrade appears here.

### Strong Story Opportunities

- Report Card Kid offers alteration service.
- The player can decline, leave, return, or pay.
- The kid’s location can feel slightly hidden but not obscure.
- The Sock can be acquired from a funny but understandable place.

### Report Card Kid Placement

**Strong Idea**

The NPC should appear before home and be easy to miss if the player rushes.

Possible locations:

- Behind a fence
- Under playground equipment
- Beside a shed
- Near a drainage ditch
- At a folding table
- Behind a convenience store
- Inside a cardboard “office”

### Needs Decision

- Forgery price
- NPC name
- Exact dialogue
- Whether the service is reversible
- Whether he offers other services later

---

## Level 1-3 — Reaching Home

### Status

**Current Plan / Partially Implemented**

### Story Purpose

- Complete the initial goal.
- Give the player the Track Medallion.
- Arrive at Fat Kid’s house.
- Pay off the Report Card quest.
- Set up the next objective.

### Current Gameplay

**Locked / Implemented**

- Track Medallion appears here.
- Level ends at Fat Kid’s house.

### Home Transition

**Current Plan**

A short transition should move from outdoor gameplay into the home scene.

This does not need to be a long cutscene.

Possible structure:

1. Fat Kid reaches the house.
2. He enters.
3. Mom reacts.
4. Report Card state is checked.
5. A reward or non-reward branch occurs.
6. The next problem is introduced.
7. Fat Kid leaves again.

### Needs Decision

- Why Fat Kid leaves home.
- What Mom gives for good grades.
- Whether Mom comments on the original report card.
- Whether Fat Kid keeps the forged card.
- Whether Mom can discover the forgery later.
- Whether home becomes revisitable immediately.

---

## Home Sequence

### Status

**Strong Idea / Needs Development**

### Required Functions

- Introduce Mom.
- Resolve the Report Card quest.
- Establish Fat Kid’s home life with minimal dialogue.
- Provide the reason for going toward the sewer.
- Keep the scene short.

### Report Card Branches

#### Original Bad Report Card

**Strong Idea**

Mom sees or asks about the report card.

Result:

- She comments on poor or mediocre grades.
- Fat Kid does not receive the special reward.
- The scene continues normally.

#### Altered Good Report Card

**Strong Idea**

Mom believes the grades are good.

Result:

- She praises or rewards Fat Kid.
- Fat Kid receives an item or permanent upgrade.
- The reward remains undecided.

#### Report Card Not Shown

**Loose Idea**

The player may be able to avoid presenting it.

This should only exist if it does not create excessive branching.

### Scene Length Target

Keep the first version to approximately:

- 3–8 short text boxes
- One visual reaction
- One optional reward
- One clear next objective

---

## Level 1-4 — Leaving Home at Evening

### Status

**Current Plan / Partially Implemented**

### Story Purpose

- Shift the atmosphere from daytime to fall evening.
- Begin the trip toward the sewer.
- Introduce more dangerous or strange outdoor encounters.
- Show that the ordinary neighborhood is becoming less normal.

### Current Gameplay

**Locked / Implemented**

- Mushroom challenge
- BeeSwarm
- Griplets
- Breakable wall

### Story Opportunities

- The breakable wall may be part of a shortcut or hidden drainage route.
- The mushroom challenge can feel like a natural backyard or overgrown area.
- BeeSwarm and Griplets can signal movement away from populated streets.
- A sign or maintenance marker can point toward drainage infrastructure.

### Needs Decision

- Exact exit from home
- Whether Mom directly sends Fat Kid
- Whether Fat Kid sneaks out
- Whether the objective is urgent, selfish, accidental, or helpful

---

## Level 1-5 — Approaching the Sewer

### Status

**Current Plan / Partially Implemented**

### Story Purpose

- Continue the evening route.
- Increase environmental evidence of the sewer.
- Prepare the player for the Gnome.
- Remix outdoor mechanics.

### Current Gameplay

**Locked / Implemented**

- Develops World 1 outdoor ideas.
- BeeSwarm and Webee concepts may appear.
- Breakable walls or foreground structures may appear.

### Environmental Storytelling

**Strong Ideas**

- Drainage water
- Increasing pipework
- Warning signs
- Municipal fencing
- Wet ground
- Strange mushrooms
- Gnome-made markers
- Tiny footprints
- Stolen tools
- Garden ornaments in the wrong place

### Needs Decision

- Whether the Gnome’s influence becomes visible before Level 1-6
- Whether the player receives a warning
- Whether another NPC comments on the sewer

---

## Level 1-6 — Gnome Boss / Sewer Entrance

### Status

**Locked / Implemented Boss, Story Role Undecided**

### Story Purpose

- Conclude World 1.
- Block access to the sewer.
- Introduce a boss with personality.
- Make entering World 2 feel earned.

### Gnome Role Possibilities

**Loose Ideas**

- Territorial guardian
- Municipal employee
- Contracted security
- Self-appointed gatekeeper
- Sewer resident
- Garden gnome protecting stolen property
- Person following an absurd regulation
- Someone who mistakes Fat Kid for a different intruder
- Guard working for a later antagonist
- Gnome who genuinely thinks entering the sewer is unsafe

### Preferred Direction

**Current Plan**

Do not make the Gnome generically evil.

His motive should be understandable, petty, strange, or mundane.

### Curse of Stamina — Implemented 2026-10-23

**Locked / Implemented**

The Gnome's final spell slowly homes toward Fat Kid, accelerating if avoided. On contact it deals no health damage and afflicts him with the **Curse of Stamina** for the current playthrough. A brief green palette effect and two-stage announcement reveal the stamina bar beneath the hearts.

This enables the existing movement resource: 50 starting capacity, running drain, jump and kick costs, passive recovery, and exhaustion. Before the curse, these restrictions are disabled. The curse survives deaths and level changes; a new game clears it. The curse spell cannot kill Fat Kid, even at one HP. This uses runtime session persistence, like the current upgrades; it does not add a disk-save system.

This decision supersedes the earlier tentative stamina/resource references below. The Taco now transmutes this same resource into gas (see the Taco entry); Mana remains undecided.

### After the Boss

**Current Plan**

- The sewer entrance opens or becomes accessible.
- Fat Kid enters.
- World 2 begins.

### Needs Decision

- Whether Gnome is defeated, knocked aside, embarrassed, or convinced.
- Whether he returns later.
- Whether he speaks before or after the fight.
- Whether he is connected to the main plot.

---

## World 2 — Sewer

### Story Purpose

**Current Plan**

The sewer should:

- Continue the reason Fat Kid left home.
- Expand the world beyond the neighborhood.
- Introduce larger and stranger creatures.
- Use environmental clues instead of heavy explanation.
- Move Fat Kid toward a later destination.

---

## Level 2-1 — Sewer Entry

### Status

**Current Development**

### Story Purpose

- Establish sewer visuals and hazards.
- Introduce the sewer as a functioning place, not just a cave.
- Teach sludge, toxic gas, or sewer-specific movement.
- Show evidence of what Fat Kid is following or trying to reach.

### Existing Gameplay Material

**Locked / Implemented or Planned**

- Sewer wall background
- Slimes
- Slugs
- Snail
- Toxic mushroom
- Slime puddles
- Pipes
- Dripping toxic fluid

### Strong Story Opportunities

- A maintenance sign is partly readable.
- Something from home or the surface has washed into the sewer.
- Tiny Gnome markings continue underground.
- Quarters appear in drains and sludge.
- A pipe or machine suggests the sewer connects to another major location.
- A creature interaction tells a story without dialogue.

### Needs Decision

- What Fat Kid is pursuing.
- Whether the sewer is a shortcut or the actual destination.
- Whether anyone else is living or working there.
- What the first sewer landmark is.

---

# 7. Biomes

## World 1 Outdoor Suburb

### Status

**Locked / Implemented**

### Visual Identity

- School
- Sidewalks
- Grass
- Trees
- Fences
- Yards
- Fields
- Fall colors
- Brambles
- Mushrooms
- Small utility structures

### Story Function

- Establish normal life.
- Introduce Mom and home.
- Let weirdness enter gradually.
- Provide familiar spaces for strange enemies and items.

## Sewer

### Status

**Current Development**

### Visual Identity

- Brick walls
- Pipes
- Grates
- Water
- Sludge
- Toxic drips
- Mushrooms
- Industrial leftovers
- Maintenance signs
- Creature nests

### Story Function

- Shift from suburban familiarity to underground weirdness.
- Reveal hidden connections beneath the town.
- Introduce hazards and creatures that feel related to waste, runoff, food, and mutation.
- Potentially connect to the mall or another later destination.

## Mall

### Status

**Loose Idea / Major Future Identity**

### Possible Story Function

- Later world
- Commercial hub
- Arcade location
- Shops
- Mall Cop enemy context
- Food court
- Escalation of suburban satire

Do not finalize placement yet.

## Dungeon

### Status

**Loose Idea**

Mentioned through possible collectible painting themes and broader game concepts.

No current story placement.

---

# 8. Main Characters

## Fat Kid

### Status

**Locked / Implemented Protagonist**

### Personality

**Current Plan**

- Mischievous
- Hungry
- Opportunistic
- Slightly rude
- Funny
- Lovable
- Physical
- Expressive
- More capable than people expect

### Dialogue Style

- Short
- Blunt
- Specific
- Sometimes reluctant
- Sometimes overconfident
- Rarely explanatory

### Characterization Through Gameplay

- Eats food immediately.
- Uses a fart-powered double jump.
- Kicks enemies and objects.
- Collects clothing as abilities.
- Can forge a report card.
- Uses quarters for questionable services and arcade machines.
- Reacts physically to damage, food, and upgrades.

### Needs Decision

- Whether Fat Kid speaks often or mostly uses reaction sounds.
- Whether the player sees his thoughts.
- Whether his name is ever stated in-world.
- Whether he has a larger personal goal beyond the immediate journey.

---

## Mom

### Status

**Current Plan**

### Role

- Lives at Fat Kid’s house.
- Resolves the Report Card quest.
- Gives or withholds a reward.
- Introduces the next objective.
- May become a recurring home NPC.

### Personality Direction

**Strong Idea**

Mom should feel like a real person in a strange world, not a generic quest giver.

Possible traits:

- Busy
- Suspicious in a practical way
- Loving but tired
- Easily impressed by the wrong thing
- More observant than Fat Kid thinks
- Concerned about grades, chores, food, or household problems
- Familiar with Fat Kid’s schemes

### Dialogue Style

- Short
- Direct
- Specific
- Slightly weary
- Not constantly joking

### Needs Decision

- Reward for good grades
- Whether she sees through the forgery
- Why she sends or allows Fat Kid to leave
- Whether she appears again between worlds

---

## Report Card Kid

### Status

**Strong Idea**

### Role

A school-aged NPC who alters report cards for quarters.

### Personality Direction

- Calmly professional about an obviously dubious service
- Not dramatic
- Treats forgery like routine paperwork
- May have a cheap setup
- Could remember Fat Kid later

### Appearance Ideas

**Loose Ideas**

- Oversized backpack
- Folding table
- Pencil behind ear
- Stamp collection
- Magnifying glass
- Cheap visor
- Cardboard sign
- Ink-stained hands

### Possible Names

**Loose Ideas**

- Red Pen
- Denny
- Curtis
- Grade-A Gary
- The Registrar
- Mikey Marks
- Eraser Eddie

Do not lock a name yet.

### Other Possible Services

**Loose Ideas**

- Fake permission slips
- Hall passes
- Excuse notes
- Library fine adjustments
- Parent signatures
- Detention rescheduling

Only add these if they become useful later.

### Needs Decision

- Name
- Price
- Location
- Dialogue
- Whether he returns
- Whether the forged card remains in inventory

---

# 9. Bosses

## Gnome

### Status

**Locked / Implemented Gameplay, Story Role Needs Decision**

### Current Placement

Level 1-6 near the sewer entrance.

### Design Rule

Do not default to generic evil.

### Possible Motives

**Loose Ideas**

- Protecting the sewer
- Guarding a job site
- Enforcing a strange permit system
- Hired by someone
- Protecting stolen garden objects
- Mistaking Fat Kid for a thief
- Blocking entry because of a real danger
- Demanding a toll or paperwork
- Trying to stop surface people from entering

### Fight Context

**Needs Decision**

- Does dialogue begin the fight?
- Is the Gnome intentionally blocking Fat Kid?
- Can the player understand his motive before fighting?
- Does the Gnome survive?
- Does the Gnome become recurring?
- Does he give information after defeat?

## Sewer Boss

### Status

**Loose Idea / Existing Concept Images to Review**

A sewer boss concept apparently exists in saved images.

Before production:

1. Locate concept images.
2. Decide whether the design still fits.
3. Define gameplay role.
4. Define why it is in the sewer.
5. Avoid final animation and sound until behavior is chosen.

---

# 10. Enemies with Story Relevance

Most enemies do not need full backstories.

Use story relevance when an enemy:

- Establishes a location
- Connects to an NPC
- Creates a memorable interaction
- Carries or drops an item
- Reappears as a recurring character
- Explains a hazard
- Changes the environment

## Apple Interaction Enemies

**Strong Idea**

Selected enemies may:

- Be hurt by falling apples
- Be hurt by kicked apples
- Eat landed apples
- Fight over food
- Accidentally help the player

This should be authored in specific encounters rather than simulated everywhere.

## Mall Cop

**Loose Idea**

Possible donut drop on defeat.

Needs balance review before making it guaranteed.

## BeeSwarm and Bird

**Current Gameplay Backlog**

Both may become killable later.

No story role is currently required.

## Webee Secret

**Needs Decision**

An older hidden interaction exists in memory but has not been clearly defined.

Do not implement until the intended joke or mechanic is recovered or redesigned.

## Sewer Snail

**Locked / Implemented or Partially Implemented**

The large sewer snail is already memorable because:

- It slides
- It spits
- It barfs
- It retreats into a shell
- The shell remains
- The shell can become a kickable platform or object

This is a strong example of a creature interaction that is memorable without needing to work in every situation.

---

# 11. Items and Permanent Upgrades

## Item Design Rule

**Current Plan**

Important abilities should feel like part of the adventure.

Not every item needs a long scene. Acquisition should still be:

- Understandable
- Funny or memorable when appropriate
- Connected to a location, NPC, challenge, or event
- Clear enough that the player understands what changed

---

## Donut

### Status

**Locked / Implemented**

### Effect

Restores one health.

### Story Use

- Food pickup
- Possible Mall Cop drop
- Can appear naturally in school, neighborhood, mall, or food-related locations

---

## Taco

### Status

**Locked / Implemented**

### Effect

Unlocks fart-powered double jump.

**Implemented 2026-10-23 — The Gift of Gas:** After the Gnome curse, collecting a Taco starts “TACO COLLECTED,” then “STAMINA TRANSMUTING...” with a green effect on Fat Kid. The lettering travels to the existing bar beneath the hearts, changing its initial leaf-green stamina color to the original muted-green gas colors. This is the same resource pool and existing costs/recovery, not a second meter.

“POWER GRANTED: THE GIFT OF GAS” follows, with a compact, quiet puff using the existing fart-cloud art, then “FART JUMP UNLOCKED.” The actual double-jump ability is granted with that final announcement. Completed gas progression survives death, Continue, and level changes. An interrupted announcement resumes on the next living spawn; New Game clears it.

The boss arena's development Taco is on the post-fight side and appears after the curse reveal. Existing uncursed standalone test levels retain the original immediate Taco upgrade behavior. Final campaign item placement remains a separate level-design decision.

### Story Direction

The item itself already communicates the joke.

No lengthy explanation is needed.

---

## Shorts

### Status

**Locked / Implemented**

### Effect

Unlocks or improves long kick.

### Story Direction

Clothing-based movement and combat upgrades fit the world well.

---

## Belt

### Status

**Locked / Implemented**

### Effect

Unlocks crouching.

### Story Direction

The logic can remain silly and game-like.

---

## Sock

### Status

**Locked / Implemented**

### Effect

Increases jump height.

### Current Placement

Level 1-2.

### Story Direction

Could be:

- Lost laundry
- Sports sock
- Suspiciously powerful sock
- Reward from a tiny platform challenge

Do not add extra lore unless needed.

---

## Track Medallion

### Status

**Locked / Implemented**

### Effect

Unlocks running.

### Current Placement

Level 1-3.

### Story Direction

Potentially connected to:

- School track
- Local race
- Discarded award
- Sports field
- Fat Kid taking it for reasons of his own

---

## Pizza Heart

### Status

**Locked / Implemented**

### Effect

Permanently increases maximum health.

### Current Placement

Chest near end of Level 1-1.

### Needs Decision

- Keep in Level 1-1
- Move later
- Use as Mom’s reward
- Create a different reward for Mom

Do not move it solely to solve the Report Card reward before the larger progression is reviewed.

---

## Wall Jump — Bubblegum

### Status

**Locked / Implemented** — Movement and pickup implemented; final placement and feel tuning remain open.

### Name and Item Decision

**Locked / Implemented** — User confirmed Bubblegum grants **Wall Jump** (2026-10-04).

The upgrade ID is `wall_jump_upgrade`. Earlier naming and item alternatives are preserved in section 21.

### Mechanical Rules

- Includes descending wall slide (`wall_cling`) and launch away from wall.
- Sliding requires falling and holding toward a wall; wall jumping does not require holding toward it.
- A wall jump spends that wall side until landing or physical opposing-wall contact.
- Neither consumes nor restores the Taco double jump.
- Should not give excessive air control.
- Must feel good before story polish.

### Item Source

**Locked / Implemented** — Bubblegum pickup, using the existing runtime upgrade persistence.

**Needs Decision** — Final production-level placement. Currently placed only in an isolated wall-jump test arena; no production progression order is established by this implementation.

---

## Petroleum Jelly Tin

### Status

**Loose Idea**

### Effect

Unlocks sliding by crouching while running.

### Story Value

The item is specific, mundane, greasy, and funny.

### Needs Decision

- Whether sliding is a committed upgrade
- Whether it damages enemies
- Whether it is required for progression
- Whether it belongs in the sewer, mall, or home

---

## Fire Fart

### Status

**Loose Idea / Future Ability**

Potential upgrade to fart movement or combat.

Do not build story progression around it until mechanics exist.

---

## Quarters

### Status

**Locked / Implemented**

### Uses

**Current or Strong Ideas**

- Report Card alteration
- Arcade machines
- Shops
- NPC services
- Optional items
- Secrets
- Unusual interactions

### Economy Rule

Avoid too many competing quarter costs early.

The first version should establish only a few meaningful uses.

---

## Report Card

### Status

**Strong Idea**

### Starting State

The Report Card may begin in Fat Kid’s inventory.

The player is not directly told to inspect it.

### Possible States

- Original bad or mediocre grades
- Altered good grades
- Presented to Mom
- Kept after presentation
- Exposed as forged

### Story Rule

Keep it funny and low-stakes.

Do not turn it into a major dramatic artifact.

---

# 12. Quests and Optional Events

## Report Card Quest

### Status

**Strong Idea**

### Quest Flow

1. Player begins with Report Card.
2. Player may inspect it.
3. Player encounters Report Card Kid.
4. Player pays quarters for altered grades.
5. Player reaches home.
6. Mom checks the card.
7. Reward branch occurs.

### Why It Works

It connects:

- Inventory
- Exploration
- NPC interaction
- Currency
- Home
- Mom
- Permanent reward
- Comedy

### Needs Decision

- Price
- Mom reward
- Original grades
- Altered grades
- Dialogue
- Whether Mom can discover forgery
- Whether quest remains available after leaving home

---

## Arcade Challenge Quest

### Status

**Loose Idea**

Possible structure:

1. NPC mentions a high score.
2. Player pays a quarter.
3. Player completes Alien Commander challenge.
4. NPC reacts.
5. Player receives an item, key, painting, or secret access.

Prefer optional rewards before using arcade games as mandatory progression.

---

## Apple Kill Event

### Status

**Loose Idea**

Possible achievement or one-time dialogue for defeating an enemy with a kicked apple.

No major quest system required.

---

## Collectible Paintings

### Status

**Loose Idea**

Possible themes:

- Outdoor areas
- Sewer
- Dungeon
- Mall
- Enemies
- Items
- Characters
- Game events

Possible display:

- Gallery
- Home wall
- Collection menu
- Museum-like NPC area

Do not commit to a full collection reward until count and production cost are known.

---

## Dwarven Scrolls

### Status

**Loose Idea**

Running joke:

> Many dwarven scrolls exist, but only one is on planet Earth.

Possible contents:

- Joke text
- Hints
- Fake lore
- Spells
- Collectible entries
- One useful Earth scroll

Needs purpose before implementation.

---

# 13. Shops and Economy

## Current Direction

**Needs Development**

Quarters should feel useful without creating a difficult economy.

## Recommended Early Economy

**Strong Idea**

World 1 should probably have only one or two major quarter uses:

- Report Card alteration
- Optional arcade play or one small purchase

This teaches that quarters matter without making players afraid to spend them.

## Possible Shop Types

**Loose Ideas**

- Convenience store
- Vending machine
- School fundraiser table
- Sewer trader
- Mall shop
- Food stand
- Strange kid service booth
- Lost-and-found counter

## Shopkeeper Rule

Shopkeepers should have:

- A clear practical role
- A short voice
- One memorable detail
- No unnecessary lore dump

## Needs Decision

- First real shop location
- Whether food can be purchased
- Whether permanent upgrades can be bought
- Whether arcade machines consume quarters every attempt
- Whether prices change
- Locked / Implemented (2026-10-21): quarters are retained on death and Continue; ordinary quarter pickups still respawn.

---

# 14. Minigames and Arcade Machines

## General Direction

**Current Plan**

Arcade machines exist physically inside the game world.

They are not only menu options.

## Alien Commander

### Status

**Current Plan / Partially Implemented**

### Known Features

- Three-by-three alien arrangement
- Player ship along bottom
- Turn or pass behavior
- AI opponent behavior
- Retro arcade presentation

### Possible In-World Uses

- Quarter-operated cabinet
- High score challenge
- NPC rivalry
- Secret room reward
- Door unlock
- Item reward
- Recurring fictional franchise

### Recommendation

**Current Plan**

Use Alien Commander as optional content first.

Do not gate mandatory progression behind it until the minigame is proven fun, fair, and quick to restart.

## Arcade Cabinet Locations

**Loose Ideas**

- Convenience store
- Restaurant
- Fat Kid’s house
- Mall arcade
- Laundromat
- Secret maintenance room
- Sewer break room
- School corner
- Pizza place

## Fictional Arcade Franchises

**Loose Idea**

Recurring cabinets or sequels could make the world feel connected.

Do not design an entire arcade catalog yet.

---

# 15. Dialogue and Character Voice

## General Dialogue Rules

- Keep conversations short.
- Avoid generic exposition.
- Most NPC dialogue should be optional.
- Let players walk away.
- Use state-dependent dialogue when it creates a meaningful payoff.
- Do not force every NPC to tell a joke.
- Use specific mundane details.
- Provide a few variants before locking important lines.
- Record trigger conditions beside dialogue.

## Dialogue Documentation Format

Use:

```markdown
### Trigger
Player speaks to Report Card Kid before alteration.

### State
Report Card = Original
Quarters >= Price

### Draft Lines
REPORT CARD KID: ...
FAT KID: ...
```

## Fat Kid Voice

**Current Plan**

- Short
- Blunt
- Occasionally smug
- Easily distracted by food
- Not a constant comedian
- Can respond through animation instead of words

### Example Tone Only

- “How much?”
- “That looks real enough.”
- “I was already going that way.”
- “No.”
- “Is that food?”

These are not locked lines.

## Mom Voice

**Current Plan**

- Practical
- Slightly tired
- Specific
- Familiar with Fat Kid’s behavior
- Capable of warmth without becoming sentimental

## Report Card Kid Voice

**Strong Idea**

- Calm
- Businesslike
- Minimal moral concern
- Treats forgery as ordinary service work

## Gnome Voice

**Needs Decision**

Possible directions:

- Bureaucratic
- Territorial
- Grandiose but mundane
- Exhausted employee
- Tiny authoritarian
- Concerned safety inspector

---

# 16. Jokes, Gags, and Easter Eggs

## Title Screen Guitar Solo

### Status

**Loose Idea — Preserve**

During the synth solo in the title music:

- Static Fat Kid image comes alive.
- He pulls out a guitar.
- He plays along.
- Head bob or foot tap.
- He hides the guitar again.
- Returns to normal pose.

### Production Rule

Do not let this become a major technical project yet.

## Starting Report Card

### Status

**Strong Idea**

The game does not announce it.

Players who inspect inventory discover the bad grades themselves.

## Report Card Forgery Service

### Status

**Strong Idea**

A child quietly runs a professional-looking grade alteration service for quarters.

## Dwarven Scroll Earth Joke

### Status

**Loose Idea — Preserve**

Many dwarven scrolls exist, but only one is on Earth.

## Petroleum Jelly Tin

### Status

**Loose Idea — Preserve**

A mundane greasy object grants a slide ability.

## Mall Cop Donut Drop

### Status

**Loose Idea**

Funny and readable, but must not damage health balance.

## Apple Interactions

### Status

**Strong Interaction Direction**

- Falling apples hurt enemies.
- Kicked apples hurt enemies.
- Landed apples heal the player.
- Selected enemies may eat apples.
- A designed encounter may reward or acknowledge an apple kill.

## Inventory Descriptions

### Status

**Strong Idea**

Inventory descriptions should preserve:

- Mundane details
- Unnecessary specificity
- Fat Kid’s perspective
- Dry jokes
- Gross details
- Slightly suspicious item histories

Do not make every item description a punchline.

---

# 17. Environmental Storytelling

## General Rule

Use the environment to suggest that the world existed before Fat Kid arrived.

Keep details readable and sparse.

## School and Neighborhood

Possible details:

- Flyers
- Lost homework
- Lunch trash
- School banners
- Odd yard decorations
- Broken sprinklers
- Fences patched badly
- Utility markings
- Drainage signs
- Convenience-store ads
- Kids doing unrelated things

## Home

Possible details:

- Fridge notes
- Shoes by door
- Chore list
- Old arcade machine
- Report-card magnet space
- Family photos
- Snack storage
- Broken household object that may create the next objective

## Route to Sewer

Possible details:

- Maintenance warnings
- Drainage maps
- Gnome symbols
- Tiny barricades
- Stolen garden decorations
- Strange runoff
- Missing utility cover
- Construction cones
- Water flowing in the wrong direction

## Sewer

Possible details:

- Old work signs
- Lunch area
- Maintenance locker
- Pipe labels
- Graffiti
- Coin buildup
- Lost surface objects
- Nests made from trash
- Toxic leaks
- Evidence of another destination beyond the sewer

---

# 18. Open Questions

## High Priority

1. Why does Fat Kid leave home after Level 1-3?
2. Why must he go toward or into the sewer?
3. What is the Gnome doing at the sewer entrance?
4. What does Mom give for the altered Report Card?
5. What is the first clear objective inside the sewer?

## Medium Priority

6. Where exactly does Report Card Kid appear?
7. How many quarters does the forgery cost?
8. Does Fat Kid keep the Report Card?
9. Does Mom ever discover the forgery?
10. Is the Gnome recurring?
11. Is the mall a later destination?
12. Where should the Bubblegum Wall Jump upgrade be placed?
13. Does home become a recurring hub?
14. Are arcade machines always optional?
15. What persists after death and checkpoint respawn?

## Low Priority

16. Does the title-screen guitar Easter egg trigger every loop?
17. Do enemies eat apples?
18. Are collectible paintings definitely included?
19. What do dwarven scrolls do?
20. Does the Petroleum Jelly Tin remain part of progression?
21. Resolved 2026-10-21: three starting lives and unlimited free Continues; see Lives and Persistent Rewards below.
22. Do stamina, gas, and Mana exist as separate resources?

---

# 19. Contradictions and Decisions Needed

## Wall Jump vs. Wall Kick

**Locked / Implemented** — Resolved 2026-10-04: **Wall Jump**, granted by **Bubblegum**. Production placement remains undecided. Earlier terms are archived in section 21.

## NPC Side Quests

**Contradiction to Resolve**

Older notes say to decide whether NPCs offer side quests, but the Report Card event already functions as one.

Recommended rule:

> The game may contain a small number of optional NPC quests. No large quest-log system is currently planned.

## Pizza Heart vs. Mom Reward

**Needs Decision**

Pizza Heart currently exists in Level 1-1, while Mom needs a possible permanent reward.

Do not move the Pizza Heart until progression is reviewed.

## Minigame Gates

**Needs Decision**

Arcade machines may unlock doors, but mandatory minigame gating is not yet approved.

Recommendation:

> Optional rewards first. Mandatory use later only if the minigame proves strong.

## Palette Guidance

**Contradiction to Resolve**

Older notes proposed Level 1-1-specific sky colors.

Current project rules require one unified master palette and explicit approval before adding colors.

Story Bible ruling:

> Palette decisions belong to the master palette workflow. Do not create a separate story or biome palette.

## Mall-Themed Identity vs. Current Opening

**Not a Direct Contradiction**

The current opening is school, neighborhood, home, and sewer.

The mall can remain a later destination or major location.

---

# 20. Story Implementation Backlog

## Next Story Tasks

### High Priority

- [ ] Decide the simple reason Fat Kid leaves home.
- [ ] Decide why the sewer is the next destination.
- [ ] Decide the Gnome’s motive.
- [ ] Choose Mom’s Report Card reward.
- [ ] Define the opening home scene in 3–8 text boxes.
- [ ] Decide Report Card Kid’s level and location.
- [ ] Draft Report Card Kid dialogue variants.
- [ ] Draft Mom dialogue for original and altered Report Card.
- [ ] Define the first story landmark in Level 2-1.

### Medium Priority

- [ ] Confirm Pizza Heart placement.
- [x] Choose Wall Jump upgrade item: Bubblegum (2026-10-04).
- [ ] Choose Bubblegum placement.
- [ ] Decide whether home is revisitable.
- [ ] Define World 1 geography between levels.
- [ ] Choose whether Gnome returns later.
- [ ] Decide first real shop or quarter sink.
- [ ] Decide whether Alien Commander has an in-world cabinet in World 1 or later.
- [ ] Review sewer boss concept images.
- [ ] Define the Webee secret interaction.

### Low Priority

- [ ] Write title-screen guitar Easter egg production note.
- [ ] Draft inventory descriptions.
- [ ] Decide collectible painting scope.
- [ ] Decide Dwarven Scroll purpose.
- [ ] Decide whether selected enemies eat apples.
- [ ] Decide whether Petroleum Jelly slide remains active.
- [x] Decide lives, continues, and quarter loss — approved 2026-10-21; see Lives and Persistent Rewards.
- [ ] Revisit stamina, gas, and Mana only after core movement and combat are stable.

## Implementation Dependencies

### Report Card Quest

Requires:

- Inventory state
- Report Card item
- Altered Report Card state
- Quarter price check
- NPC interaction
- Mom interaction
- Reward state
- Save persistence

### Home Scene

Requires:

- House art or temporary layout
- Entrance transition
- Mom sprite
- Dialogue system
- Report Card state check
- Reward grant
- Next-objective flag

### Gnome Story Context

Requires:

- Pre-fight or post-fight trigger
- Dialogue support if used
- Sewer entrance transition
- World 2 unlock

### Arcade Cabinet

Requires:

- Cabinet scene
- Quarter check
- Minigame transition
- Return point
- Reward or score state
- Fast retry behavior

---

# 21. Archived or Rejected Ideas

## Damage from the Final Curse Spell

**Status:** Cut / Archived  
**Date:** 2026-10-23

### Original Idea

The final spell dealt one HP of damage; a lethal hit deferred the curse announcement until respawn.

### Reason Archived

The user changed the spell to apply the curse without any health damage. Impact feedback and the held hurt pose remain cosmetic.

### Possible Reuse

Ordinary enemy attacks still use their existing damage rules.

## Gas as a Separate Undecided Resource

**Status:** Cut / Archived  
**Date:** 2026-10-23

### Original Idea

Gas remained undecided as a potentially separate resource alongside stamina.

### Reason Archived

The user selected the Taco transmuting the Curse of Stamina into the Gift of Gas. The existing pool changes presentation and grants fart jump; it does not add a second meter or change the existing spending/recovery rules.

### Possible Reuse

Distinct Mana or other resource mechanics remain undecided. Earlier brainstorms are preserved as history.

## Stamina as an Undecided Future Mechanic

**Status:** Cut / Archived  
**Date:** 2026-10-23

### Original Idea

Stamina was a loose future idea, with a decision still needed about whether it should exist alongside gas and Mana.

### Reason Archived

The user selected the Gnome's final spell as the Curse of Stamina, enabling the existing movement-resource prototype and revealing its HUD bar. See the implemented Level 1-6 curse entry.

### Possible Reuse

Gas and Mana remain possible separate mechanics; their earlier ideas are retained without commitment.

## Earlier Wall Movement Names and Item Sources

**Status:** Cut / Archived  
**Date:** 2026-10-04

### Original Idea

The ability was called both Wall Jump and Wall Kick, with Wall Movement Upgrade as a temporary name. Possible sources were shoes, gloves, sticky candy, knee pads, climbing gear, suction cups, a sewer item, a Gnome item, or a mall sporting goods item.

### Reason Archived

The user explicitly selected Bubblegum granting Wall Jump. Final placement and story context remain undecided.

### Possible Reuse

Other item concepts may suit future abilities or decorative objects; they are not alternative sources for this implemented upgrade.

Use this section when an idea is replaced.

Recommended archive format:

```markdown
## Idea Name

**Status:** Cut / Archived  
**Date:** YYYY-MM-DD

### Original Idea
...

### Reason Archived
...

### Possible Reuse
...
```

Do not delete old ideas merely because a newer version exists.

---

# 22. Recommended Next Decision

The next decision should be narrow:

> **What happens at home that gives Fat Kid a simple reason to head toward the sewer?**

The answer should ideally connect at least three existing elements, such as:

- Mom
- A missing or broken household item
- Food
- Quarters
- The Gnome
- A sewer route
- A future destination
- An upgrade
- A joke

Do not design the entire game plot yet. Solve the transition from home to sewer first.

---

# 23. Source Material Used for Version 0.1

This draft was assembled from:

- The dedicated FatKidGame story-planning brief
- FatKidGame Polish Backlog dated 2026-07-16
- FatKidGame Cursor Project Rules
- Existing project conversation notes concerning levels, enemies, items, minigames, art direction, and gameplay progression

When project files and this Story Bible disagree, flag the contradiction before changing canon.


## Lives and Persistent Rewards — 2026-10-21

**Locked / Implemented:** A fresh Start gives three lives, including the current attempt. Death consumes one life and restarts the current level with full health while lives remain. Zero opens Game Over. Continue is unlimited and free, restores three lives/full health, and returns to the current world's first level—including 1-1 after the World 1 boss.

Money, abilities, max-HP bonuses, opened chests, and collected persistent rewards survive death and Continue. Title-screen Start clears the entire playthrough. Quarters still respawn, so farming is possible under the current economy; balancing is separate.

Placed extra lives grant +1 and stay collected until a fresh game. Future enemy drops may repeat as enemies respawn; drop probabilities are not implemented. Extra lives never appear in chests. Chests stay open on replay; their uncollected permanent reward remains available, and collected rewards stay gone. Separate max-HP rewards still stack.

The HUD uses the first extra-life frame and an expanding count. Collection grants the life immediately; the cosmetic flight to the HUD freezes during pause. Lives are uncapped. Save files, arcade checkpoints, and collectible-based life awards remain future work.
