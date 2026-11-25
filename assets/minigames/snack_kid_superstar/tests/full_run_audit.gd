extends SceneTree
# Automated route comparison, not human playtesting. Uses real input and normal damage.
# The navigator knows the map; --hesitant adds reaction pauses and occasional missed flops.
# --tour renders at real time. Reports go to stdout; no capture/log files are created.
var game
var held=Vector2i.ZERO
var reports=[]
var build="assault"
var hesitant=false
var hp_lost=0
var shields_lost=0
var earned=0
var spent=0
var max_pressure=0.0
var boss_react=0.0
var boss_seconds=0.0
var in_finale=false
var tour=false
var opened_doors: Dictionary={}
func _initialize() -> void: call_deferred("run")
func set_motion(direction: Vector2i) -> void:
	if direction==held and not tour: return
	for pair in [[KEY_A,Vector2i.LEFT],[KEY_D,Vector2i.RIGHT],[KEY_W,Vector2i.UP],[KEY_S,Vector2i.DOWN]]:
		var event=InputEventKey.new()
		event.keycode=pair[0]; event.physical_keycode=pair[0]
		event.pressed=direction==pair[1]
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	held=direction
func tap(key: int) -> void:
	var event=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=true
	game._unhandled_input(event)
func advance(dt: float) -> void:
	var old_hp=int(game.hp);var old_shields=int(game.shields);var old_coins=int(game.coins)
	game._process(dt)
	hp_lost+=maxi(0,old_hp-int(game.hp));shields_lost+=maxi(0,old_shields-int(game.shields))
	earned+=maxi(0,int(game.coins)-old_coins)
	max_pressure=maxf(max_pressure,float(game.threat_tier()))
	if game.boss_mode: boss_seconds+=dt
func choose_perk() -> void:
	var preference=["gatling","bodyguard","carousel","pinball","popcorn","toxic","candy","fondue","bulldozer","inspector","royalty","cashback"]
	if build=="guard": preference=["bodyguard","carousel","bulldozer","fondue","pinball","popcorn","gatling","toxic","candy","royalty","cashback","inspector"]
	if build=="scrappy": preference=["inspector","royalty","cashback","bulldozer","candy","fondue","toxic","pinball","popcorn","carousel","gatling","bodyguard"]
	var best=999;var pick=0
	for i in game.choices.size():
		var rank_order=preference.find(game.choices[i][0])
		if rank_order<best: best=rank_order;pick=i
	var before=int(game.coins)
	game.take_perk(pick)
	earned+=maxi(0,int(game.coins)-before)
func route(goal: Vector2i) -> Array:
	var field=game.build_nav(goal);var here=game.tile_at(game.player)
	var path=[]
	if not field.has(here): return path
	path.append(game.center(here))
	for step in 260:
		if here==goal: break
		var best=field[here];var next=here
		for d in game.DIRS:
			if field.has(here+d) and field[here+d]<best: best=field[here+d];next=here+d
		if next==here: break
		here=next;path.append(game.center(here))
	return path
func target(policy: String,opened: int) -> Dictionary:
	var field=game.build_nav(game.tile_at(game.player));var best=99999;var result={}
	# Full loot commits to side rooms; selective only pursues affordable nearby chests.
	if policy=="full" and opened<5 and game.elapsed<110:
		if game.keys==0:
			for t in game.snacks:
				if game.snacks[t]=="K" and field.has(t): return {"t":t,"kind":"food"}
		for t in game.gates:
			var gate=game.gates[t]
			if gate.open or (game.keys==0 and not (gate.mode==2 and game.hp>1)): continue
			for d in game.DIRS:
				if field.has(t+d): return {"t":t+d,"kind":"gate","door":t}
	# A bounded extra-loot route tests whether one optional detour pays, without demanding all five.
	if policy=="extra" and opened<4 and game.elapsed<45 and game.hp>=2 and game.coins>=game.chest_cost(1):
		if game.keys==0:
			for t in game.snacks:
				if game.snacks[t]=="K" and field.has(t) and int(field[t])<=6: return {"t":t,"kind":"food"}
		for t in game.gates:
			var gate=game.gates[t]
			if gate.open or (game.keys==0 and not (gate.mode==2 and game.hp>2)): continue
			for d in game.DIRS:
				if field.has(t+d) and int(field[t+d])<=6: return {"t":t+d,"kind":"gate","door":t}
	var wants_chest=policy!="rush" and opened<(5 if policy=="full" else 4 if policy=="extra" else 3)
	if wants_chest and (game.hp>=game.max_hp or game.remaining()==0):
		for t in game.chests:
			var c=game.chests[t]
			if c.open or not field.has(t) or game.coins<game.chest_cost(c.tier): continue
			if policy in ["selective","extra"] and int(field[t])>12: continue
			if int(field[t])<best: best=int(field[t]);result={"t":t,"kind":"chest"}
		if not result.is_empty(): return result
	for t in game.snacks:
		if game.snacks[t] in ["d","p"] and field.has(t) and int(field[t])<best:
			best=int(field[t]);result={"t":t,"kind":"food"}
	if not result.is_empty(): return result
	if policy=="full" and opened<5 and game.elapsed<110:
		for t in game.chests:
			if not game.chests[t].open and field.has(t): return {"t":t,"kind":"farm"}
	return {"t":game.exit_tile,"kind":"exit"}
