extends Node2D
signal game_over
signal round_cleared(round_number: int)
signal exit_requested
signal boss_defeated
## Host sets arcade_mode before add_child. Emitted once after initials, not on a host exit.
signal arcade_finished(result: Dictionary)
var arcade_mode := false:
	set(value):
		arcade_mode = value
		if value and is_inside_tree():
			process_mode = Node.PROCESS_MODE_ALWAYS
var _run_started := false
var _terminal := ""
var _arcade_emitted := false
var _held := {}
const Perks = preload("sk_perks.gd")
const Items = preload("sk_items.gd")
const Audio = preload("sk_audio.gd")
const Boss = preload("sk_boss.gd")
const HERO = preload("../sprites/sk_player_original.png")
const FONT = preload("../sprites/sk_pixel_font.ttf")
const TILE = 16.0
const ORIGIN = Vector2(0,36)
const INK = Color("261820")
const CREAM = Color("fff7de")
const GOLD = Color("f9be4c")
const PINK = Color("fa77aa")
const GREEN = Color("8ec34b")
const BLUE = Color("55b9ce")
const DIRS = [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
# Threat rises with time spent on the current stage. Reinforcement kills pay THREAT_PAY of normal.
const THREAT_STEP = 40.0
const THREAT_MAX = 5
const THREAT_PAY = [1.0,0.85,0.55,0.3,0.12]
const THREAT_SCORE = [0.5,0.3,0.15,0.08,0.04]
const QUICK_EXIT = [2000,1000,400,0,0]
const THREAT_SPAWN = [1.0,0.85,0.7,0.55,0.45]
const THREAT_COLORS = [Color("8ec34b"),Color("f9be4c"),Color("fa77aa"),Color("f56741"),Color("be2f25")]
var audio: Node
var rounds: Array = []
var board: Array = []
var snacks: Dictionary = {}
var enemies: Array = []
var shots: Array = []
var zones: Array = []
var effects: Array = []
var ranks: Dictionary = {}
var choices: Array = []
var scores: Array = []
var state = "title"
var level = 0
var hp = 3
var max_hp = 3
var coins = 0
var keys = 0
var item_count = 0
var draft_ranks: Dictionary = {}
var perk_bonuses: Dictionary = {}
var chests: Dictionary = {}
var gates: Dictionary = {}
var exit_tile = Vector2i(1,1)
var run_time = 0.0
var spawn_cd = 12.0
var pending_spawns: Array = []
var item_history: Array = []
var loans: Array = []
var reveal_time = 0.0
var reveal_title = ""
var reveal_body = ""
var last_perk = ""
var heal_flash = 0.0
var croutons = 0
var fork_ready = 0
var forks: Array = []
var soup_time = 0.0
var soup_shots = 0
var pickles: Array = []
var saucer_swats = 0
var saucer_crack = 0.0
var olive_time = 0.0
var olive_ready = false
var inventory_page = 0
var camera = Vector2.ZERO
var score = 0
var shields = 0
var player = Vector2(36,36)
var facing = Vector2.RIGHT
# Cannon direction: the newest cardinal movement keydown. Movement itself keeps diagonal `facing`.
var shot_dir = Vector2.RIGHT
const AIM_KEYS = {KEY_W:Vector2.UP,KEY_UP:Vector2.UP,KEY_A:Vector2.LEFT,KEY_LEFT:Vector2.LEFT,KEY_S:Vector2.DOWN,KEY_DOWN:Vector2.DOWN,KEY_D:Vector2.RIGHT,KEY_RIGHT:Vector2.RIGHT}
var elapsed = 0.0
var clock = 0.0
var invincible = 0.0
var star_time = 0.0
var flop_time = 0.0
var flop_cd = 0.0
var attack_cd = 0.0
var gas_cd = 2.0
var pulse_cd = 3.0
var sugar_time = 0.0
var pizza_time = 0.0
var glide_time = 0.0
var intro_time = 0.0
var combo_time = 0.0
var combo = 0
var eaten = 0
var kills = 0
var key_found = false
var gate_open = false
var rescued = false
var clean = true
var selected = 0
var starter_draft = false
var moving = false
var initials = ""
var notice = ""
var notice_time = 0.0
var nav: Dictionary = {}
var nav_cd = 0.0
var save_enabled = true
var closed = false
var shake = 0.0
var shake_enabled = true
var save_root: String
var boss = null
var boss_mode = false
var boss_won = false
var victory_time = 0.0
var leech_meter = 0.0
var threat_seen = 1
var last_quick = 0
func _ready() -> void:
	if arcade_mode:
		process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var base = get_script().resource_path.get_base_dir() + "/.."
	rounds = JSON.parse_string(FileAccess.get_file_as_string(base + "/data/rounds.json"))
	save_root = "user://snack_kid_superstar"
	if ProjectSettings.get_setting("snack_kid/local_saves",false): save_root = (base + "/saves/runtime").simplify_path()
	DirAccess.make_dir_recursive_absolute(save_root)
	audio = Audio.new()
	add_child(audio)
	var score_path = save_root + "/scores.json"
	if not FileAccess.file_exists(score_path):
		score_path = base + "/saves/scores.json"
	if FileAccess.file_exists(score_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(score_path))
		if data is Array:
			for entry in data:
				if entry is Dictionary and entry.has("name") and entry.has("score"): scores.append(entry)
	if arcade_mode:
		# A held confirmation opened the cabinet. Require a fresh press for the draft.
		_held["j%d" % JOY_BUTTON_A] = _joy_held(JOY_BUTTON_A)
	if arcade_mode or "--smoke" in OS.get_cmdline_user_args(): new_run()
func shutdown() -> void:
	if closed: return
	closed=true
	set_process(false)
	set_process_unhandled_input(false)
	if audio and is_instance_valid(audio) and audio.has_method("shutdown"): audio.shutdown()
func _exit_tree() -> void:
	shutdown()
func rank(id: String) -> int:
	# The pepper cannon is the free starter weapon, so its rank is never zero.
	return mini(12,int(ranks.get(id,0))+int(perk_bonuses.get(id,0))+(1 if id=="pepper" else 0))
func cannon_delay() -> float:
	var delay=1.05*(1.0-rank("rapid")*0.07)
	if sugar_time>0: delay*=0.6
	return maxf(0.08,delay)
func perk(id: String) -> int:
	return mini(3,int(draft_ranks.get(id,0)))
func flop_delay() -> float:
	return maxf(0.32,2.8-rank("dash")*0.2-perk("bounce")*0.25)
func glide_bonus() -> float:
	return 0.1*perk("rink")*clampf(glide_time,0.0,1.0)
func flop_speed() -> float:
	return 150.0+rank("speed")*18.0+rank("dash")*8.0
func fan_scale() -> float:
	return 1.0
func oil_scale() -> float:
	return clampf(0.5+rank("oil")/6.0,0.5,1.0)
func slow_scale() -> float:
	return maxf(0.25,1.0-rank("slow")*0.15)
func trap_warn() -> float:
	return maxf(0.4,2.2-rank("sense")*0.3)
func dodge_chance() -> float:
	return 0.0
func soup_need() -> float:
	return maxf(0.55,1.25-rank("lucky")*0.2)
func refresh_companions() -> void:
	croutons=rank("armor")
	forks.clear()
	fork_ready=rank("wind")
	soup_time=0
	soup_shots=0
	pickles.clear()
	saucer_swats=mini(3,rank("crumbscore"))
	saucer_crack=0
	olive_time=0
	olive_ready=false
func crouton_anchor(index: int) -> Vector2:
	return player+Vector2.from_angle(elapsed*2.2+index*1.7)*14
func plant_fork() -> void:
	if fork_ready<=0: return
	fork_ready-=1
	forks.append({"p":player,"age":0.0})
func arrest_bullet(s: Dictionary) -> bool:
	if soup_shots>0 and s.p.distance_to(player)<22:
		soup_shots-=1
		if soup_shots<=0: soup_time=0
		effects.append({"p":s.p,"life":0.25,"radius":8,"color":GOLD,"text":""})
		return true
	if croutons>0 and s.p.distance_to(player)<16:
		var crumb=crouton_anchor(mini(croutons-1,3))
		croutons-=1
		effects.append({"p":crumb,"life":0.3,"radius":7,"color":Color("cb7142"),"text":""})
		return true
	return false
func update_toys(dt: float) -> void:
	if rank("lucky")>0 and not moving:
		soup_time+=dt
		if soup_time>=soup_need() and soup_shots<=0: soup_shots=rank("lucky")
	else:
		soup_time=0
		if moving: soup_shots=0
	for e in enemies:
		if e.has("fork_cd"): e.fork_cd=maxf(0.0,float(e.fork_cd)-dt)
	var kept: Array=[]
	for fork in forks:
		fork.age=float(fork.age)+dt
		if float(fork.age)>0.35 and moving and player.distance_to(fork.p)<12:
			fork_ready+=1
			effects.append({"p":fork.p,"life":0.2,"radius":6,"color":GOLD,"text":""})
			continue
		for e in enemies:
			if int(e.hp)<=0: continue
			if e.p.distance_to(fork.p)<12+girth(e) and float(e.get("fork_cd",0))<=0:
				e.stun=maxf(float(e.stun),0.55+rank("wind")*0.15)
				e.fork_cd=float(e.stun)+0.35
		kept.append(fork)
	forks=kept
	var sitting: Array=[]
	for pickle in pickles:
		pickle.life=float(pickle.life)-dt
		if float(pickle.life)<=0: continue
		var tripped=false
		for e in enemies:
			if int(e.hp)<=0: continue
			if e.p.distance_to(pickle.p)<12+girth(e):
				damage_enemy(e,mini(3,rank("finish")))
				e.stun=maxf(float(e.stun),0.5)
				effects.append({"p":pickle.p,"life":0.25,"radius":8,"color":GREEN,"text":""})
				tripped=true
				break
		if not tripped: sitting.append(pickle)
	pickles=sitting
	if rank("crumbscore")<=0:
		saucer_swats=0
		saucer_crack=0
	elif saucer_crack>0:
		saucer_crack=maxf(0.0,saucer_crack-dt)
		if saucer_crack<=0: saucer_swats=mini(3,rank("crumbscore"))
	elif saucer_swats<=0:
		saucer_swats=mini(3,rank("crumbscore"))
	if rank("bonus")<=0:
		olive_ready=false
		olive_time=0
	elif not olive_ready:
		olive_time+=dt
		if olive_time>=maxf(1.1,2.6-0.4*mini(3,rank("bonus"))): olive_ready=true
func drop_pickle() -> void:
	var cap=mini(3,rank("finish"))
	if cap<=0: return
	while pickles.size()>=cap: pickles.pop_front()
	pickles.append({"p":player,"life":5.0})
func saucer_anchor() -> Vector2:
	var dir=facing if facing.length()>0.2 else Vector2.RIGHT
	return player+dir.normalized()*22
func swat_saucer(s: Dictionary) -> bool:
	if saucer_swats<=0 or rank("crumbscore")<=0: return false
	var plate=saucer_anchor()
	if s.p.distance_to(plate)>14 or s.p.distance_to(player)<12: return false
	if s.v.length()<1: s.v=Vector2.LEFT*90
	s.v=-s.v
	s.hostile=false
	s.damage=mini(3,rank("crumbscore"))
	s.bounce=0
	s.pierce=0
	if not s.has("hit"): s["hit"]=[]
	saucer_swats-=1
	if saucer_swats<=0: saucer_crack=3.5
	effects.append({"p":plate,"life":0.2,"radius":8,"color":CREAM,"text":""})
	return true
func move_speed() -> float:
	var speed=48.0*(1.0+rank("speed")*0.12+(0.3 if pizza_time>0 else 0.0)+glide_bonus())
	return minf(speed,240.0)
func enemy_hp(kind: int) -> int:
	var amount=2+int(level*0.5)+int(minf(3.0,run_time/80.0))+int((threat_tier()-1)*0.75)
	if kind==5: amount+=3
	if kind==4: amount+=1
	return amount
func tile_at(p: Vector2) -> Vector2i:
	return Vector2i(floor(p.x/TILE),floor(p.y/TILE))
func center(t: Vector2i) -> Vector2:
	return (Vector2(t)+Vector2(0.5,0.5))*TILE
func cell(t: Vector2i) -> String:
	if t.x<0 or t.y<0 or t.x>=19 or t.y>=13: return "#"
	return board[t.y][t.x]
func solid(t: Vector2i) -> bool:
	return cell(t)=="#" or (cell(t)=="G" and not gates.get(t,{}).get("open",false))
func clear_line(a: Vector2,b: Vector2) -> bool:
	var steps = maxi(1,int(a.distance_to(b)/4))
	for i in range(steps+1):
		if solid(tile_at(a.lerp(b,float(i)/steps))): return false
	return true
func fits(p: Vector2, radius: float=4.5) -> bool:
	for corner in [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(-radius,radius),Vector2(radius,radius)]:
		if solid(tile_at(p+corner)): return false
	return true
func move_actor(p: Vector2, delta: Vector2, radius: float=4.5) -> Vector2:
	var steps = maxi(1,int(ceil(delta.length()/3.0)))
	for i in steps:
		var d = delta/steps
		if fits(p+Vector2(d.x,0),radius): p.x+=d.x
		if fits(p+Vector2(0,d.y),radius): p.y+=d.y
	return p
func girth(e: Dictionary) -> float:
	return float(e.get("size",0.0))
# Visible-body contacts. Wall movement keeps its own fits()/move_actor() box.
# The 16x20 hero is drawn from player+(-8,-12); its hurt capsule sits 2px inside that outline.
const HERO_TOP = Vector2(0,-4.5)
const HERO_FEET = Vector2(0,0.5)
const HERO_R = 5.5
const ENEMY_BODY = Vector2(7,7)
const DONUT_R = 5.0
const SHOT_R = 1.5
const OLIVE_R = 2.5
const ORBIT_REACH = 20.0
func hero_center() -> Vector2:
	return player+Vector2(0,-2)
func body_half(e: Dictionary) -> Vector2:
	return e.get("body",ENEMY_BODY)
func seg_dist(p: Vector2,a: Vector2,b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
# Does a round thing of radius r, moving a->b, touch this enemy's oval body?
func body_sweep(e: Dictionary,a: Vector2,b: Vector2,r: float=0.0) -> bool:
	var half=body_half(e)+Vector2(r,r)
	return seg_dist(Vector2.ZERO,(a-e.p)/half,(b-e.p)/half)<1.0
func body_hit(e: Dictionary,q: Vector2,r: float=0.0) -> bool:
	return body_sweep(e,q,q,r)
func hero_touch(e: Dictionary) -> bool:
	return body_sweep(e,player+HERO_TOP,player+HERO_FEET,HERO_R)
func hero_swept(a: Vector2,b: Vector2,r: float) -> bool:
	var top=player+HERO_TOP; var feet=player+HERO_FEET
	if Geometry2D.segment_intersects_segment(a,b,top,feet)!=null: return true
	return minf(minf(seg_dist(a,top,feet),seg_dist(b,top,feet)),minf(seg_dist(top,a,b),seg_dist(feet,a,b)))<HERO_R+r
func shot_radius(s: Dictionary) -> float:
	return OLIVE_R if s.get("olive",false) else SHOT_R
func orbiters() -> Array:
	var count=rank("orbit"); var hub=hero_center(); var list=[]
	for i in count:
		var p=hub+Vector2.from_angle(elapsed*3+i*TAU/count)*ORBIT_REACH
		list.append({"p":p,"clear":clear_line(hub,p)})
	return list
func bonk_orbiters() -> void:
	# Same list as the draw. A dim (walled) donut never hits, and no hit reaches around a corner.
	for orbiter in orbiters():
		if not orbiter.clear: continue
		for enemy in enemies.duplicate():
			if enemy.hp>0 and enemy.tick<=0 and body_hit(enemy,orbiter.p,DONUT_R) and clear_line(orbiter.p,enemy.p):
				damage_enemy(enemy,1); enemy.tick=0.5
func threat_tier() -> int:
	if boss_mode: return 1
	return mini(THREAT_MAX,1+int(elapsed/THREAT_STEP))
func threat_next() -> float:
	if threat_tier()>=THREAT_MAX: return -1.0
	return threat_tier()*THREAT_STEP-elapsed
func threat_pay() -> float:
	return THREAT_PAY[threat_tier()-1]
func new_run() -> void:
	# The host already paid for one run. Pause-R and the title screen cannot start another.
	if arcade_mode and _run_started:
		return
	_run_started = true
	level=0; hp=3; max_hp=3; score=0; coins=0; keys=0; item_count=0
	ranks.clear(); draft_ranks.clear(); perk_bonuses.clear(); item_history.clear(); loans.clear()
	rescued=false; kills=0; eaten=0; run_time=0; starter_draft=true
	boss=null; boss_mode=false; boss_won=false; victory_time=0; leech_meter=0; last_quick=0
	shot_dir=Vector2.RIGHT; facing=Vector2.RIGHT
	last_perk=""; reveal_time=0; heal_flash=0
	load_round()
	choices=Perks.candidates(draft_ranks); selected=0; state="choice"
	audio.play("start")
func load_round() -> void:
	boss=null; boss_mode=false; threat_seen=1
	board=rounds[level].rows.duplicate()
	normalize_round()
	snacks.clear(); enemies.clear(); shots.clear(); zones.clear(); effects.clear()
	chests.clear(); gates.clear(); pending_spawns.clear(); spawn_cd=8
	exit_tile=Vector2i(1,1)
	key_found=false; gate_open=false; elapsed=0; clean=true; combo=0; combo_time=0
	invincible=2.5; star_time=0; flop_time=0; flop_cd=0; sugar_time=0; pizza_time=0; glide_time=0
	attack_cd=0.2; gas_cd=2; pulse_cd=3; nav_cd=0
	shields=rank("shield")+rank("restock")
	refresh_companions()
	for y in 13:
		for x in 19:
			var t=Vector2i(x,y)
			var c=cell(t)
			if c=="S": player=center(t)
			if c=="E": exit_tile=t
			if c in ["c","b","l"]: chests[t]={"tier":["c","b","l"].find(c),"open":false}
			if c=="G": gates[t]={"open":false,"mode":0,"charge":0.0}
			if c in ["d","p","$","K"]: snacks[t]=c
			if c.is_valid_int() and int(c)>0:
				var kind=int(c)-1
				enemies.append({"p":center(t),"home":center(t),"kind":kind,"hp":enemy_hp(kind),"slow":0.0,"stun":0.0,"cool":randf_range(1,3),"attack":0.0,"dir":Vector2.LEFT,"tick":0.0})
	# One mode per stage, shared by every door on that stage. Midnight's two wings are both loans.
	var door_mode=[0,1,2,3,0,3,2,3,1,0][mini(level,9)]
	var ordered: Array=gates.keys()
	ordered.sort_custom(func(a,b): return a.x<b.x or (a.x==b.x and a.y<b.y))
	for t in ordered: gates[t].mode=door_mode
	state="intro"; intro_time=1.8
	notice=""; notice_time=0
	if rank("restock")>0: radial(player,4+rank("restock")*4,1+rank("restock"))
func remaining() -> int:
	var n=0
	for c in snacks.values():
		if c in ["d","p"]: n+=1
	return n
func announce(message: String) -> void:
	notice=message; notice_time=2.0
func _unhandled_input(event: InputEvent) -> void:
	# Forwarded with SubViewport.push_input. A tap can be down and up before the next poll.
	if not event is InputEventKey or not event.pressed or event.echo: return
	var k: Key = event.keycode if event.keycode!=KEY_NONE else event.physical_keycode
	_handle_key(k, event)
func _handle_key(k: int, event: InputEvent) -> void:
	if _arcade_emitted: return
	if state in ["play","intro"]:
		var code=event.physical_keycode if event.physical_keycode!=KEY_NONE else event.keycode
		if AIM_KEYS.has(code): shot_dir=AIM_KEYS[code]
	if k==KEY_M: audio.muted=not audio.muted
	if k==KEY_N: audio.music_enabled=not audio.music_enabled
	if k==KEY_F: shake_enabled=not shake_enabled
	if state=="title":
		if k in [KEY_ENTER,KEY_SPACE]: new_run()
		elif k==KEY_H: state="scores"
		elif k==KEY_ESCAPE: exit_requested.emit()
	elif state=="play":
		if k in [KEY_ESCAPE,KEY_P]: state="pause"
		if k==KEY_I: state="inventory"; inventory_page=0
		if k==KEY_E: interact()
		if k==KEY_SPACE and flop_cd<=0: belly_flop()
	elif state=="pause":
		if k in [KEY_ESCAPE,KEY_P,KEY_ENTER]: state="play"
		elif k==KEY_R: new_run()
		elif k==KEY_Q and not arcade_mode: state="title"
		elif k==KEY_I: state="inventory"; inventory_page=0
	elif state=="inventory":
		if k in [KEY_I,KEY_ESCAPE,KEY_P]: state="play"
		if k in [KEY_RIGHT,KEY_D]: inventory_page+=1
		if k in [KEY_LEFT,KEY_A]: inventory_page=maxi(0,inventory_page-1)
	elif state=="choice":
		if starter_draft and k==KEY_ESCAPE:
			if not arcade_mode: state="title"
		else:
			var n=maxi(1,choices.size())
			if k in [KEY_LEFT,KEY_A,KEY_UP,KEY_W]: selected=posmod(selected-1,n)
			if k in [KEY_RIGHT,KEY_D,KEY_DOWN,KEY_S]: selected=posmod(selected+1,n)
			if k in [KEY_1,KEY_2,KEY_3] and k-KEY_1<choices.size(): selected=k-KEY_1
			if k in [KEY_ENTER,KEY_SPACE] and selected<choices.size(): take_perk(selected)
	elif state=="over":
		if k==KEY_BACKSPACE or k==KEY_LEFT: initials=initials.left(maxi(0,initials.length()-1))
		elif k==KEY_ENTER:
			scores.append({"name":initials if initials!="" else "KID","score":score,"round":level+1})
			scores.sort_custom(func(a,b):return int(a.score)>int(b.score))
			scores=scores.slice(0,10)
			if save_enabled:
				var f=FileAccess.open(save_root+"/scores.json",FileAccess.WRITE)
				if f: f.store_string(JSON.stringify(scores))
				else: announce("Score could not be saved")
			state="scores"
		elif k==KEY_RIGHT and initials.length()<3: initials+="A"
		elif k==KEY_UP: _cycle_initial(1)
		elif k==KEY_DOWN: _cycle_initial(-1)
		elif event.unicode>=65 and event.unicode<=122 and initials.length()<3:
			var letter=String.chr(event.unicode).to_upper()
			if letter>="A" and letter<="Z": initials+=letter
	elif state=="scores" and k in [KEY_ENTER,KEY_ESCAPE,KEY_SPACE]:
		if arcade_mode and _terminal!="":
			_finish_arcade(_terminal)
			return
		state="title"
func _cycle_initial(dir: int) -> void:
	var alphabet:="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	if initials.is_empty():
		initials=alphabet[0 if dir>0 else 25]
		return
	var ch=initials.substr(initials.length()-1,1)
	var i=alphabet.find(ch)
	i=0 if i<0 else posmod(i+dir,26)
	initials=initials.substr(0,initials.length()-1)+alphabet[i]
## outcome is the caller's label. terminal is "win" or "dead" only after end_run.
## stage is 0 until the paid run starts. boss_defeated is the real boss flag.
func get_arcade_result(outcome: String) -> Dictionary:
	var result:={
		"game":"snack_run",
		"outcome":outcome,
		"score":int(score),
		"stage":int(level)+1 if _run_started else 0,
		"hp":int(hp),
		"items":int(item_count),
		"kills":int(kills),
		"boss_defeated":bool(boss_won),
	}
	if _terminal!="": result["terminal"]=_terminal
	return result
func _finish_arcade(outcome: String) -> void:
	if _arcade_emitted: return
	_arcade_emitted=true
	var result:=get_arcade_result(outcome)
	arcade_finished.emit(result)
	if is_instance_valid(self): process_mode=Node.PROCESS_MODE_DISABLED
func _poll_input() -> void:
	if _arcade_emitted: return
	# Holds (stick, d-pad, olive) are read live, including a button already down at launch.
	# Discrete pad actions edge once. Keyboard taps arrive as real events, not a poll.
	_poll_pad()
func _poll_pad() -> void:
	if _joy_pressed(JOY_BUTTON_DPAD_LEFT) or _stick_pressed(-1,0): _handle_key(KEY_LEFT,_key_event(KEY_LEFT))
	if _joy_pressed(JOY_BUTTON_DPAD_RIGHT) or _stick_pressed(1,0): _handle_key(KEY_RIGHT,_key_event(KEY_RIGHT))
	if _joy_pressed(JOY_BUTTON_DPAD_UP) or _stick_pressed(0,-1): _handle_key(KEY_UP,_key_event(KEY_UP))
	if _joy_pressed(JOY_BUTTON_DPAD_DOWN) or _stick_pressed(0,1): _handle_key(KEY_DOWN,_key_event(KEY_DOWN))
	if _joy_pressed(JOY_BUTTON_B): _handle_key(KEY_BACKSPACE,_key_event(KEY_BACKSPACE))
	if _joy_pressed(JOY_BUTTON_X): _handle_key(KEY_E,_key_event(KEY_E))
	if _joy_pressed(JOY_BUTTON_Y): _handle_key(KEY_I,_key_event(KEY_I))
	# Back / LB pause. Start is game_pause and stays with the host.
	if _joy_pressed(JOY_BUTTON_BACK) or _joy_pressed(JOY_BUTTON_LEFT_SHOULDER): _handle_key(KEY_P,_key_event(KEY_P))
	if _joy_pressed(JOY_BUTTON_A):
		var k:=KEY_SPACE if state=="play" else KEY_ENTER
		_handle_key(k,_key_event(k))
func _move_input() -> Vector2:
	var keyboard_direction:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	return keyboard_direction+_pad_vector()
func _pad_vector() -> Vector2:
	var v:=Vector2.ZERO
	for d in Input.get_connected_joypads():
		var x:=Input.get_joy_axis(d,JOY_AXIS_LEFT_X)
		var y:=Input.get_joy_axis(d,JOY_AXIS_LEFT_Y)
		if x<=-0.5: v.x-=1.0
		elif x>=0.5: v.x+=1.0
		if y<=-0.5: v.y-=1.0
		elif y>=0.5: v.y+=1.0
		if Input.is_joy_button_pressed(d,JOY_BUTTON_DPAD_LEFT): v.x-=1.0
		if Input.is_joy_button_pressed(d,JOY_BUTTON_DPAD_RIGHT): v.x+=1.0
		if Input.is_joy_button_pressed(d,JOY_BUTTON_DPAD_UP): v.y-=1.0
		if Input.is_joy_button_pressed(d,JOY_BUTTON_DPAD_DOWN): v.y+=1.0
	return v
func _pad_cardinal() -> Vector2:
	var v:=_pad_vector()
	if v==Vector2.ZERO: return Vector2.ZERO
	if absf(v.x)>=absf(v.y): return Vector2(signf(v.x),0.0)
	return Vector2(0.0,signf(v.y))
func _manual_shot_held() -> bool:
	if Input.is_physical_key_pressed(KEY_Z): return true
	for d in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(d,JOY_BUTTON_RIGHT_SHOULDER): return true
		if Input.get_joy_axis(d,JOY_AXIS_TRIGGER_RIGHT)>=0.5: return true
	return false
func _joy_held(button: JoyButton) -> bool:
	for d in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(d,button): return true
	return false
func _joy_pressed(button: JoyButton) -> bool:
	return _edge("j%d"%button, _joy_held(button))
func _stick_pressed(x_sign: int, y_sign: int) -> bool:
	var v:=_pad_vector()
	var down:=false
	if x_sign<0: down=v.x<0.0
	elif x_sign>0: down=v.x>0.0
	elif y_sign<0: down=v.y<0.0
	elif y_sign>0: down=v.y>0.0
	return _edge("s%d_%d"%[x_sign,y_sign], down)
func _edge(id: String, down: bool) -> bool:
	var was: bool=bool(_held.get(id,false))
	_held[id]=down
	return down and not was
func _key_event(k: int) -> InputEventKey:
	var ev:=InputEventKey.new()
	ev.pressed=true
	ev.keycode=k as Key
	ev.physical_keycode=k as Key
	if k>=KEY_A and k<=KEY_Z: ev.unicode=k
	return ev
func take_perk(index: int) -> void:
	var item=choices[index]
	var id=item[0]
	draft_ranks[id]=int(draft_ranks.get(id,0))+1
	for bonus in item[4]: perk_bonuses[bonus]=int(perk_bonuses.get(bonus,0))+int(item[4][bonus])
	if id=="bodyguard": max_hp+=2; hp=mini(max_hp,hp+2)
	if id=="royalty": keys+=2; coins+=40
	if id=="cashback": coins+=30; hp=mini(max_hp,hp+1)
	last_perk=item[1]
	audio.play("perk")
	# Ten drafts all happen before the finale: one starter, then one after each of the first nine clears.
	if starter_draft:
		starter_draft=false
		load_round()
		announce(item[1])
		return
	if level>=9:
		end_run()
		return
	level+=1
	load_round()
	announce(item[1])
func belly_flop() -> void:
	drop_pickle()
	flop_time=0.22; flop_cd=flop_delay(); invincible=maxf(invincible,0.22)
	if perk("bounce")>0: pizza_time=maxf(pizza_time,0.5*perk("bounce"))
	var reach=25+rank("dash")*5
	blast(player,reach,1+rank("dash")+rank("spicy"),GOLD)
	if rank("oil")>0: grease(reach)
func grease(reach: float) -> void:
	for e in enemies:
		if int(e.hp)<=0 or e.p.distance_to(player)>=reach+girth(e): continue
		e.slow=maxf(float(e.slow),rank("oil"))
		if e.get("boss",false): continue
		var away=(e.p-player).normalized()
		if away.length()>0.5: e.p=move_actor(e.p,away*mini(18,6*rank("oil"))); e.goal=center(tile_at(e.p))
	effects.append({"p":player,"life":0.4,"radius":0,"color":BLUE,"text":"SKID"})
func finish_round() -> void:
	# The final exit opens the boss arena; the run is only won after the boss falls.
	if level>=9 and not boss_mode:
		start_boss()
		return
	score+=int(400+(level+1)*100)
	round_cleared.emit(level+1)
	audio.play("clear")
	if level>=9:
		end_run()
		return
	choices=Perks.candidates(draft_ranks); selected=0; state="choice"
func end_run() -> void:
	if state=="over": return
	_terminal = "win" if int(hp) > 0 else "dead"
	state="over"; initials=""; game_over.emit()
func start_boss() -> void:
	boss_mode=true
	board=Boss.ARENA.duplicate()
	snacks.clear(); enemies.clear(); shots.clear(); zones.clear(); effects.clear()
	chests.clear(); gates.clear(); pending_spawns.clear()
	exit_tile=Vector2i(-9,-9)
	elapsed=0; combo=0; combo_time=0
	invincible=2.5; star_time=0; flop_time=0; flop_cd=0; sugar_time=0; pizza_time=0; glide_time=0
	attack_cd=0.2; gas_cd=2; pulse_cd=3; nav_cd=0
	shields=maxi(shields,rank("shield")+rank("restock"))
	refresh_companions()
	player=Boss.PLAYER_START
	boss=Boss.new()
	enemies.append(boss.spawn())
	state="intro"; intro_time=2.2
	notice=""; notice_time=0
	audio.play("start")
func boss_enemy() -> Dictionary:
	return boss.enemy if boss!=null else {}
func drop_boss_snack() -> void:
	var spots: Array=[]
	for y in 13:
		for x in 19:
			var t=Vector2i(x,y)
			if cell(t)=="." and not snacks.has(t) and center(t).distance_to(boss_enemy().get("p",Vector2.ZERO))>56: spots.append(t)
	if not spots.is_empty(): snacks[spots[randi()%spots.size()]]="p"
func boss_down() -> void:
	if boss_won: return
	boss_won=true
	state="victory"; victory_time=2.6
	shots=shots.filter(func(s):return not s.hostile)
	pending_spawns.clear()
	var at=boss_enemy().get("p",player)
	for e in enemies:
		if e.get("boss",false) or int(e.hp)<=0: continue
		e.hp=0
		effects.append({"p":e.p,"life":0.6,"radius":15,"color":GREEN,"text":"POP!"})
	for i in 4: effects.append({"p":at,"life":0.6+i*0.25,"radius":20+i*14,"color":[GOLD,PINK,CREAM,GREEN][i],"text":""})
	effects.append({"p":at,"life":2.4,"radius":0,"color":GOLD,"text":"TOAST!"})
	score+=5000+hp*500
	shake=5 if shake_enabled else 0
	audio.play("clear")
	announce(Boss.NAME+" IS TOAST!")
	boss_defeated.emit()
func _process(dt: float) -> void:
	_poll_input()
	if _arcade_emitted:
		return
	dt=minf(dt,0.05)
	clock+=dt
	if state=="intro":
		intro_time-=dt
		if intro_time<=0: state="play"
	if state=="play": update_game(dt)
	elif state=="victory":
		victory_time-=dt
		if victory_time<=0: finish_round()
	if state!="pause":
		for e in effects: e.life-=dt
		effects=effects.filter(func(e):return e.life>0)
		notice_time=maxf(0,notice_time-dt)
		reveal_time=maxf(0,reveal_time-dt)
		heal_flash=maxf(0,heal_flash-dt)
		shake=maxf(0,shake-dt*16)
	queue_redraw()
func update_game(dt: float) -> void:
	elapsed+=dt
	run_time+=dt
	update_director(dt)
	invincible=maxf(0,invincible-dt); star_time=maxf(0,star_time-dt)
	flop_time=maxf(0,flop_time-dt); flop_cd=maxf(0,flop_cd-dt)
	sugar_time=maxf(0,sugar_time-dt); pizza_time=maxf(0,pizza_time-dt)
	combo_time=maxf(0,combo_time-dt)
	if combo_time<=0: combo=0
	var input=_move_input()
	var pad_aim=_pad_cardinal()
	if pad_aim!=Vector2.ZERO: shot_dir=pad_aim
	moving=input.length()>0
	if moving: facing=input.normalized()
	var speed=move_speed()
	if cell(tile_at(player))=="o": speed*=oil_scale()
	var previous=player
	player=move_actor(player,(facing*flop_speed() if flop_time>0 else input.normalized()*speed)*dt)
	if flop_time<=0 and star_time<=0:
		for e in enemies:
			if e.hp>0 and e.kind==5 and hero_touch(e):
				player=previous; hurt(); break
	# Rink momentum counts only the player's own steps: walls and guards stall it, conveyors push after.
	glide_time=glide_time+dt if moving and player.distance_to(previous)>0.01 else 0.0
	if cell(tile_at(player)) in ["~", ")", "(", "="] and trap_phase(tile_at(player))>2:
		player=move_actor(player,hazard_dir(cell(tile_at(player)))*22*fan_scale()*dt)
	try_collect()
	
	attack_cd-=dt; gas_cd-=dt; pulse_cd-=dt
	if rank("pepper")>0 and attack_cd<=0:
		var aim=cannon_aim()
		if olive_ready and _manual_shot_held():
			fire(player,aim,2+mini(4,rank("bonus")),false,true)
			olive_ready=false
			olive_time=0
		else:
			for i in range(1+rank("spread")):
				fire(player,aim.rotated((i-rank("spread")*0.5)*0.18),1+rank("pepper")+streak_bonus(),false)
		attack_cd=cannon_delay()
	if rank("gas")>0 and gas_cd<=0:
		add_zone(player-facing*8,23+rank("gas")*4+rank("giant")*8,rank("gas")+rank("spicy"),2+rank("stink"),GREEN)
		gas_cd=4
	if rank("pulse")>0 and pulse_cd<=0:
		blast(player,30+rank("pulse")*10,rank("pulse"),BLUE); pulse_cd=5
	update_enemies(dt)
	if boss!=null: boss.update(self,dt)
	update_toys(dt)
	update_shots(dt)
	update_zones(dt)
	update_traps(dt)
	bonk_orbiters()
	if state!="play": return
	for enemy in enemies:
		if enemy.get("boss",false): continue
		if enemy.hp>0 and hero_touch(enemy):
			if star_time>0 or flop_time>0: damage_enemy(enemy,5 if star_time>0 else 1+rank("dash")+rank("spicy"))
			else: hurt()
		if state!="play": break
	enemies=enemies.filter(func(e):return e.hp>0)
func collect(t: Vector2i) -> void:
	var c=snacks[t]; snacks.erase(t)
	audio.play("bite")
	if c=="K":
		keys+=1; key_found=true; star_time=maxf(star_time,rank("key")*2); announce("KEY +1  / E AT LOCK"); return
	if c=="$": star_time=4+rank("star")*2; score+=200; announce("STAR SODA: TOUCH = TROUBLE!"); return
	eaten+=1; hp=mini(max_hp,hp+1); heal_flash=0.45; combo=mini(5,combo+1); combo_time=3
	var points=(100 if c=="d" else 150)+rank("combo")*25*combo
	score+=points
	effects.append({"p":center(t),"life":0.6,"radius":12,"color":GREEN,"text":"+1 HP"})
	if c=="d":
		sugar_time=rank("sugar")*3
		if rank("sprinkles")>0: radial(player,4+rank("sprinkles")*4,1)
	else:
		pizza_time=rank("pizza")*2
		if rank("cheese")>0: add_zone(player,24,rank("cheese"),2+rank("stink"),GOLD)
	if rank("nova")>0 and eaten%5==0: blast(player,40+rank("nova")*12,rank("nova")+1,PINK)
	if rank("trail")>0: add_zone(player,14,1+rank("trail"),5,GOLD,true)
	if rank("munch")>0: chomp()
	if rank("snare")>0:
		for e in enemies:
			if e.p.distance_to(player)<60: e.slow=maxf(e.slow,rank("snare"))
func fire(p: Vector2,dir: Vector2,damage: int,hostile: bool,olive: bool=false) -> void:
	if shots.size()>=150: return
	shots.append({"p":p,"v":dir* (70 if olive else 90 if hostile else 175),"life":3.0 if hostile else 0.9+rank("range")*0.5,"damage":damage,"hostile":hostile,"bounce":0 if hostile or olive else rank("ricochet"),"pierce":0 if hostile or olive else rank("pierce"),"hit":[],"olive":olive})
func radial(p: Vector2,count: int,damage: int) -> void:
	for i in count: fire(p,Vector2.from_angle(i*TAU/count),damage,false)
func smart_sauce() -> bool:
	# Only chest ranks of Smart Sauce unlock auto-aim; stage-perk bonuses do not.
	return int(ranks.get("splash",0))>0
func cannon_aim() -> Vector2:
	if smart_sauce() and not _manual_shot_held():
		var target=nearest_enemy(player,170)
		if target!=null: return (target.p-player).normalized()
	return shot_dir
func nearest_enemy(p: Vector2,reach: float):
	var target=null
	for e in enemies:
		var d=p.distance_to(e.p)
		if e.hp>0 and d<reach and clear_line(p,e.p): target=e; reach=d
	return target
func try_collect() -> void:
	for t in snacks.keys():
		var dist=player.distance_to(center(t))
		if dist<10+rank("magnet")*8 and clear_line(player,center(t)):
			collect(t)
			if rank("magnet")>0 and dist>12: slurp_crumb()
func slurp_crumb() -> void:
	var target=nearest_enemy(player,140)
	if target!=null: fire(player,(target.p-player).normalized(),rank("magnet"),false)
func chomp() -> void:
	for e in enemies:
		if int(e.hp)>0 and e.p.distance_to(player)<30+girth(e) and clear_line(player,e.p): e.stun=maxf(float(e.stun),0.4)
	blast(player,30,1+rank("munch"),CREAM)
	effects.append({"p":player,"life":0.4,"radius":0,"color":CREAM,"text":"CHOMP"})
func streak_bonus() -> int:
	return rank("combo") if combo>=3 and combo_time>0 else 0
func blast(p: Vector2,radius: float,damage: int,color: Color,chain: bool=true,skip=null) -> void:
	if damage<=0: return
	effects.append({"p":p,"life":0.3,"radius":radius,"color":color,"text":""})
	for e in enemies.duplicate():
		if e==skip: continue
		if e.hp>0 and e.p.distance_to(p)<radius+girth(e) and clear_line(p,e.p): damage_enemy(e,damage,false,chain)
func kill_pay(e: Dictionary) -> float:
	# Authored monsters always pay in full; reinforcements pay less as the stage threat climbs.
	return threat_pay() if e.get("reinforcement",false) else 1.0
func kill_coins(pay: float=1.0) -> int:
	return maxi(1,roundi((8+level)*(1+int(draft_ranks.get("cashback",0))*0.5)*pay))
func kills_for(price: int) -> int:
	return ceili(float(price)/kill_coins())
func vault_bonus() -> int:
	return chest_cost(0)*2
func damage_enemy(e: Dictionary,amount: int,trap: bool=false,chain: bool=true) -> void:
	if e.hp<=0: return
	if e.get("boss",false):
		e.slow=maxf(float(e.slow),rank("frost"))
		if boss!=null: boss.take_hit(self,e,amount,trap)
		return
	e.hp-=amount; e.slow=maxf(e.slow,rank("frost")); e.tick=0.15
	if rank("knock")>0: e.p=move_actor(e.p,(e.p-player).normalized()*rank("knock")*5*(0.25 if e.kind==5 else 1.0)); e.goal=center(tile_at(e.p))
	if e.hp>0: return
	var pay=kill_pay(e)
	kills+=1; coins+=kill_coins(pay)
	var due=0
	while due<loans.size():
		loans[due]=int(loans[due])-1
		if int(loans[due])<=0:
			loans.remove_at(due)
			keys+=1
			announce("LOAN REPAID: KEY +1")
		else: due+=1
	var fame=THREAT_SCORE[threat_tier()-1] if e.get("reinforcement",false) else 1.0
	score+=roundi(250*fame)+(100+rank("gourmet")*100 if trap else 0)
	audio.play("pop")
	effects.append({"p":e.p,"life":0.4,"radius":15,"color":GREEN,"text":"POP!" if pay>=1.0 else str(roundi(pay*100))+"%"})
	if rank("leech")>0:
		leech_meter+=pay
		var need=maxi(2,5-rank("leech"))
		if leech_meter>=need: leech_meter-=need; shields=mini(5,shields+1)
	if trap and rank("gourmet")>0: blast(e.p,30,1+rank("gourmet"),PINK,false,e)
	if chain and rank("bomb")>0: blast(e.p,25+rank("bomb")*8,rank("bomb"),GOLD,false)
	if chain and rank("chain")>0:
		var target=nearest_enemy(e.p,80)
		if target!=null:
			effects.append({"p":target.p,"life":0.3,"radius":18,"color":BLUE,"text":"ZAP"})
			damage_enemy(target,rank("chain"),false,false)
func hurt() -> void:
	if state!="play" or invincible>0 or star_time>0: return
	audio.play("hit"); clean=false; shake=3 if shake_enabled else 0
	if rank("eject")>0:
		shots=shots.filter(func(s):return not s.hostile)
		for e in enemies: e.stun=rank("eject")
	if shields>0:
		shields-=1
		invincible=1.25
		blast(player,50,rank("shieldpop")*2,BLUE)
		if boss!=null: boss.stagger(self)
	else:
		hp-=1
		blast(player,35+rank("retaliate")*6,rank("retaliate")*2,PINK)
		if hp<=0 and rank("revive")>0 and not rescued:
			rescued=true; hp=mini(max_hp,rank("revive")); announce("SECOND HELPING!")
		if hp<=0: end_run(); return
		invincible=1.5
		plant_fork()
		announce("OUCH! FOOD HEALS 1")
	separate_from_threats()

func build_nav(target: Vector2i) -> Dictionary:
	var distances={target:0}
	var todo=[target]
	var head=0
	while head<todo.size():
		var t=todo[head]; head+=1
		for d in DIRS:
			var n=t+d
			if not solid(n) and not distances.has(n): distances[n]=distances[t]+1; todo.append(n)
	return distances
func update_enemies(dt: float) -> void:
	nav_cd-=dt
	if nav_cd<=0: nav=build_nav(tile_at(player)); nav_cd=0.22
	for e in enemies:
		if e.hp<=0 or e.get("boss",false): continue
		e.slow=maxf(0,e.slow-dt); e.stun=maxf(0,e.stun-dt); e.tick=maxf(0,e.tick-dt); e.cool-=dt
		if e.stun>0: continue
		var speed=28.0+level*1.1+minf(6.0,run_time/40.0)+(threat_tier()-1)*2.5
		if e.kind==4:
			speed=65 if fmod(elapsed,1.1)<0.45 else 0
		if e.kind==5: speed=15+level
		if cell(tile_at(e.p))=="o": speed*=0.5
		if e.slow>0: speed*=0.5
		if e.p.distance_to(player)<60: speed*=slow_scale()
		if e.kind==2:
			if e.cool<=0 and clear_line(e.p,player):
				fire(e.p,(hero_center()-e.p).normalized(),1,true); e.cool=2.4
			if e.p.distance_to(player)<100: continue
		if e.kind==1:
			if e.cool<=0:
				e.attack=1.15; e.dir=(player-e.p).normalized(); e.cool=3.5
				if absf(e.dir.x)>absf(e.dir.y): e.dir=Vector2(signf(e.dir.x),0)
				else: e.dir=Vector2(0,signf(e.dir.y))
			if e.attack>0:
				e.attack-=dt
				if e.attack<0.45:
					e.p=move_actor(e.p,e.dir*85*dt); e.goal=center(tile_at(e.p))
				continue
		var t=tile_at(e.p)
		var field=nav
		if e.kind==3: field=build_nav(tile_at(player if player.distance_to(e.home)<48 else e.home))
		if e.kind==6:
			var ahead=tile_at(player+facing*32)
			if not solid(ahead): field=build_nav(ahead)
		if not e.has("goal"): e.goal=center(t)
		if e.p.distance_to(e.goal)<0.1:
			var best=int(field.get(t,999))
			e.goal=center(t)
			for d in DIRS:
				if int(field.get(t+d,999))<best:
					best=int(field[t+d]); e.goal=center(t+d)
		var toward=e.goal-e.p
		if toward.length()>0.01:
			e.dir=toward.normalized()
			e.p=move_actor(e.p,e.dir*minf(toward.length(),speed*dt))

func update_shots(dt: float) -> void:
	for s in shots:
		s.life-=dt
		var from: Vector2=s.p
		var r=shot_radius(s)
		var next=s.p+s.v*dt
		if solid(tile_at(next)):
			if s.bounce>0:
				s.bounce-=1
				if solid(tile_at(s.p+Vector2(s.v.x*dt,0))): s.v.x=-s.v.x
				if solid(tile_at(s.p+Vector2(0,s.v.y*dt))): s.v.y=-s.v.y
			else: s.life=0
		else: s.p=next
		if s.life<=0: continue
		if not s.hostile and not s.get("ignited",false) and rank("gas")>0 and rank("sprinkles")>0:
			for z in zones:
				if z.color==GREEN and s.p.distance_to(z.p)<z.radius:
					s.damage+=2; s.pierce+=1; s["ignited"]=true; break
		if s.hostile:
			if swat_saucer(s): continue
			if arrest_bullet(s): s.life=0; continue
			if hero_swept(from,s.p,r): s.life=0; hurt()
			if s.get("trap",false):
				for e in enemies.duplicate():
					if e.hp>0 and body_sweep(e,from,s.p,r):
						damage_enemy(e,2+rank("trap")*2,true); s.life=0; break
		else:
			for e in enemies.duplicate():
				if e.hp<=0 or s.hit.has(e): continue
				if body_sweep(e,from,s.p,r):
					s.hit.append(e); damage_enemy(e,s.damage)
					if s.get("olive",false):
						for other in enemies.duplicate():
							if other==e or int(other.hp)<=0: continue
							if other.p.distance_to(s.p)<28+girth(other):
								var pull=s.p-other.p
								if pull.length()>1 and not other.get("boss",false): other.p=move_actor(other.p,pull.normalized()*8)
								damage_enemy(other,mini(4,rank("bonus")))
						s.life=0
						break
					if rank("splash")>0: blast(s.p,22,rank("splash"),GOLD,false,e)
					s.pierce-=1
					if s.pierce<0: s.life=0; break
	shots=shots.filter(func(s):return s.life>0)
func add_zone(p: Vector2,radius: float,damage: int,life: float,color: Color,mine: bool=false) -> void:
	if zones.size()<40: zones.append({"p":p,"radius":radius,"damage":damage,"life":life,"tick":0.0,"color":color,"mine":mine})
func update_zones(dt: float) -> void:
	for z in zones:
		z.life-=dt; z.tick-=dt
		if z.tick>0: continue
		z.tick=0.5
		for e in enemies.duplicate():
			if e.hp>0 and e.p.distance_to(z.p)<z.radius+girth(e) and clear_line(z.p,e.p):
				damage_enemy(e,z.damage)
				if z.color==GOLD and rank("frost")>0: e.stun=maxf(e.stun,0.35)
				if z.mine: z.life=0; blast(z.p,30,z.damage,GOLD); break
	zones=zones.filter(func(z):return z.life>0)
func trap_phase(t: Vector2i) -> float:
	return fmod(elapsed+(t.x+t.y)*0.11,4.0)
func update_traps(dt: float) -> void:
	for y in 13:
		for x in 19:
			var t=Vector2i(x,y); var c=cell(t); var phase=trap_phase(t)
			if c=="^" and rank("sense")>0 and phase>trap_warn() and phase<3.2:
				for e in enemies:
					if int(e.hp)>0 and not e.get("boss",false) and e.p.distance_to(center(t))<10: e.stun=maxf(float(e.stun),3.2-phase)
			if c=="^" and phase>=3.2:
				if player.distance_to(center(t))<12: hurt()
				for e in enemies.duplicate():
					var is_boss=bool(e.get("boss",false))
					var cooldown=float(boss.spike_cd) if is_boss and boss!=null else float(e.tick)
					if e.hp>0 and e.p.distance_to(center(t))<12+girth(e) and cooldown<=0:
						if is_boss and boss!=null: boss.spike_cd=0.5
						damage_enemy(e,2+rank("trap")*2,true); e.tick=0.5
			if c in [">","<","A","V"] and phase>=3.2 and phase-dt<3.2:
				fire(center(t),hazard_dir(c),1,true)
				shots.back()["trap"]=true

func hazard_dir(c: String) -> Vector2:
	if c in ["<","("]: return Vector2.LEFT
	if c in ["A","="]: return Vector2.UP
	if c=="V": return Vector2.DOWN
	return Vector2.RIGHT
func separate_from_threats() -> void:
	var away=Vector2.ZERO
	var best=18.0
	for e in enemies:
		if int(e.hp)<=0: continue
		var delta=player-e.p
		var dist=delta.length()
		if dist<best and dist>0.01:
			best=dist
			away=delta/dist
	if away!=Vector2.ZERO: player=move_actor(player,away*12)
func chest_cost(tier: int) -> int:
	# Kill pay grows by 1 coin per stage while chests grow 35% per stage, so late loot costs more kills.
	return int([8,22,48][tier]*(1.0+level*0.35))
func use_target() -> Dictionary:
	var best=9999.0
	var kind=""
	var tile=Vector2i.ZERO
	for t in chests:
		if chests[t].open: continue
		var dist=player.distance_to(center(t))
		if dist<12 and dist<best:
			best=dist; kind="chest"; tile=t
	for t in gates:
		if gates[t].open: continue
		var dist=player.distance_to(center(t))
		if dist<18 and dist<best:
			best=dist; kind="gate"; tile=t
	var exit_dist=player.distance_to(center(exit_tile))
	if exit_dist<16:
		var at_exit=remaining()==0 and exit_dist<12 and best>6
		if kind=="" or exit_dist<best or at_exit:
			kind="exit"; tile=exit_tile; best=exit_dist
	return {"kind":kind,"tile":tile,"dist":best}
func interact() -> void:
	var use=use_target()
	var kind=str(use.kind)
	var tile: Vector2i=use.tile
	if kind=="chest":
		var tier=chests[tile].tier
		var price=chest_cost(tier)
		if coins<price: announce("NEED "+str(price)+" COINS"); return
		if item_count>=50: announce("BAG FULL: 50 ITEMS"); return
		var item=Items.roll(tier,ranks)
		if item.is_empty(): return
		coins-=price; chests[tile].open=true; item_count+=1
		ranks[item[0]]=int(ranks.get(item[0],0))+1
		item_history.append(item[0])
		if item[0]=="shield": shields+=1
		if item[0]=="armor": croutons+=1
		if item[0]=="wind": fork_ready+=1
		if item[0]=="crumbscore": saucer_swats=mini(3,rank("crumbscore")); saucer_crack=0
		if item[0]=="bonus": olive_ready=true
		if randf()<[0.12,0.25,0.4][tier]: keys+=1
		announce(str(item[1]).left(22)+"  I"); audio.play("perk"); return
	if kind=="gate":
		var gate=gates[tile]
		if gate.mode==2 and hp>1: hp-=1
		elif keys>0:
			keys-=1
			if gate.mode==1: loans.append(3)
		else:
			announce("NEED KEY" if gate.mode!=2 else "NEED KEY OR 2+ HP")
			return
		gate.open=true; nav_cd=0
		blast(center(tile),48,rank("gate")*3,GOLD)
		if gate.mode==3:
			coins+=30
			for i in 3: queue_spawn()
		else:
			var vault=vault_bonus()
			coins+=vault
			effects.append({"p":center(tile),"life":1.2,"radius":0,"color":GOLD,"text":"+$"+str(vault)})
		announce(["KEY SPENT","LOAN: 3 KILLS REFUND THIS KEY","BLOOD LOCK: FOOD HEALS","ALARM +30, ENEMIES COMING"][gate.mode])
		return
	if kind=="exit":
		if remaining()>0: announce("EAT "+str(remaining())+" MORE TO EXIT")
		else:
			last_quick=quick_exit_bonus()
			score+=last_quick
			finish_round()
func quick_exit_bonus() -> int:
	return roundi(QUICK_EXIT[threat_tier()-1]*(1.0+level*0.2))
func queue_spawn(kind: int=-1) -> void:
	if enemies.size()+pending_spawns.size()>=28: return
	var field=build_nav(tile_at(player))
	var pool=[]
	for t in field:
		if center(t).distance_to(player)>64 and not chests.has(t) and t!=exit_tile: pool.append(t)
	if pool.is_empty(): return
	pool.shuffle()
	pending_spawns.append({"p":center(pool[0]),"time":1.3,"kind":kind if kind>=0 else randi_range(0,mini(6,1+level))})
func update_director(dt: float) -> void:
	var tier=threat_tier()
	if tier>threat_seen and not boss_mode:
		threat_seen=tier
		announce("THREAT "+str(tier)+": SPAWNS PAY "+str(roundi(threat_pay()*100))+"%")
	spawn_cd-=dt
	if spawn_cd<=0 and not boss_mode:
		for i in mini(4,1+int(level/4.0)+int((tier-1)/2.0)): queue_spawn()
		spawn_cd=maxf(2.0,(11.0-level*0.55-minf(2.0,run_time/150.0))*THREAT_SPAWN[tier-1])
	for portal in pending_spawns:
		portal.time-=dt
		if portal.time<=0:
			if portal.p.distance_to(player)<28: portal.time=0.6; continue
			enemies.append({"p":portal.p,"home":portal.p,"kind":portal.kind,"hp":enemy_hp(portal.kind),"slow":0.0,"stun":0.0,"cool":2.0,"attack":0.0,"dir":Vector2.LEFT,"tick":0.0,"reinforcement":true})
	pending_spawns=pending_spawns.filter(func(p):return p.time>0)
func exit_compass() -> String:
	var delta=center(exit_tile)-player
	if delta.length()<48: return ""
	var horizontal="E" if delta.x>12 else "W" if delta.x<-12 else ""
	var vertical="S" if delta.y>12 else "N" if delta.y<-12 else ""
	return vertical+horizontal
func prompt_line() -> String:
	if boss_mode and boss!=null and (notice_time<=0 or boss.action.ends_with("_warn")): return boss.callout()
	if notice_time>0: return notice.left(30)
	var use=use_target()
	if use.kind=="chest":
		var tier=int(chests[use.tile].tier)
		var price=chest_cost(tier)
		return "E: "+["TIN","SILVER","NEON"][tier]+" $"+str(price)+" ~"+str(kills_for(price))+" BASE KILLS"
	if use.kind=="gate":
		var mode=int(gates[use.tile].mode)
		if mode==3: return "E: KEY, +30, SPAWNS"
		return ["E: 1 KEY, VAULT +$","E: LOAN KEY, VAULT +$","E: HP/KEY, VAULT +$"][mode]+str(vault_bonus())
	if use.kind=="exit":
		return "E: LEAVE WITH THE LOOT" if remaining()==0 else "EXIT NEEDS "+str(remaining())+" FOOD"
	var ahead=""
	var ahead_dist=46.0
	for t in gates:
		if gates[t].open: continue
		var dist=player.distance_to(center(t))
		if dist<ahead_dist:
			ahead_dist=dist
			ahead=["KEY LOCK AHEAD","LOAN LOCK AHEAD","BLOOD LOCK AHEAD","ALARM LOCK AHEAD"][int(gates[t].mode)]
	if ahead!="": return ahead
	var hint=exit_compass()
	if hint!="": return "EXIT "+hint
	if loans.size()>0:
		var soon=99
		for owed in loans: soon=mini(soon,int(owed))
		return "LOAN REFUND IN "+str(soon)+" KILLS"
	return "SPACE FLOP   E USE   I BAG"
func draw_exit_marker() -> void:
	if boss_mode: return
	var spot=center(exit_tile)+ORIGIN-camera
	var play=Rect2(2,38,252,168)
	if play.has_point(spot) and spot.y<204: return
	var edge=Vector2(clampf(spot.x,10,246),clampf(spot.y,46,198))
	var mark=GREEN if remaining()==0 else GOLD
	draw_rect(Rect2(edge-Vector2(6,6),Vector2(12,12)),INK)
	draw_rect(Rect2(edge-Vector2(5,5),Vector2(10,10)),mark,false)
	label("E",edge+Vector2(-3,3),mark)
func label(text: String,p: Vector2,color: Color=CREAM,size: int=8) -> void:
	draw_string(FONT,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func centered(text: String,y: float,color: Color=CREAM,size: int=8) -> void:
	label(text,Vector2((256-FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)/2,y),color,size)
func wrapped(text: String,p: Vector2,color: Color=CREAM,width: int=28) -> void:
	var line=""; var y=p.y
	for word in text.split(" "):
		if (line+word).length()>width:
			label(line,p*Vector2(1,0)+Vector2(0,y),color); y+=12; line=""
		line+=word+" "
	if line!="": label(line,Vector2(p.x,y),color)
func box(rect: Rect2,color: Color=BLUE) -> void:
	draw_rect(rect,Color("181c30")); draw_rect(rect,color,false)
func draw_pickle_mark(p: Vector2) -> void:
	draw_rect(Rect2(p+Vector2(-2,-6),Vector2(4,10)),Color("3d7a32"))
	draw_rect(Rect2(p+Vector2(-1,-7),Vector2(2,4)),GREEN)
func draw_saucer_mark(p: Vector2) -> void:
	draw_rect(Rect2(p+Vector2(-7,-2),Vector2(14,4)),CREAM)
	draw_rect(Rect2(p+Vector2(-5,-3),Vector2(10,2)),GOLD)
func draw_olive_mark(p: Vector2) -> void:
	draw_rect(Rect2(p+Vector2(-3,-2),Vector2(6,4)),Color("6f8f2a"))
	draw_rect(Rect2(p+Vector2(-1,-1),Vector2(2,2)),Color("be2f25"))
func draw_fork_mark(p: Vector2) -> void:
	draw_rect(Rect2(p+Vector2(-1,-5),Vector2(2,8)),CREAM)
	draw_rect(Rect2(p+Vector2(-3,-6),Vector2(2,3)),GOLD)
	draw_rect(Rect2(p+Vector2(1,-6),Vector2(2,3)),GOLD)
func draw_crouton_mark(p: Vector2) -> void:
	draw_rect(Rect2(p+Vector2(-3,-3),Vector2(6,6)),INK)
	draw_rect(Rect2(p+Vector2(-2,-2),Vector2(4,4)),Color("cb7142"))
func draw_bowl_mark(p: Vector2,armed: bool) -> void:
	draw_rect(Rect2(p+Vector2(-5,4),Vector2(10,3)),INK)
	draw_rect(Rect2(p+Vector2(-4,5),Vector2(8,1)),GOLD if armed else Color("667080"))
func donut(p: Vector2,alpha: float=1.0) -> void:
	for y in range(-5,6):
		for x in range(-5,6):
			var d=x*x+y*y
			if d>=6 and d<=29: draw_rect(Rect2(p+Vector2(x,y),Vector2.ONE),Color(INK if d>23 or d<9 else PINK,alpha))
	draw_rect(Rect2(p+Vector2(-3,-2),Vector2(2,1)),Color(CREAM,alpha))
func blob(p: Vector2,kind: int,flash: bool=false) -> void:
	var color=CREAM if flash else [GREEN,PINK,BLUE,Color("b59cd7"),GOLD,Color("e97949"),Color("76d4b4")][kind]
	p=p.round()
	draw_rect(Rect2(p+Vector2(-7,-4),Vector2(14,10)),INK)
	draw_rect(Rect2(p+Vector2(-5,-7),Vector2(10,14)),INK)
	draw_rect(Rect2(p+Vector2(-5,-4),Vector2(10,9)),color)
	draw_rect(Rect2(p+Vector2(-4,-5),Vector2(8,11)),color)
	draw_rect(Rect2(p+Vector2(-4,-2),Vector2(2,2)),INK)
	draw_rect(Rect2(p+Vector2(2,-2),Vector2(2,2)),INK)
	draw_rect(Rect2(p+Vector2(-2,3),Vector2(4,1)),INK)
	if kind==1:
		draw_rect(Rect2(p+Vector2(-5,-8),Vector2(2,3)),CREAM); draw_rect(Rect2(p+Vector2(3,-8),Vector2(2,3)),CREAM)
	elif kind==2: draw_rect(Rect2(p+Vector2(-2,1),Vector2(4,3)),INK)
	elif kind==3: draw_rect(Rect2(p+Vector2(-6,-6),Vector2(12,2)),GOLD)
	elif kind==4: draw_line(p+Vector2(-9,4),p+Vector2(-6,2),PINK,2)
	elif kind==5: draw_rect(Rect2(p+Vector2(-6,-7),Vector2(12,3)),Color("7c8b9b"))
	elif kind==6: draw_rect(Rect2(p+Vector2(-1,-10),Vector2(2,4)),GOLD)
func _draw() -> void:
	draw_rect(Rect2(0,0,256,224),Color("181c30"))
	if state=="title":
		for x in range(0,256,16): draw_rect(Rect2(x,14,8,2),PINK)
		centered("SNACK KID",47,CREAM,24)
		centered("SUPERSTAR",73,GOLD,24)
		draw_texture(HERO,Vector2(119,93))
		blob(Vector2(89,107),0); donut(Vector2(160,104))
		centered("EAT. LOOT. DON'T LINGER.",136,PINK)
		centered("ENTER / SPACE: START",160,GOLD)
		centered("MOVE + AIM: WASD / ARROWS",180)
		centered("SPACE FLOP   E INTERACT",194,BLUE)
		centered("P PAUSE  I BAG  H SCORES",210,BLUE)
		return
	if state=="scores":
		centered("BUFFET HALL OF FAME",26,GOLD)
		for i in mini(10,scores.size()):
			var entry=scores[i]
			label("%02d %-3s %07d R%02d"%[i+1,str(entry.name).left(3),int(entry.score),int(entry.get("round",1))],Vector2(32,48+i*14))
		centered("ENTER: BACK",212,BLUE); return
	if state=="choice":
		if choices.is_empty():
			centered("NO SUPER PERKS LEFT",80,PINK); return
		selected=clampi(selected,0,choices.size()-1)
		var header="STAGE "+str(level+1)+" CLEARED"+("  QUICK +"+str(last_quick) if last_quick>0 else "")
		centered("BEFORE STAGE 1" if starter_draft else header,18,GOLD)
		centered("PICK A SUPER PERK",34,PINK)
		for i in choices.size():
			var card=choices[i]
			var short_name=str(card[1]).split(" ")[0].left(9)
			box(Rect2(4+i*84,46,80,36),GOLD if i==selected else BLUE)
			label(str(i+1)+" "+short_name,Vector2(10+i*84,62),GOLD if i==selected else CREAM)
			label("TAKE" if i==selected else "LOOK",Vector2(10+i*84,76),GOLD if i==selected else BLUE)
		var item=choices[selected]
		wrapped(item[1],Vector2(12,100),GOLD,28)
		wrapped(item[2],Vector2(12,128),CREAM,28)
		wrapped(item[3],Vector2(12,164),BLUE,28)
		centered("1 2 3 THEN ENTER",210,PINK); return
	if state=="over":
		centered("SUPERSTAR!" if hp>0 else "SNACKED OUT",42,GOLD,16)
		centered("SCORE "+str(score),72,PINK)
		centered("STAGE "+str(level+1)+"   ITEMS "+str(item_count),94)
		if boss_won and hp>0: centered(Boss.NAME+" TOASTED",116,GREEN)
		elif last_perk!="": centered(last_perk.left(26),116,BLUE)
		centered("YOUR INITIALS",142,GOLD)
		centered(initials+"_".repeat(3-initials.length()),168,CREAM,16)
		centered("ENTER SAVES YOUR SCORE",204,GOLD); return
	if state in ["pause","inventory"]:
		centered("LUNCH BREAK" if state=="pause" else "YOUR LOOT BAG",20,GOLD)
		if state=="pause":
			wrapped("HP "+str(hp)+"/"+str(max_hp)+"   $"+str(coins)+"   KEY "+str(keys),Vector2(16,46))
			wrapped("SCORE "+str(score)+"   BAG "+str(item_count)+"/50   KILLS "+str(kills),Vector2(16,68),GOLD)
			wrapped("Ten foods power the exit. Each food heals 1 HP. Locks show their price before you spend.",Vector2(16,92),BLUE)
			if boss_mode: label("SPIKES HURT IT; POPS OPEN IT",Vector2(16,128),PINK)
			else: label("THREAT "+str(threat_tier())+"  LATE KILLS PAY "+str(roundi(threat_pay()*100))+"%",Vector2(16,128),PINK)
			centered("ENTER / A RESUME" if arcade_mode else "ENTER RESUME  R RESTART",140)
			centered("I / Y BAG" if arcade_mode else "Q TITLE  I BAG",158)
			centered("M SOUND  N MUSIC  F SHAKE",184,BLUE)
		else:
			var bag=item_history.duplicate()
			for id in draft_ranks: bag.append("perk:"+id)
			inventory_page=clampi(inventory_page,0,maxi(0,bag.size()-1))
			if bag.size()>0:
				var id=bag[inventory_page]
				var is_perk=id.begins_with("perk:")
				var item=Perks.definition(id.substr(5)) if is_perk else Items.definition(id)
				wrapped(item[1],Vector2(16,46),GOLD)
				wrapped(item[2],Vector2(16,78))
				wrapped(item[3],Vector2(16,118),BLUE)
				if is_perk: wrapped("DRAFT RANK "+str(int(draft_ranks.get(id.substr(5),0))),Vector2(16,156),PINK)
				else: wrapped("CHEST "+str(int(ranks.get(id,0)))+"  STAGE +"+str(int(perk_bonuses.get(id,0))),Vector2(16,156),PINK)
				centered(("SUPER PERK" if is_perk else Items.RARITY_NAMES[Items.rarity_for(id)]),176,PINK)
			centered(str(inventory_page+1)+" / "+str(bag.size())+"  LEFT / RIGHT",189)
		centered("P / ESC CLOSE",213,GOLD); return
	draw_world()
	if state=="intro" and boss_mode:
		box(Rect2(12,82,232,61),PINK)
		centered("FINAL COURSE",100,GOLD)
		centered(Boss.NAME,118,PINK)
		centered("DODGE, THEN HIT WHEN OPEN",134,BLUE)
	elif state=="intro":
		box(Rect2(12,82,232,61),GOLD)
		centered("STAGE "+str(level+1)+" / 10",100,GOLD)
		centered(str(rounds[level].name).to_upper().left(28),118)
		centered("10 FOODS = EXIT + HEALING",134,BLUE)
	elif state=="victory":
		box(Rect2(12,82,232,45),GOLD)
		centered("SUPERSTAR!",102,GOLD,16)
		centered(Boss.NAME+" IS TOAST",120,PINK)
func draw_world() -> void:
	camera=(player-Vector2(128,86)).clamp(Vector2.ZERO,Vector2(48,36)).round()
	var offset=ORIGIN-camera
	draw_set_transform(offset)
	var wall=Color("80554e") if boss_mode else [Color("4c636a"),Color("684f65"),Color("536d49"),Color("80554e"),Color("426f73")][level%5]
	for y in 13:
		for x in 19:
			var t=Vector2i(x,y); var p=Vector2(t)*16; var c=cell(t)
			draw_rect(Rect2(p,Vector2(16,16)),Color("242b3d") if (x+y)%2==0 else Color("22293a"))
			if c=="#":
				draw_rect(Rect2(p,Vector2(16,16)),INK)
				draw_rect(Rect2(p+Vector2.ONE,Vector2(14,12)),wall)
				draw_rect(Rect2(p+Vector2.ONE,Vector2(14,2)),wall.lightened(0.3))
				draw_line(p+Vector2(1,8),p+Vector2(15,8),wall.darkened(0.3))
			elif c=="G" and gates.has(t):
				var mode=int(gates[t].mode)
				var color=[GOLD,BLUE,PINK,Color("f56741")][mode]
				if solid(t):
					for gx in range(2,16,4): draw_rect(Rect2(p+Vector2(gx,1),Vector2(2,14)),color)
					label(["K","L","B","!"][mode],p+Vector2(4,12),color)
				else: draw_rect(Rect2(p+Vector2(6,6),Vector2(4,4)),color)
			elif c in ["^",">","<","A","V"]:
				var phase=trap_phase(t)
				var color=Color("f56741") if phase>=3.2 else GOLD if phase>trap_warn() else Color("667080")
				draw_rect(Rect2(p+Vector2.ONE,Vector2(14,14)),color.darkened(0.7))
				label(c,p+Vector2(4,12),color)
			elif c=="o": draw_rect(Rect2(p+Vector2(2,4),Vector2(12,9)),Color("131528"))
			elif c in ["~",")","(","="]: label("<" if c=="(" else "^" if c=="=" else ">",p+Vector2(4,12),BLUE)
	if not boss_mode:
		var exit_p=center(exit_tile)
		draw_rect(Rect2(exit_p-Vector2(6,6),Vector2(12,12)),GREEN if remaining()==0 else Color("526079"),false)
		label("E",exit_p+Vector2(-4,4),GREEN if remaining()==0 else Color("526079"))
	for t in chests:
		var p=center(t); var chest=chests[t]; var color=[CREAM,BLUE,PINK][chest.tier]
		draw_rect(Rect2(p-Vector2(6,4),Vector2(12,9)),INK)
		draw_rect(Rect2(p-Vector2(5,5 if chest.open else 3),Vector2(10,3)),color)
		if not chest.open:
			draw_rect(Rect2(p-Vector2(1,1),Vector2(2,4)),GOLD)
			var price=str(chest_cost(chest.tier))
			label(price,p+Vector2(-4.0*price.length(),-14),color)
	for t in snacks:
		var p=center(t)
		match snacks[t]:
			"d": donut(p)
			"p":
				draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-5),p+Vector2(5,-5),p+Vector2(0,6)]),GOLD)
				draw_rect(Rect2(p-Vector2(1,2),Vector2(2,2)),Color("be2f25"))
			"K":
				draw_rect(Rect2(p-Vector2(5,4),Vector2(5,5)),GOLD,false)
				draw_line(p,p+Vector2(6,0),GOLD,2); draw_line(p+Vector2(5,0),p+Vector2(5,3),GOLD,2)
			"$": label("*",p+Vector2(-4,4),GOLD)
	for fork in forks: draw_fork_mark(fork.p)
	for pickle in pickles: draw_pickle_mark(pickle.p)
	if saucer_swats>0: draw_saucer_mark(saucer_anchor())
	if rank("lucky")>0 and (soup_shots>0 or soup_time>0.25): draw_bowl_mark(player,soup_shots>0)
	for portal in pending_spawns:
		draw_arc(portal.p,7,clock*4,clock*4+5,12,PINK,1)
		label("!",portal.p+Vector2(-3,3),PINK)
	for z in zones: draw_circle(z.p,z.radius,Color(z.color,0.15)); draw_arc(z.p,z.radius,0,TAU,16,z.color)
	for e in enemies:
		if e.hp<=0 or e.get("boss",false): continue
		if e.attack>0.45: draw_line(e.p,e.p+e.dir*40,PINK)
		blob(e.p,e.kind,e.tick>0)
	if boss!=null and not boss.defeated: boss.draw(self)
	for s in shots:
		var olive=s.get("olive",false)
		var size=5 if olive else 3
		var color=Color("6f8f2a") if olive else Color("f56741") if s.hostile else GREEN if s.get("ignited",false) else GOLD
		draw_rect(Rect2(s.p-Vector2.ONE*(size/2.0),Vector2(size,size)),color)
	for orbiter in orbiters(): donut(orbiter.p.round(),1.0 if orbiter.clear else 0.35)
	if star_time>0 or shields>0: draw_arc(player,12,0,TAU,16,GOLD if star_time>0 else BLUE)
	if invincible<=0 or int(clock*12)%2==0:
		var bob=1 if moving and int(clock*8)%2 else 0
		draw_set_transform(offset+player.round()+Vector2(0,-bob),0,Vector2(1 if facing.x<0 else -1,1))
		draw_texture(HERO,Vector2(-8,-12))
		draw_set_transform(offset)
	for i in mini(4,croutons): draw_crouton_mark(crouton_anchor(i))
	if olive_ready:
		var nose=shot_dir
		draw_olive_mark(player+nose.normalized()*12)
	for e in effects:
		if e.text=="": draw_arc(e.p,maxf(1,e.radius*(1-e.life/0.35)),0,TAU,16,e.color)
		else: label(str(e.text),e.p+Vector2(-14,-10),e.color)
	draw_set_transform(Vector2.ZERO)
	draw_exit_marker()
	draw_rect(Rect2(0,0,256,36),Color("181c30"))
	var hearts=mini(max_hp,10)
	for i in hearts:
		var col=INK
		if i<hp: col=GREEN if heal_flash>0 and i==hp-1 else PINK
		draw_rect(Rect2(4+i*8,4,6,6),col)
	var hx=10+hearts*8
	label("$"+str(coins),Vector2(hx,12),GOLD)
	label("KEY "+str(keys),Vector2(mini(168,hx+48),12),GOLD)
	label("R"+str(level+1),Vector2(228,12),CREAM)
	if boss_mode and boss!=null: draw_boss_bar()
	else:
		label("FOOD "+str(10-remaining())+"/10",Vector2(4,26),GREEN)
		draw_threat()
		label("BAG "+str(item_count),Vector2(204,26),BLUE)
	draw_rect(Rect2(4,30,48,4),INK)
	draw_rect(Rect2(4,30,48*(1.0-clampf(flop_cd/flop_delay(),0,1)),4),GOLD)
	draw_rect(Rect2(0,208,256,16),Color("181c30"))
	centered(prompt_line(),219,GOLD if notice_time>0 else CREAM)
