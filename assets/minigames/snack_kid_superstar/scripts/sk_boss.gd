extends RefCounted
# Final-course boss. The game owns the enemy dictionary; this object owns the pattern and damage rules.
# Placeholder name: not Story Bible canon.
const NAME = "KING CALZONE"
const MAX_HP = 190.0
const SIZE = 6.0          # added to blast and zone radii so area effects reach the big body
const BODY = Vector2(16,11) # oval half extents of the drawn dome and base, for shots and contact
const HIT_CAP = 10.0      # most raw damage one hit can deal
const ARMOR = 0.6         # damage taken while guarded; weak builds still chip, strong builds hit GUARD_DPS
const OPEN = 1.25         # damage taken while dizzy or winded
const GUARD_DPS = 6.0     # damage bucket refill per second while guarded
const OPEN_DPS = 30.0     # damage bucket refill per second while open
const STUN_CAP = 0.5      # longest stun any source can apply
const CC_IMMUNE = 5.0     # stun immunity after a stun lands
const SLOW_SCALE = 0.75   # slows only cost the boss a quarter of its speed
const MINION_CAP = 4
const PHASE_FLOORS = [0.66,0.33,0.0]
const PATTERNS = [["ring","slam","rain","slam"],["slam","ring","summon","rain"],["slam","rain","ring","summon"]]
const ARENA = [
"###################",
"#.................#",
"#.................#",
"#...##.......##...#",
"#...##...^...##...#",
"#.................#",
"#.....^.....^.....#",
"#.................#",
"#...##...^...##...#",
"#...##.......##...#",
"#.................#",
"#.................#",
"###################"
]
const START = Vector2(152,40)
const PLAYER_START = Vector2(152,184)
const CALLOUTS = {"intro":"THE FINAL COURSE","stalk":"GUARDED: LURE IT ONTO SPIKES","ring_warn":"PIZZA WHEEL: FIND THE GAP","slam_warn":"BELLY SLAM: STEP ASIDE","slam":"BELLY SLAM!","rain_warn":"MEATBALLS: LEAVE THE RINGS","summon_warn":"SOUS CHEFS INCOMING","dizzy":"DIZZY! FULL DAMAGE NOW","winded":"WINDED! HIT IT","roar":"STEAMING! GRAB THE PIZZA"}
var enemy: Dictionary = {}
var hp_f = MAX_HP
var phase = 1
var action = "intro"
var timer = 1.6
var step = -1
var budget = GUARD_DPS
var cc_immune = 0.0
var stunned = 0.0
var defeated = false
var aim = Vector2.DOWN
var gap = 0
var rings_left = 0
var slams_left = 0
var marks: Array = []
var note_cd = 0.0
var wake = 0.0
var stagger_cd = 0.0
var spike_cd = 0.0
const STAGGER_CD = 6.0    # a shield popped during the boss fight winds it at most this often
func spawn() -> Dictionary:
	enemy={"p":START,"home":START,"kind":7,"hp":int(MAX_HP),"max_hp":int(MAX_HP),"slow":0.0,"stun":0.0,"cool":0.0,"attack":0.0,"dir":Vector2.DOWN,"tick":0.0,"goal":START,"boss":true,"size":SIZE,"body":BODY}
	return enemy
func is_open() -> bool:
	return action in ["dizzy","winded"]
func dps_cap() -> float:
	return OPEN_DPS if is_open() else GUARD_DPS
func warn_time() -> float:
	return [1.0,0.9,0.8][phase-1]
func ring_count() -> int:
	return [10,12,14][phase-1]
func in_gap(i: int) -> bool:
	return posmod(i-gap,ring_count())<3
func callout() -> String:
	if defeated: return NAME+" IS TOAST!"
	if stunned>0: return "STUNNED! HIT IT"
	return CALLOUTS.get(action,"")
