extends RefCounted
# Stage rewards are distinct from chest items. These change a whole build at once.
const ITEMS = [
["gatling","GATLING GOURMET","Grow two spicy cannons.","Faster fire + extra shots.",{"pepper":2,"rapid":1,"spread":1}],
["toxic","BIOHAZARD LICENSE","Weaponize your bad manners.","Huge, hot, lingering gas.",{"gas":2,"giant":1,"spicy":2,"stink":1}],
["candy","CANDY APOCALYPSE","Every bite becomes a weapon.","Donut volleys + fifth-bite blast.",{"sprinkles":2,"nova":2,"munch":1}],
["carousel","SNACK SOLAR SYSTEM","Become a three-donut planet.","Orbiters + pulse + knockback.",{"orbit":3,"pulse":1,"knock":1}],
["fondue","FROZEN FONDUE","Pizza becomes a freezing lake.","Cheese pools freeze enemies.",{"cheese":3,"frost":2,"stink":1}],
["popcorn","POPCORN ARMAGEDDON","Kills cause explosive chains.","Popcorn blasts + lightning.",{"bomb":2,"chain":2}],
["bulldozer","BELLY BULLDOZER","Your belly is a siege weapon.","Fast flops, and a crouton eats one bullet.",{"dash":3,"spicy":2,"armor":1}],
["pinball","PEPPERONI PINBALL","Turn corridors into a blender.","Bouncing, piercing, long shots.",{"ricochet":3,"pierce":2,"range":2}],
["inspector","HEALTH INSPECTOR","Turn the kitchen against them.","Deadly traps + crumb mines.",{"trap":3,"gourmet":2,"trail":2}],
["bodyguard","BUBBLE BODYGUARD","Gain +2 max HP and heal 2.","Refill shields; shields explode.",{"shield":2,"shieldpop":2}],
["royalty","PANTRY ROYALTY","Gain two keys and 40 coins.","Doors explode. Keys empower.",{"gate":3,"key":2}],
["cashback","HOSTILE TAKEOVER","Kills pay 50% more per rank.","30 coins, heal 1, and one olive rank.",{"combo":2,"bonus":1}],
["rink","ROLLER RINK","Oil never slows you. Keep moving to build speed.","Each pick: builds up to +10% speed over 1s of moving. Stopping resets it.",{"oil":3}],
["bounce","BOUNCE HOUSE","Flops recover fast and kick off a speed burst.","Each pick: -0.25s flop wait, +0.5s burst, +1 Pizza Turbo.",{"pizza":1}]
]
static func definition(id: String) -> Array:
	for p in ITEMS:
		if p[0]==id: return p
	return []
static func candidates(owned: Dictionary) -> Array:
	var pool=[]
	for p in ITEMS:
		if int(owned.get(p[0],0))<3: pool.append(p)
	pool.shuffle()
	return pool.slice(0,3)