# Simple delayed local dodging from visible tells; does not know future attacks.
func boss_step(dt: float) -> void:
	boss_react-=dt
	if boss_react<=0:
		boss_react=0.35 if hesitant else 0.2
		var b=game.boss
		var e=game.boss_enemy()
		var best=INF;var chosen=Vector2i.ZERO
		var food_path=[]
		if game.hp<game.max_hp and not game.snacks.is_empty():
			var nearest=INF;var food=Vector2i.ZERO
			for t in game.snacks:
				var distance=game.player.distance_to(game.center(t))
				if distance<nearest: nearest=distance;food=t
			food_path=route(food)
			while not food_path.is_empty() and game.player.distance_to(food_path[0])<4: food_path.pop_front()
		for direction in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var want=Vector2(direction)*game.move_speed()*0.35
			var spot=game.move_actor(game.player,want)
			var cost=absf(spot.distance_to(e.p)-68)*0.08
			if direction!=Vector2i.ZERO and spot.distance_to(game.player)<want.length()*0.65: cost+=80
			if not game.clear_line(spot,e.p): cost+=8
			if direction==held: cost-=0.3
			for foe in game.enemies:
				if foe.hp>0: cost+=maxf(0,36-spot.distance_to(foe.p))*4
			for shot in game.shots:
				if not shot.hostile: continue
				var predicted=shot.p+shot.v*0.25
				cost+=maxf(0,17-spot.distance_to(predicted))*7
			if b.action in ["slam_warn","slam"]:
				var relative=spot-e.p
				if relative.dot(b.aim)>-18: cost+=maxf(0,24-absf(relative.cross(b.aim)))*9
			if b.action=="rain_warn":
				for mark in b.marks: cost+=maxf(0,21-spot.distance_to(mark.p))*9
			if not food_path.is_empty(): cost+=spot.distance_to(food_path[0])*0.3
			if cost<best: best=cost;chosen=direction
		set_motion(chosen)
		if game.flop_cd<=0 and game.nearest_enemy(game.player,25)!=null and not hesitant: tap(KEY_SPACE)
	elif tour: set_motion(held)
	advance(dt)
func prepare_run() -> void:
	game.new_run()