func update(g, dt: float) -> void:
	if defeated: return
	var e=enemy
	budget=minf(dps_cap(),budget+dps_cap()*dt)
	cc_immune=maxf(0.0,cc_immune-dt)
	note_cd=maxf(0.0,note_cd-dt)
	wake=maxf(0.0,wake-dt)
	stagger_cd=maxf(0.0,stagger_cd-dt)
	spike_cd=maxf(0.0,spike_cd-dt)
	e.tick=maxf(0.0,float(e.tick)-dt)
	absorb_cc(g,e)
	var scale=SLOW_SCALE if float(e.slow)>0 else 1.0
	e.slow=maxf(0.0,float(e.slow)-dt)
	if stunned>0:
		stunned=maxf(0.0,stunned-dt)
		touch(g,e)
		return
	timer-=dt
	match action:
		"intro":
			if timer<=0: next_action(g)
		"stalk":
			if g.player.distance_to(e.p)>40:
				e.p=g.move_actor(e.p,(g.player-e.p).normalized()*20.0*scale*dt,10.0)
			if timer<=0: next_action(g)
		"ring_warn":
			if timer<=0: fire_ring(g)
		"slam_warn":
			if timer<=0: action="slam"; timer=1.6
		"slam":
			var want=aim*[130.0,145.0,160.0][phase-1]*scale*dt
			var moved=g.move_actor(e.p,want,10.0)
			var blocked=moved.distance_to(e.p)<want.length()*0.35
			e.p=moved
			if blocked or timer<=0: end_slam(g)
		"rain_warn":
			if timer<=0: drop_meatballs(g)
		"summon_warn":
			if timer<=0: summon(g)
		"dizzy","winded","roar":
			if timer<=0: action="stalk"; timer=0.7; wake=0.5
	e.goal=e.p
	touch(g,e)
func absorb_cc(g,e: Dictionary) -> void:
	if float(e.stun)>0:
		if cc_immune<=0 and action!="roar":
			stunned=minf(float(e.stun),STUN_CAP)
			cc_immune=CC_IMMUNE
			g.effects.append({"p":e.p+Vector2(0,-20),"life":0.6,"radius":0,"color":g.BLUE,"text":"STUN"})
		e.stun=0.0
	e.slow=minf(float(e.slow),1.5)
func touch(g,e: Dictionary) -> void:
	# Only a moving boss hurts on contact, so walking in to punish an open boss is safe.
	if not g.hero_touch(e): return
	if g.star_time>0 or g.flop_time>0:
		if float(e.tick)<=0: g.damage_enemy(e,5 if g.star_time>0 else 1+g.rank("dash")+g.rank("spicy"))
	elif stunned<=0 and wake<=0 and action in ["stalk","slam"]:
		var before=g.hp+g.shields
		g.hurt()
		if action=="slam" and g.hp+g.shields<before: end_slam(g)
func next_action(g) -> void:
	var pattern: Array=PATTERNS[phase-1]
	step=(step+1)%pattern.size()
	begin(g,pattern[step])
func begin(g,name: String) -> void:
	match name:
		"ring":
			gap=randi()%ring_count()
			rings_left=2 if phase==3 else 1
			action="ring_warn"; timer=warn_time()
		"slam":
			aim_at(g)
			slams_left=2 if phase==3 else 1
			action="slam_warn"; timer=warn_time()+0.1
		"rain":
			marks.clear()
			for i in [3,4,5][phase-1]:
				var spot=g.player if i==0 else g.player+Vector2.from_angle(randf()*TAU)*randf_range(26,44)
				if not g.solid(g.tile_at(spot)): marks.append({"p":spot})
			action="rain_warn"; timer=1.1
		"summon":
			action="summon_warn"; timer=0.6
func aim_at(g) -> void:
	aim=(g.player-enemy.p).normalized()
	if aim.length()<0.5: aim=Vector2.DOWN
func ring_dir(i: int, offset: float) -> Vector2:
	return Vector2.from_angle(i*TAU/ring_count()+offset)