func draw_threat() -> void:
	var tier=threat_tier()
	var color=THREAT_COLORS[tier-1]
	var next=threat_next()
	label("THREAT "+str(tier)+(" >"+str(ceili(next))+"s" if next>=0 else " MAX"),Vector2(90,26),color)
	draw_rect(Rect2(90,30,104,3),INK)
	var fill=1.0 if next<0 else 1.0-next/THREAT_STEP
	var warn=next>=0 and next<5 and int(clock*6)%2==0
	draw_rect(Rect2(90,30,104*fill,3),CREAM if warn else color)
func draw_boss_bar() -> void:
	var open=boss.is_open() or boss.stunned>0
	label(Boss.NAME,Vector2(4,26),GOLD)
	draw_rect(Rect2(104,20,98,7),INK)
	draw_rect(Rect2(105,21,96*boss.hp_f/Boss.MAX_HP,5),GREEN if open else PINK)
	for f in Boss.PHASE_FLOORS.slice(0,2): draw_rect(Rect2(105+96*f,20,1,7),CREAM)
	label("OPEN" if open else "GUARD",Vector2(210,26),GREEN if open else BLUE)

func normalize_round() -> void:
	# Legacy-map compatibility while authored economy maps are being delivered.
	var food=[]; var empty=[]; var count_chests=0; var has_exit=false
	for y in range(1,12):
		for x in range(1,18):
			var c=board[y][x]
			if c in ["d","p"]: food.append(Vector2i(x,y))
			if c==".": empty.append(Vector2i(x,y))
			if c in ["c","b","l"]: count_chests+=1
			if c=="E": has_exit=true
	while food.size()>10:
		var t=food.pop_at(floori(food.size()/2.0))
		board[t.y][t.x]="."
	while food.size()<10 and not empty.is_empty():
		var t=empty.pop_back(); board[t.y][t.x]="d"; food.append(t)
	while count_chests<5 and not empty.is_empty():
		var t=empty.pop_at(int(empty.size()*0.6))
		board[t.y][t.x]=["c","c","b","b","l"][count_chests]; count_chests+=1
	if not has_exit: board[1][2]="E"