func campaign(policy: String,seed_value: int) -> Dictionary:
	seed(seed_value);prepare_run();set_motion(Vector2i.ZERO)
	opened_doors.clear()
	hp_lost=0;shields_lost=0;earned=0;spent=0;max_pressure=0;boss_seconds=0;boss_react=0;in_finale=false
	var stages=[];var stage=-1;var start_time=0.0;var start_items=0;var start_kills=0
	var path=[];var goal={};var timeout=false;var max_enemies=0;var frames=0
	var last_progress=0.0;var previous_food=-1
	while frames<90000:
		frames+=1
		if tour:
			await create_timer(1.0/30).timeout
		if hesitant and frames%30==0 and game.state=="play":
			set_motion(Vector2i.ZERO)
			for pause in 6: advance(1.0/30)
		if game.state=="over": break
		if game.state=="choice":
			set_motion(Vector2i.ZERO)
			if stage>=0: stages.append({"stage":stage+1,"seconds":snapped(game.run_time-start_time,0.1),"hp":game.hp,"kills":game.kills-start_kills,"items":game.item_count-start_items,"food_left":game.remaining()})
			choose_perk();continue
		if game.level!=stage:
			stage=game.level;start_time=game.run_time;start_items=game.item_count;start_kills=game.kills
			path=[];goal={};last_progress=game.run_time;previous_food=game.remaining()
		if game.state in ["intro","victory"]: advance(1.0/30);continue
		if game.state!="play": break
		max_enemies=maxi(max_enemies,game.enemies.size())
		for door in game.gates:
			if game.gates[door].open: opened_doors[str(game.level)+":"+str(door)]=true
		if game.run_time-start_time>(260 if game.boss_mode else 150): timeout=true;break
		if game.boss_mode:
			if not in_finale: path=[];goal={};in_finale=true
			boss_step(1.0/30)
			if frames%300==0: await process_frame
			continue
		if game.remaining()!=previous_food: previous_food=game.remaining();last_progress=game.run_time
		if game.run_time-last_progress>12:
			path=[];goal={};last_progress=game.run_time
		if goal.is_empty() or (goal.get("kind","")=="farm" and (game.coins>=game.chest_cost(game.chests[goal.t].tier) or game.elapsed>=110)) or (goal.kind=="food" and not game.snacks.has(goal.t)) or (goal.kind=="chest" and game.chests[goal.t].open) or (goal.kind=="gate" and game.gates[goal.door].open):
			goal=target(policy,game.item_count-start_items);path=route(goal.t)
		if goal.kind in ["chest","exit","gate","farm"] and game.player.distance_to(game.center(goal.t))<(1.5 if goal.kind=="gate" else 6.0):
			set_motion(Vector2i.ZERO)
			if (policy=="camp" and goal.kind=="exit" and game.elapsed<90) or goal.kind=="farm":
				# Stay exposed; use normal cannon/flop, never grant invulnerability.
				if game.flop_cd<=0 and game.nearest_enemy(game.player,24)!=null: tap(KEY_SPACE)
				advance(1.0/30);continue
			var before=int(game.coins)
			var health_before=int(game.hp)
			tap(KEY_E);hp_lost+=maxi(0,health_before-int(game.hp));spent+=maxi(0,before-int(game.coins));earned+=maxi(0,int(game.coins)-before);advance(1.0/30);path=[];goal={};continue
		while not path.is_empty() and game.player.distance_to(path[0])<1.5: path.pop_front()
		if path.is_empty(): path=route(goal.t)
		var dt=1.0/30
		if not path.is_empty():
			var delta=path[0]-game.player
			var direction=Vector2i(signi(int(signf(delta.x))),0) if absf(delta.x)>absf(delta.y) else Vector2i(0,signi(int(signf(delta.y))))
			set_motion(direction)
			var axis_distance=absf(delta.x) if direction.x!=0 else absf(delta.y)
			dt=minf(dt,maxf(0.003,axis_distance/maxf(1,game.move_speed())))
		if game.flop_cd<=0 and game.nearest_enemy(game.player,20)!=null and (not hesitant or frames%3==0):
			tap(KEY_SPACE)
		advance(dt)
		if frames%3000==0: await process_frame
	set_motion(Vector2i.ZERO)
	stages.append({"stage":stage+1,"seconds":snapped(game.run_time-start_time,0.1),"hp":game.hp,"kills":game.kills-start_kills,"items":game.item_count-start_items,"food_left":game.remaining()})
	var result={"policy":policy,"build":build,"hesitant":hesitant,"seed":seed_value,"hp_lost":hp_lost,"shield_hits":shields_lost,"earned":earned,"spent":spent,"coins":game.coins,"score":game.score,"peak_threat":max_pressure,"boss_seconds":snapped(boss_seconds,0.1),"won":game.state=="over" and game.hp>0,"timeout":timeout,"stage":game.level+1,"seconds":snapped(game.run_time,0.1),"hp":game.hp,"items":game.item_count,"kills":game.kills,"max_enemies":max_enemies,"stages":stages}
	result["opened_doors"]=opened_doors.size()
	result["full_loot_stages"]=stages.filter(func(s):return int(s.items)>=5).size()
	print(JSON.stringify(result));return result
func run() -> void:
	game=load((get_script().resource_path.get_base_dir()+"/../scenes/Snack_Kid_Superstar.tscn").simplify_path()).instantiate()
	if game.get_script()==null:
		push_error("Game script did not load; implementation may be mid-edit.")
		game.free();quit(2);return
	root.add_child(game);game.set_process(false);game.save_enabled=false;game.audio.muted=true
	tour="--tour" in OS.get_cmdline_user_args()
	hesitant="--hesitant" in OS.get_cmdline_user_args()
	var policies=["rush","selective","full","camp"]
	var seeds=[19,47,83]
	var builds=["assault","guard","scrappy"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--policy="): policies=[arg.trim_prefix("--policy=")]
		if arg.begins_with("--seed="): seeds=[int(arg.trim_prefix("--seed="))]
		if arg.begins_with("--build="): builds=[arg.trim_prefix("--build=")]
	if tour: policies=["selective"];seeds=[19];builds=["assault"]
	for profile in builds:
		build=profile
		for policy in policies:
			for seed_value in seeds: reports.append(await campaign(policy,seed_value))
	game.queue_free();await process_frame;await process_frame;quit()