func fire_ring(g) -> void:
	var offset=0.0 if rings_left>1 or phase<3 else PI/ring_count()
	for i in ring_count():
		if in_gap(i): continue
		g.fire(enemy.p,ring_dir(i,offset),1,true)
		if not g.shots.is_empty(): g.shots.back().v*=0.7; g.shots.back()["boss"]=true
	rings_left-=1
	if rings_left>0: action="ring_warn"; timer=0.45
	else: recover("winded",1.6)
func end_slam(g) -> void:
	g.shake=3 if g.shake_enabled else 0
	g.effects.append({"p":enemy.p,"life":0.4,"radius":22,"color":g.GOLD,"text":""})
	slams_left-=1
	if slams_left>0:
		aim_at(g)
		action="slam_warn"; timer=0.75
	else: recover("dizzy",[2.4,2.2,2.5][phase-1])
func drop_meatballs(g) -> void:
	for m in marks:
		g.effects.append({"p":m.p,"life":0.3,"radius":14,"color":g.PINK,"text":""})
		if g.player.distance_to(m.p)<13: g.hurt()
		for e in g.enemies.duplicate():
			if e.get("boss",false) or int(e.hp)<=0: continue
			if e.p.distance_to(m.p)<14: g.damage_enemy(e,3,true)
	marks.clear()
	recover("winded",1.5)
func summon(g) -> void:
	var alive=g.enemies.size()-1+g.pending_spawns.size()
	for i in mini(2,MINION_CAP-alive): g.queue_spawn(randi_range(0,2))
	recover("winded",1.8)
func stagger(g) -> void:
	# A shield popped by any boss-fight hit winds the boss: the defensive build's punish window.
	if defeated or stagger_cd>0 or stunned>0 or action in ["intro","roar","dizzy","winded"]: return
	stagger_cd=STAGGER_CD
	marks.clear()
	recover("winded",1.4)
	g.effects.append({"p":enemy.p+Vector2(0,-22),"life":0.8,"radius":0,"color":g.GREEN,"text":"POPPED!"})
func recover(name: String, seconds: float) -> void:
	action=name; timer=seconds
	budget=maxf(budget,OPEN_DPS*0.5)
func take_hit(g,e: Dictionary,amount: float,trap: bool=false) -> float:
	if defeated or g.state!="play" or g.hp<=0: return 0.0
	if action in ["intro","roar"]:
		note(g,"NOPE")
		return 0.0
	# Kitchen hazards ignore the guard and the damage bucket; HIT_CAP and phase floors still apply.
	var dmg=minf(amount,HIT_CAP)*(OPEN if is_open() or trap else ARMOR)
	if trap: note(g,"SPIKED!")
	else:
		dmg=minf(dmg,budget)
		if dmg<=0.0:
			note(g,"MAXED" if is_open() else "GUARDED")
			return 0.0
		if not is_open(): note(g,"GUARDED")
		budget-=dmg
	var before=hp_f
	hp_f=maxf(0.0,hp_f-dmg)
	e.tick=0.15
	var floor_hp=MAX_HP*PHASE_FLOORS[phase-1]
	if phase<3 and hp_f<=floor_hp:
		hp_f=floor_hp
		roar(g)
	e.hp=maxi(0,ceili(hp_f))
	if hp_f<=0.0:
		e.hp=0; defeated=true
		g.boss_down()
	return before-hp_f
func note(g,text: String) -> void:
	if note_cd>0: return
	note_cd=0.6
	g.effects.append({"p":enemy.p+Vector2(0,-22),"life":0.5,"radius":0,"color":g.BLUE,"text":text})
func roar(g) -> void:
	phase+=1; step=-1
	action="roar"; timer=1.6
	marks.clear(); stunned=0.0
	g.shots=g.shots.filter(func(s): return not s.hostile)
	g.drop_boss_snack()
	g.shake=4 if g.shake_enabled else 0
	g.announce(NAME+" IS STEAMING!")
