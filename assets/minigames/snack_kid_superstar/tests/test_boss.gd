extends SceneTree
# Isolated contract tests. State fixtures here do not count as campaign victories.
var g
var checks=0
var failures=0
var defeats=0
var clears=0
var endings=0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL ",message)
func fresh() -> void:
	g.new_run();g.starter_draft=false;g.level=9;g.load_round();g.state="play"
	g.snacks.clear();g.player=g.center(g.exit_tile)
	g.interact()
	g.state="play"
	g.invincible=0;g.star_time=0;g.shields=0
	defeats=0;clears=0;endings=0
func open_boss() -> Dictionary:
	var e=g.boss_enemy()
	g.boss.action="dizzy";g.boss.timer=10;g.boss.budget=g.Boss.OPEN_DPS
	return e
func run() -> void:
	g=load((get_script().resource_path.get_base_dir()+"/../scenes/Snack_Kid_Superstar.tscn").simplify_path()).instantiate()
	root.add_child(g);g.set_process(false);g.save_enabled=false;g.audio.muted=true
	g.boss_defeated.connect(func(): defeats+=1)
	g.round_cleared.connect(func(_stage): clears+=1)
	g.game_over.connect(func(): endings+=1)
	fresh()
	verify(g.boss_mode and g.boss!=null and not g.boss_won,"last exit begins the finale")
	verify(g.state=="play" and endings==0,"entering finale does not report a win")
	var e=g.boss_enemy()
	verify(e!=null and e.get("boss",false) and e.hp==g.Boss.MAX_HP,"boss uses the shared enemy damage path")
	verify(g.fits(g.player) and g.fits(e.p,10),"arena starts fit on walkable floor")
	var before=g.boss.hp_f
	g.damage_enemy(e,999)
	verify(is_equal_approx(g.boss.hp_f,before),"intro protects the boss during the tell")
	g.boss.action="stalk";g.boss.budget=g.Boss.GUARD_DPS
	g.damage_enemy(e,1000)
	var guarded=before-g.boss.hp_f
	verify(guarded>0 and guarded<=g.Boss.HIT_CAP*g.Boss.ARMOR+0.001,"guarded hit has an armor and hit cap")
	fresh();e=open_boss();before=g.boss.hp_f
	g.damage_enemy(e,1000)
	verify(before-g.boss.hp_f>guarded,"open recovery rewards attacks")
	for i in 100: g.damage_enemy(e,1000)
	verify(before-g.boss.hp_f<=g.Boss.OPEN_DPS+0.001,"burst chains cannot bypass the damage budget")
	fresh();e=open_boss();before=g.boss.hp_f
	g.player=e.p+Vector2(0,40)
	g.fire(e.p,Vector2.DOWN,3,false);g.update_shots(0.001)
	verify(g.boss.hp_f<before,"ordinary cannon shots can hurt boss")
	before=g.boss.hp_f;g.boss.budget=g.Boss.OPEN_DPS
	g.blast(e.p,30,2,g.GOLD)
	verify(g.boss.hp_f<before,"blast items can hurt boss")
	before=g.boss.hp_f;g.boss.budget=g.Boss.OPEN_DPS
	g.add_zone(e.p,24,2,2,g.GREEN);g.update_zones(0.01)
	verify(g.boss.hp_f<before,"gas and cheese zones can hurt boss")
	fresh();e=open_boss();e.stun=99;e.slow=99
	g.boss.absorb_cc(g,e)
	verify(g.boss.stunned<=g.Boss.STUN_CAP and g.boss.stunned>0,"stuns are short but work")
	verify(e.stun==0 and e.slow<=1.5,"CC values cannot accumulate indefinitely")
	g.boss.stunned=0;e.stun=99;g.boss.absorb_cc(g,e)
	verify(g.boss.stunned==0,"stun immunity prevents pinning forever")
	fresh();e=g.boss_enemy();g.player=g.Boss.PLAYER_START
	var up=InputEventKey.new();up.keycode=KEY_W;up.physical_keycode=KEY_W;up.pressed=true
	g._unhandled_input(up);g.attack_cd=0;g.shots.clear();g.update_game(0.01)
	verify(g.shots.size()>0 and g.shots[0].v.normalized().is_equal_approx(Vector2.UP) and absf(e.p.x-g.player.x)<g.girth(e),"pressing up lines the directional cannon on the boss")
	g.ranks["splash"]=1;g.shot_dir=Vector2.LEFT;g.attack_cd=0;g.shots.clear();g.update_game(0.01)
	verify(g.shots.size()>0 and g.shots[0].v.normalized().dot((e.p-g.player).normalized())>0.99,"Smart Sauce finds the boss")
	# The drawn dome and base span about 34x20; its oval body is 32x22.
	verify(g.body_hit(e,e.p+Vector2(17,0),g.SHOT_R) and not g.body_hit(e,e.p+Vector2(18,0),g.SHOT_R),"boss side boundary matches its drawn width")
	verify(g.body_hit(e,e.p+Vector2(0,-12),g.SHOT_R) and not g.body_hit(e,e.p+Vector2(0,-13),g.SHOT_R),"boss top boundary matches its dome")
	verify(g.body_sweep(e,e.p+Vector2(-60,0),e.p+Vector2(60,0),g.SHOT_R),"a fast shot cannot skip the boss")
	g.player=e.p+Vector2(0,20)
	verify(g.hero_touch(e),"hero head under the boss base touches it")
	g.player=e.p+Vector2(0,27)
	verify(not g.hero_touch(e),"hero just below the boss base does not touch it")
	fresh();e=open_boss();g.player=Vector2(152,184)
	g.boss.begin(g,"ring")
	verify(g.boss.action=="ring_warn" and g.boss.timer>=0.8,"ring has a readable tell")
	g.shots.clear();var count=g.boss.ring_count();var gap_count=0
	for i in count:
		if g.boss.in_gap(i): gap_count+=1
	g.boss.fire_ring(g)
	verify(gap_count==3 and g.shots.size()==count-3,"ring preserves a three-bullet safe gap")
	g.boss.begin(g,"slam")
	var aim=g.boss.aim
	g.player+=Vector2(32,0)
	verify(g.boss.action=="slam_warn" and g.boss.aim==aim,"slam aim locks before the player dodges")
	g.boss.begin(g,"rain");var mark=g.player
	verify(not g.boss.marks.is_empty() and g.boss.marks[0].p==mark,"rain warns at the original player position")
	g.player=Vector2(24,184);g.hp=3;g.invincible=0
	g.boss.drop_meatballs(g)
	verify(g.hp==3,"leaving rain markers avoids the damage")
	g.boss.begin(g,"rain");g.boss.drop_meatballs(g)
	verify(g.hp==2,"standing in a warned rain marker costs one HP")
	fresh();e=open_boss()
	g.boss.hp_f=g.Boss.MAX_HP*0.66+0.25;e.hp=ceili(g.boss.hp_f)
	g.damage_enemy(e,1000)
	verify(g.boss.phase==2 and g.boss.action=="roar","first health threshold enters phase two")
	verify(is_equal_approx(g.boss.hp_f,g.Boss.MAX_HP*0.66),"damage cannot skip the phase floor")
	verify(g.snacks.size()>0,"phase transition offers healing food")
	before=g.boss.hp_f;g.damage_enemy(e,1000)
	verify(g.boss.hp_f==before,"transition immunity prevents phase skipping")
	g.boss.hp_f=g.Boss.MAX_HP*0.33+0.25;e=open_boss();g.damage_enemy(e,1000)
	verify(g.boss.phase==3 and g.boss.action=="roar","second threshold enters final phase")
	fresh();e=open_boss();g.boss.phase=3;g.boss.hp_f=0.25;e.hp=1
	g.damage_enemy(e,1000)
	verify(g.boss_won and g.state=="victory" and defeats==1,"boss defeat starts victory celebration once")
	verify(endings==0 and clears==0,"host result waits for celebration")
	g.boss_down();g.damage_enemy(e,1000)
	verify(defeats==1,"duplicate damage cannot duplicate boss defeat")
	var hp=g.hp;g.invincible=0;g.hurt()
	verify(g.hp==hp,"victory cannot be turned into posthumous death")
	for i in 65: g._process(0.05)
	verify(g.state=="over" and endings==1 and clears==1,"celebration emits exactly one clear and result")
	for i in 20: g._process(0.05)
	verify(endings==1 and clears==1,"later frames do not repeat the result")
	fresh();e=open_boss();g.boss.phase=3;g.boss.hp_f=0.25;e.hp=1
	g.hp=1;g.hurt();g.damage_enemy(e,1000)
	verify(g.state=="over" and g.hp==0 and not g.boss_won,"lethal player damage wins a same-frame race")
	verify(defeats==0 and endings==1,"death never emits boss victory")
	g.new_run()
	verify(g.boss==null and not g.boss_mode and not g.boss_won,"restart resets the entire finale")
	fresh();e=g.boss_enemy();g.boss.action="stalk";g.boss.budget=0
	before=g.boss.hp_f;g.damage_enemy(e,1000,true)
	verify(is_equal_approx(before-g.boss.hp_f,g.Boss.HIT_CAP*g.Boss.OPEN),"spikes bypass empty guard bucket but retain hit cap")
	g.boss.hp_f=g.Boss.MAX_HP*0.66+0.1;e.hp=ceili(g.boss.hp_f)
	g.damage_enemy(e,1000,true)
	verify(g.boss.phase==2 and is_equal_approx(g.boss.hp_f,g.Boss.MAX_HP*0.66),"trap damage preserves phase floor")
	before=g.boss.hp_f;g.damage_enemy(e,1000,true)
	verify(g.boss.hp_f==before,"traps respect phase transition immunity")
	fresh();g.boss.action="rain_warn";g.boss.marks=[{"p":g.player}];g.shields=2
	g.hurt()
	verify(g.hp==3 and g.shields==1 and g.boss.action=="winded","shield break creates boss opening without heart loss")
	verify(g.boss.marks.is_empty() and g.boss.stagger_cd==g.Boss.STAGGER_CD,"shield stagger cancels rain and starts cooldown")
	g.boss.action="stalk";g.invincible=0;g.hurt()
	verify(g.shields==0 and g.boss.action=="stalk","another shield cannot bypass stagger cooldown")
	g.boss.stagger_cd=0;g.boss.action="roar";g.boss.stagger(g)
	verify(g.boss.action=="roar","shield stagger cannot cancel phase transition")
	var spikes=0
	for row in g.Boss.ARENA: spikes+=row.count("^")
	verify(spikes==4 and g.cell(g.tile_at(g.Boss.PLAYER_START))!="^" and g.cell(g.tile_at(g.Boss.START))!="^","four boss spikes avoid both starting positions")
	fresh();e=open_boss();e.p=g.center(Vector2i(9,4));g.elapsed=3.3-13*0.11
	g.update_traps(0.01)
	verify(g.boss.spike_cd==0.5,"boss spike hit starts an independent half-second cooldown")
	g.damage_enemy(e,1);e.tick=0;before=g.boss.hp_f
	g.update_traps(0.01)
	verify(g.boss.hp_f==before,"ordinary hits cannot shorten spike cooldown")
	g.boss.spike_cd=0;g.update_traps(0.01)
	verify(g.boss.hp_f<before,"spikes can damage again after their own cooldown")
	print("BOSS CHECKS ",checks," FAILED ",failures)
	g.shutdown();g.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)
