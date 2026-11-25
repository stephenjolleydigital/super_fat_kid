extends RefCounted
# Each upgrade has three ranks. Values below describe one additional rank.
const ITEMS = [
["pepper", "PEPPERONI CANNON", "You already start with a small cannon.", "Each rank: +1 damage. Fires the last way you pressed."],
["gas", "BIOHAZARD BURP", "Leave a damaging stink cloud every 4s.", "Each rank: +1 damage and larger cloud."],
["orbit", "DOUGHNUT SATELLITES", "A donut orbits you and bonks monsters.", "Each rank: another orbiting donut."],
["sprinkles", "SPRINKLE SHOTGUN", "Every donut fires a radial candy volley.", "Each rank: +4 projectiles."],
["cheese", "MOLTEN MOZZARELLA", "Pizza leaves a hot cheese pool.", "Each rank: +1 damage per half second."],
["nova", "LAST BITE BIG BANG", "Every fifth snack explodes around you.", "Each rank: wider blast, +1 damage."],
["dash", "BELLY FLOP", "SPACE lunges, crushes and protects you.", "Each rank: shorter cooldown, +1 damage, farther flop."],
["ricochet", "RUBBER PEPPERONI", "All friendly shots bounce off walls.", "Each rank: another wall bounce."],
["pierce", "SKEWER SERVICE", "Shots pierce additional monsters.", "Each rank: another target per shot."],
["frost", "BRAIN FREEZE", "Your hits slow monsters for 1 second.", "Each rank: another second of slow."],
["chain", "MICROWAVE ARC", "Kills zap the closest visible monster.", "Each rank: +1 arc damage."],
["bomb", "POPCORN FUNERAL", "Dead monsters explode into popcorn.", "Each rank: +1 damage, larger blast."],
["speed", "ROLLER SNACKS", "Move 12% faster per rank.", "Belly flop travels farther too. Stacks up to the speed cap."],
["magnet", "VACUUM MOUTH", "Slurp snacks from farther away. Walls block it.", "Each rank: +8px reach and +1 damage on the crumb spat after a 12px+ slurp."],
["shield", "BUBBLE WRAP", "Gain one shield now and each round.", "Each rank: +1 refreshed shield. Pop in boss fight: winds boss (6s cooldown)."],
["sugar", "SUGAR OVERDRIVE", "Donuts accelerate your cannon for 3s.", "Each rank: longer overdrive."],
["rapid", "FAST FOOD", "Cannon cooldown is 7% shorter per rank.", "Stacks with Sugar Overdrive. Delay never hits zero."],
["spread", "TRIPLE DECKER", "Cannon fires an extra angled shot.", "Each rank: another shot."],
["trail", "CRUMB MINEFIELD", "Every snack drops an explosive crumb.", "Each rank: +1 mine damage."],
["retaliate", "REVENGE IS SWEET", "Losing HP triggers a candy blast.", "Each rank: +2 damage and wider blast."],
["trap", "HEALTH INSPECTOR", "Hazards deal +2 damage to enemies.", "Each rank: +2 more; bait them in. Spikes ignore the boss guard."],
["key", "GOLDEN RAMPAGE", "Keys grant 2 seconds of invincibility.", "Each rank: +2s. Touching monsters deals 5 damage."],
["combo", "COMBO MEAL", "Bites within 3s build a combo, up to 5.", "Each rank: +25 pts per combo step and +1 cannon damage at combo 3+."],
["revive", "SECOND HELPING", "One fatal-hit rescue per run.", "Rescue heals 1 HP per stack."],
["range", "LONG LUNCH", "Friendly shots live 0.5s longer.", "Each rank: +0.5s; great with bounces."],
["knock", "HEAVY SAUCE", "Your hits knock monsters back.", "Each rank: +5px push, walls respected."],
["stink", "LINGERING STINK", "Gas and cheese last 1s longer.", "Each rank: +1s hazard lifetime."],
["giant", "BIG GAS ENERGY", "Gas clouds grow 8 pixels wider.", "Each rank: +8px radius."],
["spicy", "GHOST PEPPER", "Gas deals +1 damage per rank.", "Also adds damage to your belly flop."],
["shieldpop", "BUBBLE TROUBLE", "A broken shield launches a blast.", "Each rank: +2 damage."],
["pizza", "PIZZA TURBO", "Pizza gives 30% speed for 2 seconds.", "Each rank: +2s duration."],
["finish", "DOORSTOP PICKLE", "A flop leaves a pickle where you started.", "First monster to touch it trips. Up to 3 sit out."],
["armor", "SUPPORT CROUTON", "A little cube follows you and eats one bullet.", "Each rank: one crouton each round. Then it is crumbs."],
["lucky", "SOUP WARRANT", "Stand still and a bowl arrests hostile shots.", "Each rank: a quicker bowl and one more arrest."],
["oil", "NONSTICK SNEAKERS", "Oil slows you less. Flops grease monsters.", "Skid: 6px/rank (max 18). Slow: 1s/rank. No oil penalty at rank 3."],
["wind", "GRUDGE FORK", "Losing a heart plants a fork in that tile.", "Stepping on it pins a monster. Walk back to pick it up."],
["sense", "SPIKE SYRUP", "Earlier trap warnings. Monsters stick to lit spikes.", "Each rank: +0.3s warning, so stuck monsters wait longer for the spike."],
["gourmet", "FLOOR SAUCE", "Trap kills burst into hot sauce (30px).", "Each rank: +100 points per trap kill and +1 sauce damage. Rank 1 sauce: 2."],
["gate", "DOOR CRASHER", "Opening a gate blasts nearby guards.", "Each rank: +3 damage."],
["bonus", "PIT OLIVE", "An olive loads. Hold Z and the next shot is it.", "It pops neighbors. Auto-fire will not spend it."],
["leech", "SNACK INSURANCE", "4 kill credits restore a shield.", "Extra ranks: -1 needed (min 2). Late reinforcements give less credit."],
["pulse", "PERSONAL SPACE", "A knockback pulse fires every 5s.", "Each rank: +1 damage, wider pulse."],
["slow", "COLD SODA AURA", "Nearby monsters move 15% slower.", "Each rank: +15%; within 60px."],
["star", "STAR SODA", "Stars grant 2s more invulnerability.", "Each rank: another 2s."],
["crumbscore", "FLYING SAUCER", "A plate ahead of you bats shots back.", "One swat per rank, up to 3. It recharges after it cracks."],
["eject", "EMERGENCY EJECT", "Losing HP clears hostile bullets.", "Each rank: also stuns enemies for 1s."],
["snare", "STICKY FINGERS", "Snacks slow nearby enemies.", "Each rank: +1s of slow within 60px."],
["splash", "SMART SAUCE", "Cannon auto-aims at visible foes; hits splash neighbors.", "Each rank: +1 splash; struck foe not hit twice. Hold Z to aim by hand."],
["munch", "CHOMP CHOMP", "Eating bites foes within 30px and dazes them 0.4s.", "Each rank: +1 bite damage. Rank 1 bite: 2."],
["restock", "POCKET SNACK", "Start each round with a radial volley.", "Each rank: +4 shots and 1 shield."]
]
static func definition(id: String) -> Array:
	for entry in ITEMS:
		if entry[0] == id: return entry
	return []

const RARITY_NAMES = ["COMMON", "RARE", "EPIC", "LEGENDARY"]
static func rarity(index: int) -> int:
	if index in [10,11,23,47]: return 3
	if index in [2,3,5,7,8,17,21,29,40,48]: return 2
	if index%2==0: return 1
	return 0
static func roll(tier: int,ranks: Dictionary) -> Array:
	var pool: Array=[]
	var weights: Array=[]
	var total=0
	for i in ITEMS.size():
		if int(ranks.get(ITEMS[i][0],0))>=3: continue
		var weights_by_tier=[[65,25,9,1],[20,48,27,5],[0,15,55,30]][tier]
		var weight=weights_by_tier[rarity(i)]
		pool.append(ITEMS[i]); weights.append(weight); total+=weight
	if total<=0: return []
	var ticket=randi_range(1,total)
	for i in pool.size():
		ticket-=weights[i]
		if ticket<=0: return pool[i]
	return pool.back()
static func rarity_for(id: String) -> int:
	for i in ITEMS.size():
		if ITEMS[i][0]==id: return rarity(i)
	return 0