func wall_hit(g,from: Vector2,dir: Vector2) -> Vector2:
	var p=from
	for i in 80:
		if g.solid(g.tile_at(p+dir*4)): break
		p+=dir*4
	return p
func draw(g) -> void:
	var p: Vector2=enemy.p.round()
	var blink=int(g.clock*10)%2==0
	match action:
		"ring_warn":
			var offset=0.0 if rings_left>1 or phase<3 else PI/ring_count()
			for i in ring_count():
				var d=ring_dir(i,offset)
				if in_gap(i): g.draw_line(p+d*20,p+d*24,g.GREEN,2)
				else: g.draw_line(p+d*16,p+d*(26 if blink else 22),g.PINK,1)
		"slam_warn":
			var side=Vector2(-aim.y,aim.x)*10
			var end=wall_hit(g,p,aim)
			var color=g.PINK if blink else g.GOLD
			g.draw_line(p+side,end+side,color)
			g.draw_line(p-side,end-side,color)
		"rain_warn":
			for m in marks:
				var fill=clampf(1.0-timer/1.1,0.0,1.0)
				g.draw_circle(m.p,14*fill,Color(g.PINK,0.3))
				g.draw_arc(m.p,14,0,TAU,16,g.PINK)
				g.label("!",m.p+Vector2(-2,4),g.PINK)
	if is_open() or stunned>0: g.draw_arc(p,19,0,TAU,20,g.GREEN,2)
	else: g.draw_arc(p,19,0,TAU,20,Color(g.BLUE,0.6))
	var crust=g.CREAM if float(enemy.tick)>0 else g.GOLD if is_open() or stunned>0 else Color("cb7142")
	var shell=PackedVector2Array(); var body=PackedVector2Array()
	for i in 13:
		var a=PI+i*PI/12
		shell.append(p+Vector2(cos(a)*17,sin(a)*15+5))
		body.append(p+Vector2(cos(a)*15,sin(a)*13+5))
	g.draw_colored_polygon(shell,g.INK)
	g.draw_colored_polygon(body,crust)
	g.draw_rect(Rect2(p+Vector2(-17,5),Vector2(34,5)),g.INK)
	for x in range(-15,14,4): g.draw_rect(Rect2(p+Vector2(x,5),Vector2(3,3)),Color("cb7142"))
	for spot in [Vector2(-10,-3),Vector2(2,-7),Vector2(8,-1)]: g.draw_rect(Rect2(p+spot,Vector2(3,3)),g.PINK)
	var squint=1 if is_open() else 3
	g.draw_rect(Rect2(p+Vector2(-6,-1),Vector2(2,squint)),g.INK)
	g.draw_rect(Rect2(p+Vector2(4,-1),Vector2(2,squint)),g.INK)
	if action.ends_with("_warn") or action=="slam":
		g.draw_line(p+Vector2(-8,-4),p+Vector2(-4,-2),g.INK)
		g.draw_line(p+Vector2(8,-4),p+Vector2(4,-2),g.INK)
	g.draw_colored_polygon(PackedVector2Array([p+Vector2(-7,-9),p+Vector2(-7,-15),p+Vector2(-3,-12),p+Vector2(0,-17),p+Vector2(3,-12),p+Vector2(7,-15),p+Vector2(7,-9)]),g.GOLD)
	g.draw_rect(Rect2(p+Vector2(-1,-12),Vector2(2,2)),g.PINK)
	if is_open() or stunned>0:
		for i in 3:
			var star=p+Vector2(0,-20)+Vector2.from_angle(g.clock*5+i*TAU/3)*9
			g.draw_rect(Rect2(star-Vector2.ONE,Vector2(2,2)),g.CREAM)
		g.label("OPEN",p+Vector2(-11,-24),g.GREEN)
	if action=="roar":
		for i in 3: g.draw_line(p+Vector2(-8+i*8,-18),p+Vector2(-6+i*8+(2 if blink else -2),-26),g.CREAM)
