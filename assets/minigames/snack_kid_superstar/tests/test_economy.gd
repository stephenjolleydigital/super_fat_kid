extends SceneTree
var checks=0
var failures=0
func verify(ok: bool,what: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL ",what)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g=load((get_script().resource_path.get_base_dir()+"/../scenes/Snack_Kid_Superstar.tscn").simplify_path()).instantiate()
	root.add_child(g); g.set_process(false); g.save_enabled=false; g.audio.muted=true
	g.new_run()
	verify(g.hp==3 and g.max_hp==3,"single-life 3 HP start")
	verify(g.Items.ITEMS.size()==50,"50 chest items")
	verify(g.Perks.ITEMS.size()==14,"separate 14 super perks")
	for l in 10:
		g.level=l; g.load_round()
		verify(g.remaining()==10,"10 foods stage "+str(l))
		verify(g.chests.size()==5,"five chests stage "+str(l))
		var field=g.build_nav(Vector2i(1,1))
		verify(field.has(g.exit_tile),"exit reachable")
		for t in g.snacks:
			if g.snacks[t]=="K": verify(field.has(t),"key accessible")
		for t in g.gates: g.gates[t].open=true
		field=g.build_nav(Vector2i(1,1))
		for t in g.snacks: verify(field.has(t),"food reachable after gates")
		for t in g.chests: verify(field.has(t),"chest reachable after gates")
	g.new_run(); g.state="play"; g.invincible=0
	g.hurt(); verify(g.hp==2 and g.state=="play","damage removes HP")
	var t=g.snacks.keys().filter(func(k):return g.snacks[k] in ["d","p"])[0]
	g.collect(t); verify(g.hp==3,"food heals 1")
	g.hp=1; g.invincible=0; g.shields=0; g.hurt()
	verify(g.state=="over" and g.hp==0,"one-life death")
	g.new_run(); g.state="play"
	var chest=g.chests.keys()[0]; g.player=g.center(chest); g.coins=0
	g.interact(); verify(not g.chests[chest].open,"cannot afford chest")
	g.coins=1000; var before=g.coins; g.interact()
	verify(g.chests[chest].open and g.item_count==1 and g.coins<before,"chest pays and grants item")
	g.interact(); verify(g.item_count==1,"cannot reopen chest")
	g.new_run(); g.state="play"; var count=g.enemies.size()
	g.spawn_cd=0; g.update_director(0.1)
	verify(g.pending_spawns.size()>0,"reinforcement warning")
	g.update_director(2)
	verify(g.enemies.size()>count,"reinforcement spawns")
	g.run_time=300; g.spawn_cd=0; g.update_director(0.1)
	verify(g.spawn_cd<10,"difficulty escalates over time")
	g.new_run(); g.coins=100000
	verify(g.state=="choice" and g.starter_draft,"starter draft before stage 1")
	g.take_perk(0)
	verify(not g.starter_draft and g.level==0,"starter perk starts the run")
	for l in 10:
		g.level=l; g.load_round(); g.state="play"; g.coins=100000
		for gate in g.gates: g.gates[gate].open=true
		for c in g.chests:
			g.player=g.center(c); g.interact()
		for food in g.snacks.keys(): g.collect(food)
		verify(g.remaining()==0,"all food collected")
		verify(g.state=="play","cleared food does not force exit")
		g.player=g.center(g.exit_tile); g.interact()
		if l<9:
			verify(g.state=="choice","lever grants super perk")
			g.take_perk(0)
		else:
			verify(g.state=="intro" and g.boss_mode,"final lever starts the boss")
	verify(g.item_count==50,"50 chest rewards per run")
	verify(g.state=="intro" and g.hp>0 and not g.boss_won,"ten stages require the final boss")
	var picks=0
	for n in g.draft_ranks.values(): picks+=n
	verify(picks==10,"ten stage perk picks")
	g.new_run(); g.state="play"; g.invincible=999
	for i in 1200: g.update_game(1.0/60)
	verify(g.enemies.size()<=28,"bounded enemy population")
	audit_facing(g)
	audit_aiming(g)
	audit_contacts(g)
	audit_orbiters(g)
	audit_movement_perks(g)
	audit_price_progression(g)
	audit_new_interactions(g)
	audit_vaults(g)
	audit(g)
	audit_cabinet()
	print("CHECKS ",checks," FAILED ",failures)
	g.shutdown()
	g.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
func fresh(g) -> void:
	g.new_run()
	g.starter_draft=false
	g.state="play"
	g.invincible=999
	g.spawn_cd=999
	g.enemies.clear()
	g.shots.clear()
	g.zones.clear()
	g.attack_cd=10
	g.gas_cd=10
	g.pulse_cd=10
	g.ranks.clear()
func dummy(g, at: Vector2, hp: int) -> Dictionary:
	return {"p":at,"home":at,"kind":0,"hp":hp,"slow":0.0,"stun":0.0,"cool":9.0,"attack":0.0,"dir":Vector2.LEFT,"tick":0.0,"goal":at}
func snack(g, kind: String):
	for t in g.snacks.keys():
		if g.snacks[t]==kind: return t
	return null
func zone_of(g, color: Color):
	for z in g.zones:
		if z.color==color: return z
	return null
func audit_cabinet() -> void:
	var cab = load((get_script().resource_path.get_base_dir()+"/../scenes/Cabinet_Demo.tscn").simplify_path()).instantiate()
	root.add_child(cab)
	cab.game.save_enabled = false
	cab.game.audio.muted = true
	cab.game.set_process(false)
	cab.game.new_run(); cab.game.starter_draft=false; cab.game.state="play"
	var up=InputEventKey.new()
	up.keycode=KEY_UP; up.physical_keycode=KEY_UP; up.pressed=true
	root.push_input(up)
	verify(cab.game.shot_dir==Vector2.UP and game_aim_once(cab),"cabinet forwards the aim key to the game once")
	cab.game.exit_requested.emit()
	verify(str(cab.result.get("outcome", "")) == "exit", "cabinet hears exit and does not quit")
	cab.game.hp = 0
	cab.game.end_run()
	verify(str(cab.result.get("outcome", "")) == "dead", "cabinet hears game over")
	verify(cab.get_parent() == root, "cabinet leaves the host tree running")
	cab.game.round_cleared.emit(1)
	verify(cab.rounds_cleared.size() == 1, "cabinet records a cleared stage")
	cab.queue_free()
func audit(g) -> void:
	audit_items(g)
	audit_stacks(g)
	audit_rules(g)
	audit_doors(g)
	audit_play(g)
func audit_items(g) -> void:
	var seen={}
	for item in g.Items.ITEMS:
		var id=str(item[0])
		seen[id]=true
		probe(g,id)
	verify(seen.size()==50,"every chest item was probed")
func probe(g, id: String) -> void:
	fresh(g)
	if id=="pepper":
		g.ranks["pepper"]=1
		g.attack_cd=0
		g.shots.clear()
		g.update_game(0.05)
		verify(g.shots.size()>=1,"pepper fires")
		verify(g.shots[0].damage==1+g.rank("pepper"),"pepper damage stacks with the starter cannon")
	elif id=="gas":
		g.ranks["gas"]=1
		g.gas_cd=0
		g.update_game(0.05)
		verify(zone_of(g,g.GREEN)!=null,"gas cloud")
	elif id=="orbit":
		g.ranks["orbit"]=1
		g.elapsed=0
		var orb=dummy(g,g.player+Vector2.from_angle(0.15)*20,5)
		orb.stun=10
		g.enemies=[orb]
		g.update_game(0.05)
		verify(orb.hp<5,"orbit bonks")
	elif id=="sprinkles":
		g.ranks["sprinkles"]=1
		g.shots.clear()
		g.collect(snack(g,"d"))
		verify(g.shots.size()>=8,"sprinkles volley")
	elif id=="cheese":
		g.ranks["cheese"]=1
		g.collect(snack(g,"p"))
		verify(zone_of(g,g.GOLD)!=null,"cheese pool")
	elif id=="nova":
		g.ranks["nova"]=1
		g.eaten=4
		var foe=dummy(g,g.player+Vector2(16,0),6)
		g.enemies=[foe]
		g.collect(snack(g,"d"))
		verify(foe.hp<6,"nova blast")
	elif id=="dash":
		g.ranks["dash"]=1
		g.flop_cd=0
		var ev=InputEventKey.new()
		ev.pressed=true
		ev.keycode=KEY_SPACE
		g._unhandled_input(ev)
		verify(g.flop_time>0,"flop starts")
		verify(g.flop_cd<2.8 and g.flop_cd>2.4,"dash shortens the flop")
		verify(g.flop_speed()>=158,"dash flop travels farther")
	elif id=="ricochet":
		g.ranks["ricochet"]=1
		g.fire(Vector2(20,24),Vector2.LEFT,1,false)
		var shot=g.shots.back()
		verify(shot.bounce==1,"ricochet stores a bounce")
		g.update_shots(0.05)
		verify(shot.v.x>0,"ricochet flips off a wall")
	elif id=="pierce":
		g.ranks["pierce"]=1
		g.fire(g.player,Vector2.RIGHT,1,false)
		verify(g.shots.back().pierce==1,"pierce rank")
	elif id=="frost":
		g.ranks["frost"]=1
		var foe=dummy(g,g.player+Vector2(40,0),5)
		g.damage_enemy(foe,1)
		verify(foe.hp==4 and foe.slow>=1,"frost slows a survivor")
	elif id=="chain":
		g.ranks["chain"]=1
		var first=dummy(g,Vector2(100,40),1)
		var second=dummy(g,Vector2(130,40),8)
		g.enemies=[first,second]
		g.player=Vector2(80,40)
		g.damage_enemy(first,5)
		verify(second.hp<8,"chain zap")
	elif id=="bomb":
		g.ranks["bomb"]=1
		var first=dummy(g,Vector2(100,40),1)
		var second=dummy(g,Vector2(120,40),8)
		g.enemies=[first,second]
		g.damage_enemy(first,5)
		verify(second.hp<8,"popcorn blast")
	elif id=="speed":
		var base=g.move_speed()
		g.ranks["speed"]=1
		verify(g.move_speed()>base,"speed rank")
		verify(g.flop_speed()>150,"speed lengthens the flop")
	elif id=="magnet":
		var tile=Vector2i(2,1)
		g.snacks[tile]="d"
		g.player=g.center(Vector2i(1,1))
		g.try_collect()
		verify(g.snacks.has(tile),"magnet rank 0 misses the next tile")
		g.ranks["magnet"]=1
		g.try_collect()
		verify(not g.snacks.has(tile),"magnet rank 1 grabs the next tile")
	elif id=="shield":
		g.ranks["shield"]=1
		g.load_round()
		verify(g.shields>=1,"shield refreshes each round")
	elif id=="sugar":
		g.ranks["sugar"]=1
		g.collect(snack(g,"d"))
		verify(g.sugar_time>=3,"sugar overdrive")
	elif id=="rapid":
		var plain=g.cannon_delay()
		g.ranks["rapid"]=1
		verify(g.cannon_delay()<plain,"rapid shortens the cannon")
		g.ranks["rapid"]=12
		g.sugar_time=3
		verify(g.cannon_delay()>0.05,"rapid plus sugar stays positive")
	elif id=="spread":
		g.ranks["spread"]=1
		g.attack_cd=0
		g.shots.clear()
		g.update_game(0.05)
		verify(g.shots.size()==2,"spread adds a shot")
	elif id=="trail":
		g.ranks["trail"]=1
		g.collect(snack(g,"d"))
		var mine=false
		for z in g.zones:
			if z.mine: mine=true
		verify(mine,"crumb mine")
	elif id=="retaliate":
		g.ranks["retaliate"]=1
		g.invincible=0
		g.shields=0
		g.hp=3
		var foe=dummy(g,g.player+Vector2(20,0),10)
		g.enemies=[foe]
		g.hurt()
		verify(g.hp==2 and foe.hp<10,"retaliate answers a lost heart")
	elif id=="trap":
		g.level=1
		g.load_round()
		g.state="play"
		g.ranks["trap"]=1
		g.invincible=999
		var spike=Vector2i.ZERO
		var found=false
		for y in 13:
			for x in 19:
				if g.cell(Vector2i(x,y))=="^":
					spike=Vector2i(x,y)
					found=true
		verify(found,"spike school has a spike")
		var offset=fmod((spike.x+spike.y)*0.11,4.0)
		g.elapsed=fmod(3.5-offset+4.0,4.0)
		var foe=dummy(g,g.center(spike),10)
		g.enemies=[foe]
		g.player=g.center(Vector2i(1,1))
		g.update_traps(0.05)
		verify(foe.hp<=6,"trap rank adds spike damage")
	elif id=="key":
		g.ranks["key"]=1
		g.snacks[Vector2i(5,2)]="K"
		g.collect(Vector2i(5,2))
		verify(g.keys==1 and g.star_time>=2,"key grants rampage")
	elif id=="combo":
		g.ranks["combo"]=1
		var before=g.score
		g.collect(snack(g,"d"))
		verify(g.score-before>=125,"combo score")
	elif id=="revive":
		g.ranks["revive"]=1
		g.hp=1
		g.shields=0
		g.invincible=0
		g.rescued=false
		g.hurt()
		verify(g.rescued and g.hp==1 and g.state=="play","fatal hit rescue")
		g.invincible=0
		g.hp=1
		g.hurt()
		verify(g.state=="over","rescue is once per run")
	elif id=="range":
		g.ranks["range"]=1
		g.fire(g.player,Vector2.RIGHT,1,false)
		verify(g.shots.back().life>=1.4,"range lifetime")
	elif id=="knock":
		g.ranks["knock"]=1
		g.player=Vector2(60,40)
		var foe=dummy(g,Vector2(90,40),5)
		g.damage_enemy(foe,1)
		verify(foe.p.x>90,"knock pushes")
	elif id=="stink":
		g.ranks["gas"]=1
		g.ranks["stink"]=1
		g.gas_cd=0
		g.update_game(0.05)
		var cloud=zone_of(g,g.GREEN)
		verify(cloud!=null and cloud.life>2.4,"stink lengthens gas")
	elif id=="giant":
		g.ranks["gas"]=1
		g.ranks["giant"]=1
		g.gas_cd=0
		g.update_game(0.05)
		var cloud=zone_of(g,g.GREEN)
		verify(cloud!=null and cloud.radius>=31,"giant widens gas")
	elif id=="spicy":
		g.ranks["gas"]=1
		g.ranks["spicy"]=1
		g.gas_cd=0
		g.update_game(0.05)
		var cloud=zone_of(g,g.GREEN)
		verify(cloud!=null and cloud.damage>=2,"spicy adds gas damage")
	elif id=="shieldpop":
		g.ranks["shieldpop"]=1
		g.shields=1
		g.invincible=0
		g.hp=3
		var foe=dummy(g,g.player+Vector2(20,0),8)
		g.enemies=[foe]
		g.hurt()
		verify(g.hp==3 and g.shields==0 and foe.hp<8,"broken shield explodes")
	elif id=="pizza":
		g.ranks["pizza"]=1
		g.collect(snack(g,"p"))
		verify(g.pizza_time>=2,"pizza turbo")
	elif id=="finish":
		g.ranks["finish"]=1
		g.snacks.clear()
		g.player=Vector2(80,40)
		g.drop_pickle()
		verify(g.pickles.size()==1,"a flop leaves a pickle")
		var tripped=dummy(g,g.pickles[0].p,3)
		g.enemies=[tripped]
		g.update_toys(0.05)
		verify(int(tripped.hp)<3 and g.pickles.is_empty(),"the pickle trips the first monster")
		g.ranks["finish"]=6
		g.pickles.clear()
		for i in 4: g.drop_pickle()
		verify(g.pickles.size()==3,"only three pickles sit at once")
		verify(is_equal_approx(g.move_speed(),48.0),"the pickle is not a speed coupon")
	elif id=="armor":
		g.ranks["armor"]=1
		g.croutons=1
		g.hp=3
		g.shields=0
		g.invincible=0
		g.shots=[{"p":g.player+Vector2(8,0),"v":Vector2.ZERO,"life":1.0,"hostile":true,"damage":1,"pierce":0,"bounce":0}]
		g.update_shots(0.05)
		verify(g.hp==3 and g.croutons==0 and g.shots.is_empty(),"crouton eats one bullet")
		g.invincible=0
		g.shots=[{"p":g.player+Vector2(4,0),"v":Vector2.ZERO,"life":1.0,"hostile":true,"damage":1,"pierce":0,"bounce":0}]
		g.update_shots(0.05)
		verify(g.hp==2,"the next bullet still hurts")
	elif id=="lucky":
		g.ranks["lucky"]=1
		g.moving=false
		g.soup_time=0
		g.soup_shots=0
		g.hp=3
		g.shields=0
		g.invincible=0
		g.update_toys(1.3)
		verify(g.soup_shots>=1,"standing still serves the warrant")
		g.shots=[{"p":g.player+Vector2(6,0),"v":Vector2.ZERO,"life":1.0,"hostile":true,"damage":1,"pierce":0,"bounce":0}]
		g.update_shots(0.05)
		verify(g.hp==3 and g.soup_shots==0,"the bowl arrests the shot")
		g.soup_time=1
		g.soup_shots=1
		g.moving=true
		g.update_toys(0.05)
		verify(g.soup_time==0 and g.soup_shots==0,"moving spills the soup")
		verify(is_equal_approx(g.dodge_chance(),0.0),"soup is not a dodge coupon")
	elif id=="oil":
		g.ranks["oil"]=3
		verify(is_equal_approx(g.oil_scale(),1.0),"oil rank 3 is full speed")
		g.ranks["oil"]=8
		verify(g.oil_scale()<=1.0,"oil never becomes a speed boost")
	elif id=="wind":
		g.ranks["wind"]=1
		g.fork_ready=1
		g.forks.clear()
		g.player=Vector2(80,40)
		g.shields=0
		g.invincible=0
		g.hp=3
		g.enemies.clear()
		g.hurt()
		verify(g.forks.size()==1 and g.fork_ready==0 and g.hp==2,"a lost heart plants the fork")
		var pinned=dummy(g,g.forks[0].p,4)
		g.enemies=[pinned]
		g.update_toys(0.05)
		verify(float(pinned.stun)>0.4,"the fork pins who steps on it")
		g.forks[0].age=1.0
		g.player=g.forks[0].p
		g.moving=true
		g.update_toys(0.05)
		verify(g.forks.is_empty() and g.fork_ready==1,"walking back picks the fork up")
		g.ranks["wind"]=12
		verify(is_equal_approx(g.fan_scale(),1.0),"forks do not weaken fans")
	elif id=="sense":
		g.ranks["sense"]=1
		verify(g.trap_warn()<2.2,"sense warns earlier")
	elif id=="gourmet":
		g.ranks["gourmet"]=1
		var before=g.score
		g.damage_enemy(dummy(g,Vector2(120,40),1),5,true)
		verify(g.score-before>=450,"gourmet trap score")
	elif id=="gate":
		g.ranks["gate"]=1
		g.keys=1
		var door=Vector2i(3,1)
		g.gates[door]={"open":false,"mode":0,"charge":0.0}
		g.player=g.center(door)
		var foe=dummy(g,g.player+Vector2(18,0),9)
		g.enemies=[foe]
		g.interact()
		verify(g.gates[door].open and g.keys==0,"ordinary lock spends a key")
		verify(foe.hp<9,"opening a gate blasts")
	elif id=="bonus":
		var perk=g.Perks.definition("cashback")
		verify("50%" in str(perk[2]) and "30 coins" in str(perk[3]) and "olive" in str(perk[3]),"cashback text matches its olive grant")
		verify(int(perk[4]["bonus"])==1,"cashback still grants one bonus rank")
		g.ranks["bonus"]=1
		g.olive_ready=false
		g.olive_time=0
		g.facing=Vector2.RIGHT
		g.update_toys(2.3)
		verify(g.olive_ready,"olive loads beside you")
		g.attack_cd=0
		g.shots.clear()
		g.update_game(0.05)
		verify(g.olive_ready and g.shots.size()>=1,"auto fire keeps the olive")
		var press=InputEventKey.new()
		press.keycode=KEY_Z
		press.physical_keycode=KEY_Z
		press.pressed=true
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		g.attack_cd=0
		g.shots.clear()
		g.update_game(0.05)
		var spent=false
		for s in g.shots:
			if s.get("olive",false): spent=true
		verify(spent and not g.olive_ready,"holding Z spends the olive")
		var stuck=dummy(g,g.player+Vector2(16,0),9)
		var neighbor=dummy(g,g.player+Vector2(30,6),9)
		g.enemies=[stuck,neighbor]
		g.shots[0].p=stuck.p
		g.shots[0].v=Vector2.ZERO
		g.shots[0].life=1
		g.update_shots(0.05)
		verify(int(stuck.hp)<9 and int(neighbor.hp)<9,"olive pops the neighbor")
		var release=InputEventKey.new()
		release.keycode=KEY_Z
		release.physical_keycode=KEY_Z
		release.pressed=false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
		g.score=0
		g.level=0
		g.finish_round()
		verify(g.score==500,"clear pay is no longer a percent")
		verify(g.state=="choice","a cleared early stage still drafts")
	elif id=="leech":
		g.ranks["leech"]=1
		g.shields=0
		g.kills=0
		for i in 4:
			g.damage_enemy(dummy(g,Vector2(140,40),1),5)
		verify(g.shields==1,"leech restores a shield")
	elif id=="pulse":
		g.ranks["pulse"]=1
		g.pulse_cd=0
		var foe=dummy(g,g.player+Vector2(20,0),5)
		g.enemies=[foe]
		g.update_game(0.05)
		verify(foe.hp<5,"pulse hits")
	elif id=="slow":
		g.ranks["slow"]=1
		verify(g.slow_scale()<1.0,"slow aura")
		g.ranks["slow"]=12
		verify(g.slow_scale()>=0.25,"slow never reverses")
	elif id=="star":
		g.ranks["star"]=1
		g.snacks[Vector2i(5,2)]="$"
		g.collect(Vector2i(5,2))
		verify(g.star_time>=6,"star duration")
	elif id=="crumbscore":
		var card=g.Items.definition("crumbscore")
		verify("One swat per rank" in str(card[3]) and "up to 3" in str(card[3]),"saucer card matches one swat per rank")
		g.ranks["crumbscore"]=1
		g.saucer_swats=1
		g.saucer_crack=0
		g.facing=Vector2.RIGHT
		var spot=Vector2i(2,1)
		for y in 12:
			for x in 17:
				if not g.solid(Vector2i(x,y)) and not g.solid(Vector2i(x+1,y)):
					spot=Vector2i(x,y)
		g.player=g.center(spot)
		var plate=g.saucer_anchor()
		g.shots=[{"p":plate,"v":Vector2.ZERO,"life":1.0,"hostile":true,"damage":1,"pierce":0,"bounce":0,"hit":[]}]
		g.update_shots(0.05)
		verify(g.saucer_swats==0 and g.shots.size()==1 and not g.shots[0].hostile,"saucer bats the shot back")
		g.shots=[{"p":plate,"v":Vector2.ZERO,"life":1.0,"hostile":true,"damage":1,"pierce":0,"bounce":0,"hit":[]}]
		g.update_shots(0.05)
		verify(g.shots[0].hostile,"a cracked saucer does not bat")
		g.ranks["crumbscore"]=6
		g.saucer_swats=0
		g.saucer_crack=0.1
		g.update_toys(0.2)
		verify(g.saucer_swats==3,"the saucer comes back with at most three swats")
		var before=g.score
		g.collect(snack(g,"d"))
		verify(g.score-before==100,"snacks no longer pay crumb cash")
	elif id=="eject":
		g.ranks["eject"]=1
		g.fire(g.player,Vector2.RIGHT,1,true)
		g.invincible=0
		g.shields=0
		g.hp=3
		var foe=dummy(g,g.player+Vector2(30,0),4)
		g.enemies=[foe]
		g.hurt()
		var hostile=false
		for s in g.shots:
			if s.hostile: hostile=true
		verify(not hostile and foe.stun>=1,"eject clears shots and stuns")
	elif id=="snare":
		g.ranks["snare"]=1
		var foe=dummy(g,g.player+Vector2(40,0),4)
		g.enemies=[foe]
		g.collect(snack(g,"d"))
		verify(foe.slow>=1,"snare")
	elif id=="splash":
		g.ranks["splash"]=1
		var first=dummy(g,Vector2(100,40),5)
		var second=dummy(g,Vector2(116,40),5)
		g.enemies=[first,second]
		g.fire(first.p,Vector2.RIGHT,1,false)
		g.update_shots(0.05)
		verify(first.hp==4,"splash does not double-hit the struck target")
		verify(second.hp<5,"splash hits a neighbor")
	elif id=="munch":
		g.ranks["munch"]=1
		var foe=dummy(g,g.player+Vector2(16,0),5)
		g.enemies=[foe]
		g.collect(snack(g,"d"))
		verify(foe.hp<5,"munch")
	elif id=="restock":
		g.ranks["restock"]=1
		g.load_round()
		verify(g.shields>=1 and g.shots.size()>=8,"restock opens with a volley and a shield")
	else:
		verify(false,"missing probe "+id)
func audit_stacks(g) -> void:
	fresh(g)
	g.ranks["pepper"]=1
	g.perk_bonuses={"pepper":2,"rapid":1,"spread":1}
	g.attack_cd=0
	g.shots.clear()
	g.update_game(0.05)
	verify(g.rank("pepper")==4,"chest pepper, stage pepper and starter stack")
	verify(g.shots.size()==2,"stage spread changes the volley")
	verify(g.shots[0].damage==5,"stacked cannon damage")
	g.ranks["dash"]=12
	verify(g.flop_delay()>0.3,"max dash cooldown stays positive")
func audit_rules(g) -> void:
	fresh(g)
	verify(g.chest_cost(0)==8,"stage 1 tin costs 8")
	g.coins=0
	g.damage_enemy(dummy(g,Vector2(120,40),1),5)
	verify(g.coins>=g.chest_cost(0),"one stage-1 kill buys a tin")
	fresh(g)
	g.invincible=0
	g.shields=0
	g.hp=3
	g.hurt()
	verify(g.hp==2,"a hit lands")
	g.hurt()
	verify(g.hp==2,"iframes block the immediate second hit")
	fresh(g)
	g.invincible=0
	g.shields=0
	g.hp=3
	g.player=Vector2(80,40)
	g.enemies=[dummy(g,Vector2(86,40),5)]
	g.hurt()
	verify(g.player.x<78,"a hit shoves you off the monster")
	fresh(g)
	g.state="pause"
	var elapsed=g.elapsed
	g._process(0.5)
	verify(is_equal_approx(g.elapsed,elapsed),"pause freezes the round")
	fresh(g)
	var origin=g.center(Vector2i(1,1))
	var blocked=g.move_actor(origin,Vector2(-40,0))
	verify(blocked.x>origin.x-8 and g.fits(blocked),"walls stop movement")
	var walked=origin
	for i in 60:
		walked=g.move_actor(walked,Vector2(40,0)/60.0)
	verify(walked.x>origin.x+20 and g.fits(walked),"continuous movement stays on open floor")
	fresh(g)
	g.gates.clear()
	var left=Vector2i(2,1)
	var right=Vector2i(4,1)
	g.gates[left]={"open":false,"mode":1,"charge":0.0}
	g.gates[right]={"open":false,"mode":1,"charge":0.0}
	g.keys=1
	g.player=g.center(left)
	g.interact()
	g.keys=1
	g.player=g.center(right)
	g.interact()
	verify(g.loans.size()==2 and int(g.loans[0])==3 and int(g.loans[1])==3,"two loans keep separate debts")
	g.damage_enemy(dummy(g,Vector2(140,80),1),5)
	verify(g.loans.size()==2 and int(g.loans[0])==2 and int(g.loans[1])==2,"one kill ticks both loans")
	for i in 2:
		g.damage_enemy(dummy(g,Vector2(140,80),1),5)
	verify(g.loans.is_empty() and g.keys==2,"each loan refunds its own key")
	fresh(g)
	g.notice_time=0
	g.player=g.center(Vector2i(1,1))
	verify(g.prompt_line().begins_with("EXIT"),"offscreen exit is named")
	fresh(g)
	g.snacks.clear()
	g.notice_time=0
	g.exit_tile=Vector2i(4,1)
	g.chests[Vector2i(5,1)]={"tier":0,"open":false}
	g.player=Vector2(80,g.center(Vector2i(4,1)).y)
	g.coins=100
	g.state="play"
	verify(g.prompt_line().begins_with("E: LEAVE"),"prompt and exit agree beside a chest")
	g.interact()
	verify(g.state=="choice" and g.chests[Vector2i(5,1)].open==false,"E leaves instead of buying the neighbor")
func audit_doors(g) -> void:
	fresh(g)
	g.level=2
	g.load_round()
	g.state="play"
	g.notice_time=0
	var pantry=null
	for t in g.gates: pantry=t
	verify(g.gates[pantry].mode==2,"pantry door is a blood lock")
	g.player=g.center(pantry)+Vector2(30,0)
	verify("AHEAD" in g.prompt_line(),"blood lock explains itself before you can spend")
	g.player=g.center(pantry)
	g.keys=0
	g.hp=3
	g.interact()
	verify(g.gates[pantry].open and g.hp==2,"blood lock spends HP instead of the only key")
	fresh(g)
	g.level=5
	g.load_round()
	g.state="play"
	var alarm=null
	for t in g.gates: alarm=t
	verify(g.gates[alarm].mode==3,"oil vault is an alarm lock")
	g.keys=1
	g.coins=0
	g.player=g.center(alarm)
	g.interact()
	verify(g.gates[alarm].open and g.coins==30 and g.keys==0,"alarm spends a key and pays 30")
	verify(g.pending_spawns.size()>=1,"alarm calls reinforcements")
	fresh(g)
	g.level=8
	g.load_round()
	verify(g.gates.size()==2,"buffet has two optional wings")
	for t in g.gates:
		verify(int(g.gates[t].mode)==1,"each buffet wing is its own loan")
	fresh(g)
	g.level=9
	g.load_round()
	g.state="play"
	var finale=null
	for t in g.gates: finale=t
	verify(g.gates[finale].mode==0,"showdown lock is ordinary")
	g.keys=1
	g.hp=3
	g.player=g.center(finale)
	g.interact()
	verify(g.keys==0 and g.hp==3 and g.gates[finale].open,"showdown lock spends a key and no HP")
func step_toward(g, tile: Vector2i) -> void:
	var field=g.build_nav(tile)
	var here=g.tile_at(g.player)
	if not field.has(here): return
	var next=g.center(here)
	var best=int(field[here])
	for d in g.DIRS:
		var n=here+d
		if field.has(n) and int(field[n])<best:
			best=int(field[n])
			next=g.center(n)
	var delta=next-g.player
	if delta.length()>1.0:
		g.facing=delta.normalized()
		# The scripted walker presses the cardinal it walks, so the directional cannon follows it.
		g.shot_dir=Vector2(signf(delta.x),0) if absf(delta.x)>=absf(delta.y) else Vector2(0,signf(delta.y))
		g.player=g.move_actor(g.player,g.facing*g.move_speed()/60.0)
func stroll(g, stage: int, seconds: float) -> Dictionary:
	g.level=stage
	g.load_round()
	g.state="play"
	g.invincible=0.4
	var eaten0=g.eaten
	var kills0=g.kills
	for i in int(seconds*60.0):
		if g.state!="play": break
		var field=g.build_nav(g.tile_at(g.player))
		var goal=null
		var best=99999
		for t in g.snacks.keys():
			if g.snacks[t] in ["d","p"] and field.has(t) and int(field[t])<best:
				best=int(field[t])
				goal=t
		if goal!=null: step_toward(g,goal)
		# Like a player turning to shoot: tap toward a visible foe's main axis.
		var foe=g.nearest_enemy(g.player,170)
		if foe!=null:
			var to=foe.p-g.player
			g.shot_dir=Vector2(signf(to.x),0) if absf(to.x)>=absf(to.y) else Vector2(0,signf(to.y))
		g.update_game(1.0/60.0)
	var opened=0
	for t in g.chests:
		if g.chests[t].open: opened+=1
	return {"stage":stage+1,"hp":g.hp,"coins":g.coins,"eaten":g.eaten-eaten0,"kills":g.kills-kills0,"opened":opened,"state":g.state,"left":g.remaining()}
func audit_play(g) -> void:
	verify(not Input.is_physical_key_pressed(KEY_Z),"aim key is released before the stroll")
	g.new_run()
	g.starter_draft=false
	var first=stroll(g,0,7.0)
	print("SIM ",first)
	verify(int(first.eaten)>=1,"scripted stage 1 eats")
	verify(int(first.kills)>=1 and int(first.coins)>=8,"scripted stage 1 earns a tin")
	verify(first.state=="play" and int(first.hp)>0,"scripted stage 1 survives the opening")
	var tin=null
	var tin_cost=999
	for t in g.chests:
		if g.chests[t].open: continue
		var cost=g.chest_cost(int(g.chests[t].tier))
		if int(g.coins)>=cost and cost<tin_cost:
			tin_cost=cost
			tin=t
	if tin!=null and g.state=="play":
		for i in 360:
			if g.player.distance_to(g.center(tin))<12: break
			step_toward(g,tin)
			g.update_game(1.0/60.0)
			if g.state!="play": break
		if g.player.distance_to(g.center(tin))<14: g.interact()
	var bought=0
	for t in g.chests:
		if g.chests[t].open: bought+=1
	print("SIM BUY coins=",g.coins," opened=",bought," hp=",g.hp)
	verify(bought>=1,"scripted stage 1 spends its first coins on a chest")
	for stage in [1,6,8,9]:
		g.new_run()
		g.starter_draft=false
		var report=stroll(g,stage,3.5)
		print("SIM ",report)
		verify(report.state=="play" or report.state=="over","scripted stage "+str(stage+1)+" ran")


func audit_facing(g) -> void:
	fresh(g)
	g.player=Vector2(80,40)
	for pair in [[KEY_A,Vector2.LEFT],[KEY_D,Vector2.RIGHT],[KEY_W,Vector2.UP],[KEY_S,Vector2.DOWN]]:
		var press=InputEventKey.new()
		press.keycode=pair[0];press.physical_keycode=pair[0];press.pressed=true
		Input.parse_input_event(press)
		var aim=InputEventKey.new()
		aim.keycode=KEY_Z;aim.physical_keycode=KEY_Z;aim.pressed=true
		Input.parse_input_event(aim);Input.flush_buffered_events()
		g.attack_cd=0;g.shots.clear()
		var old=g.player
		g.update_game(0.01)
		verify(g.facing.is_equal_approx(pair[1]),"movement preserves intended facing "+str(pair[1]))
		verify((g.player-old).dot(pair[1])>0,"input moves in intended direction "+str(pair[1]))
		verify(g.shots.size()>0 and g.shots[0].v.normalized().is_equal_approx(pair[1]),"Z aims cannon in movement direction "+str(pair[1]))
		press=press.duplicate();aim=aim.duplicate();press.pressed=false;aim.pressed=false
		Input.parse_input_event(press);Input.parse_input_event(aim);Input.flush_buffered_events()

func game_aim_once(cab) -> bool:
	# F toggles shake, so a doubled delivery would flip it back.
	var shake=cab.game.shake_enabled
	for code in [KEY_A,KEY_F]:
		var event=InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=true
		root.push_input(event)
	return cab.game.shot_dir==Vector2.LEFT and cab.game.shake_enabled!=shake

func aim_key(g, code: Key, pressed:=true, echo:=false) -> void:
	var event=InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.echo=echo
	g._unhandled_input(event)

func hold_z(down: bool) -> void:
	var event=InputEventKey.new()
	event.keycode=KEY_Z; event.physical_keycode=KEY_Z; event.pressed=down
	Input.parse_input_event(event); Input.flush_buffered_events()

func shot_heading(g) -> Vector2:
	g.attack_cd=0; g.shots.clear()
	g.update_game(0.01)
	if g.shots.is_empty(): return Vector2.ZERO
	return g.shots[0].v.normalized()

func audit_aiming(g) -> void:
	fresh(g)
	verify(g.shot_dir==Vector2.RIGHT,"cannon starts aimed right")
	g.player=Vector2(80,40)
	for pair in [[KEY_W,Vector2.UP],[KEY_A,Vector2.LEFT],[KEY_S,Vector2.DOWN],[KEY_D,Vector2.RIGHT],[KEY_UP,Vector2.UP],[KEY_LEFT,Vector2.LEFT],[KEY_DOWN,Vector2.DOWN],[KEY_RIGHT,Vector2.RIGHT]]:
		aim_key(g,pair[0]); aim_key(g,pair[0],false)
		g.player=Vector2(80,40)
		verify(shot_heading(g).is_equal_approx(pair[1]),"released key "+OS.get_keycode_string(pair[0])+" keeps firing "+str(pair[1])+" with no enemies")
	aim_key(g,KEY_A); aim_key(g,KEY_A,false)
	var spot=g.player
	verify(shot_heading(g).is_equal_approx(Vector2.LEFT) and shot_heading(g).is_equal_approx(Vector2.LEFT) and g.player==spot,"standing still keeps auto-firing the last direction")
	var foe=dummy(g,g.player,99)
	foe.stun=999
	g.enemies=[foe]
	for t in g.snacks.keys()+g.chests.keys()+[Vector2i(3,3),Vector2i(5,5),Vector2i(8,4),Vector2i(10,6)]:
		var at=g.center(t)
		if g.solid(g.tile_at(at)) or g.solid(g.tile_at(at+Vector2(20,14))) or not g.clear_line(at,at+Vector2(20,14)): continue
		g.player=at; foe.p=at+Vector2(20,14); break
	verify(g.nearest_enemy(g.player,170)==foe,"off-axis target is visible")
	aim_key(g,KEY_W); aim_key(g,KEY_W,false)
	verify(shot_heading(g).is_equal_approx(Vector2.UP),"baseline cannon ignores an off-axis target")
	aim_key(g,KEY_D); aim_key(g,KEY_S)
	verify(g.shot_dir==Vector2.DOWN,"overlapping keys: newest keydown wins")
	aim_key(g,KEY_S,false)
	verify(g.shot_dir==Vector2.DOWN,"releasing the newest key keeps its direction")
	aim_key(g,KEY_D,true,true)
	verify(g.shot_dir==Vector2.DOWN,"key-repeat echo does not steal aim")
	aim_key(g,KEY_D,false)
	g.state="choice"; aim_key(g,KEY_W); aim_key(g,KEY_W,false); g.state="play"
	verify(g.shot_dir==Vector2.DOWN,"menu navigation does not re-aim the cannon")
	g.perk_bonuses["splash"]=2
	verify(not g.smart_sauce() and shot_heading(g).is_equal_approx(Vector2.DOWN),"stage bonus splash does not unlock auto-aim")
	g.perk_bonuses.erase("splash")
	g.ranks["splash"]=1
	var toward=(foe.p-g.player).normalized()
	verify(g.smart_sauce() and shot_heading(g).dot(toward)>0.999,"Smart Sauce auto-aims at a visible foe")
	hold_z(true)
	verify(shot_heading(g).is_equal_approx(Vector2.DOWN),"holding Z overrides Smart Sauce")
	g.olive_ready=true
	var olive=shot_heading(g)
	verify(not g.olive_ready and olive.is_equal_approx(Vector2.DOWN) and g.shots[0].get("olive",false),"Z with Smart Sauce still fires the olive by hand")
	hold_z(false)
	g.enemies=[dummy(g,g.player+Vector2(0,400),99)]
	verify(shot_heading(g).is_equal_approx(Vector2.DOWN),"Smart Sauce falls back to the last pressed direction")
	g.enemies.clear()
	g.new_run()
	verify(g.shot_dir==Vector2.RIGHT and g.facing==Vector2.RIGHT,"new run resets the cannon direction")

func open_room(g, wall:=Vector2i(-1,-1)) -> void:
	g.board=[]
	for y in 13:
		var row=""
		for x in 19: row+="#" if x==0 or y==0 or x==18 or y==12 or Vector2i(x,y)==wall else "."
		g.board.append(row)
	g.snacks.clear(); g.gates.clear(); g.chests.clear(); g.enemies.clear(); g.shots.clear()

func shot_hurts(g, at: Vector2, offset: Vector2, v:=Vector2.ZERO, dt:=0.001) -> bool:
	g.player=at; g.invincible=0; g.shields=0; g.hp=3; g.state="play"
	g.shots=[{"p":at+offset,"v":v,"life":1.0,"hostile":true,"damage":1,"pierce":0,"bounce":0,"hit":[]}]
	g.update_shots(dt)
	return g.hp<3

func shot_hits(g, e: Dictionary, offset: Vector2, v:=Vector2.ZERO, dt:=0.001) -> bool:
	e.hp=5; g.enemies=[e]
	g.shots=[{"p":e.p+offset,"v":v,"life":1.0,"hostile":false,"damage":1,"pierce":0,"bounce":0,"hit":[]}]
	g.update_shots(dt)
	return int(e.hp)<5

func wrap_lines(text: String, width:=28) -> int:
	var lines=0; var line=""
	for word in text.split(" "):
		if (line+word).length()>width: lines+=1; line=""
		line+=word+" "
	return lines+(1 if line!="" else 0)

func audit_contacts(g) -> void:
	fresh(g); open_room(g)
	var at=Vector2(150,110)
	# Hero sprite covers x -7.5..7.5, y -12..8 around player; the hurt capsule forgives a 2px graze.
	verify(shot_hurts(g,at,Vector2(0,-9)),"a bullet in the hero's head hurts")
	verify(shot_hurts(g,at,Vector2(0,-11)) and not shot_hurts(g,at,Vector2(0,-12)),"head boundary: deep hit hurts, top graze is forgiven")
	verify(shot_hurts(g,at,Vector2(6.5,-2)) and not shot_hurts(g,at,Vector2(7.5,-2)),"side boundary: overlap hurts, edge graze is forgiven")
	verify(shot_hurts(g,at,Vector2(0,7)) and not shot_hurts(g,at,Vector2(0,8)),"feet boundary: overlap hurts, under-foot near miss is forgiven")
	verify(shot_hurts(g,at,Vector2(-40,-2),Vector2(4000,0),0.02),"a fast bullet cannot skip through the hero")
	verify(not shot_hurts(g,at,Vector2(-40,9),Vector2(4000,0),0.02),"a fast bullet passing under the feet misses")
	var foe=dummy(g,Vector2(150,60),5); foe.stun=99
	# Enemy blob is drawn 14x14 around its center; a 3px shot touches at 8.5px.
	verify(shot_hits(g,foe,Vector2(8,0)) and not shot_hits(g,foe,Vector2(9,0)),"enemy side boundary matches the drawn blob")
	verify(shot_hits(g,foe,Vector2(0,-8)) and not shot_hits(g,foe,Vector2(0,9)),"enemy top/bottom boundary matches the drawn blob")
	verify(shot_hits(g,foe,Vector2(-40,0),Vector2(4000,0),0.02),"a fast cannon shot cannot skip an enemy")
	verify(not shot_hits(g,foe,Vector2(-40,10),Vector2(4000,0),0.02),"a fast near-miss shot does not hit")
	g.player=at
	var probe=dummy(g,at,5)
	for pair in [[Vector2(0,-16),true],[Vector2(0,-18.5),false],[Vector2(12,-2),true],[Vector2(13,-2),false],[Vector2(0,12.5),true],[Vector2(0,13.5),false]]:
		probe.p=at+pair[0]
		verify(g.hero_touch(probe)==pair[1],"enemy body at "+str(pair[0])+(" touches" if pair[1] else " does not touch")+" the hero")
	g.enemies=[dummy(g,at+Vector2(0,-16),5)]; g.enemies[0].stun=99
	g.invincible=0; g.shields=0; g.hp=3; g.state="play"; g.update_game(0.001)
	verify(g.hp==2,"an enemy overlapping the hero's head hurts in play")
	open_room(g); var t=Vector2i(5,5); g.snacks[t]="d"; g.player=g.center(t)+Vector2(9,0); g.try_collect()
	verify(not g.snacks.has(t),"food pickup stays generous")
	g.snacks[t]="d"; g.player=g.center(t)+Vector2(11,0); g.try_collect()
	verify(g.snacks.has(t),"food pickup keeps its old reach")

func audit_orbiters(g) -> void:
	fresh(g); open_room(g); g.player=Vector2(150,110); g.elapsed=0
	for count in [1,6,8,12]:
		g.ranks["orbit"]=count
		var list=g.orbiters(); var even=true
		for i in list.size():
			if absf(list[i].p.distance_to(g.hero_center())-g.ORBIT_REACH)>0.01 or not list[i].clear: even=false
			if count>1 and absf(list[i].p.distance_to(list[(i+1)%count].p)-2*g.ORBIT_REACH*sin(PI/count))>0.01: even=false
		verify(list.size()==count and even,"rank "+str(count)+" draws and swings "+str(count)+" evenly spaced donuts")
	g.ranks["orbit"]=12
	var foes=[]
	for o in g.orbiters():
		var foe=dummy(g,o.p,5); foe.stun=99; foes.append(foe)
	g.enemies=foes.duplicate(); g.bonk_orbiters()
	var bonked=0
	for foe in foes: if int(foe.hp)<5: bonked+=1
	verify(bonked==12,"all twelve visible donuts can bonk")
	g.ranks["orbit"]=1
	# Wall tile (9,6) covers x 144..160, y 96..112. The donut center is clear but the foe is around the corner.
	open_room(g,Vector2i(9,6)); g.player=Vector2(122,110); g.elapsed=0
	var o=g.orbiters()[0]
	var corner=dummy(g,Vector2(149,115),5); corner.stun=99; g.enemies=[corner]
	verify(o.clear and o.p.is_equal_approx(Vector2(142,108)) and g.body_hit(corner,o.p,g.DONUT_R),"corner fixture: donut is visible and in reach")
	g.bonk_orbiters()
	verify(corner.hp==5,"a donut cannot bonk around a wall corner")
	open_room(g); corner.tick=0; g.enemies=[corner]; g.bonk_orbiters()
	verify(corner.hp<5,"the same donut bonks once the corner is gone")
	open_room(g,Vector2i(9,6)); g.player=Vector2(126,106); g.elapsed=0
	o=g.orbiters()[0]
	var near=dummy(g,Vector2(138,104),5); near.stun=99; g.enemies=[near]
	verify(g.orbiters().size()==1 and not o.clear,"a donut inside a wall is still listed for the dim draw")
	g.bonk_orbiters()
	verify(near.hp==5,"a walled donut does no damage")

func audit_movement_perks(g) -> void:
	fresh(g)
	verify(g.Items.ITEMS.size()==50,"movement perks keep 50 chest items")
	var rink=g.Perks.definition("rink"); var bounce=g.Perks.definition("bounce")
	verify(rink.size()==5 and bounce.size()==5,"roller rink and bounce house are drafts")
	var tabs={}
	for p in g.Perks.ITEMS:
		tabs[str(p[1]).split(" ")[0].left(9)]=true
		verify(wrap_lines(p[1])<=2 and wrap_lines(p[2])<=3 and wrap_lines(p[3])<=3,"perk card fits: "+str(p[0]))
	verify(tabs.size()==g.Perks.ITEMS.size(),"perk tabs have distinct short names")
	var base=g.move_speed()
	verify(g.oil_scale()<1.0,"oil slows without the rink")
	g.choices=[rink]; g.take_perk(0); g.state="play"
	verify(int(g.draft_ranks.get("rink",0))==1 and is_equal_approx(g.oil_scale(),1.0),"roller rink grants oil immunity")
	g.glide_time=0
	verify(is_equal_approx(g.move_speed(),base),"rink adds nothing from a standstill")
	g.glide_time=0.5
	verify(is_equal_approx(g.move_speed(),base*1.05),"rink speed builds while moving")
	g.glide_time=9
	verify(is_equal_approx(g.move_speed(),base*1.1),"one rink pick caps at +10% after 1s")
	g.update_game(0.01)
	verify(g.glide_time==0,"stopping resets the rink build-up")
	var hold=InputEventKey.new(); hold.keycode=KEY_D; hold.physical_keycode=KEY_D; hold.pressed=true
	Input.parse_input_event(hold); Input.flush_buffered_events()
	g.update_game(0.25); g.update_game(0.25)
	verify(absf(g.glide_time-0.5)<0.001,"nonstop moving builds rink time")
	open_room(g); g.player=Vector2(283,110); g.glide_time=0.7
	g.update_game(0.1)
	verify(is_equal_approx(g.player.x,283.0) and g.glide_time==0,"pushing into a wall does not build rink speed")
	var belt=""
	for x in 19: belt+="#" if x in [0,18] else "=" if x==17 else "."
	g.board[6]=belt; g.player=Vector2(283,104); g.elapsed=0.47; g.glide_time=0.7
	g.update_game(0.1)
	verify(g.player.y<104 and g.glide_time==0,"a conveyor carrying a wall-pinned hero does not count as moving")
	open_room(g); g.player=Vector2(150,110); g.glide_time=0.7
	var guard=dummy(g,g.player+Vector2(14,-2),9); guard.kind=5; guard.stun=99; g.enemies=[guard]
	g.update_game(0.1)
	verify(is_equal_approx(g.player.x,150.0) and g.glide_time==0,"a guard that blocks the step resets rink speed")
	open_room(g); g.player=Vector2(150,110); g.glide_time=0
	g.update_game(0.1)
	verify(g.player.x>150 and absf(g.glide_time-0.1)<0.001,"free steps still build rink speed")
	hold=hold.duplicate(); hold.pressed=false; Input.parse_input_event(hold); Input.flush_buffered_events()
	g.draft_ranks["rink"]=3; g.glide_time=9
	verify(is_equal_approx(g.move_speed(),base*1.3),"three rink picks stack to +30%")
	g.draft_ranks["rink"]=7
	verify(is_equal_approx(g.move_speed(),base*1.3),"rink math caps at three picks")
	for i in 20:
		for p in g.Perks.candidates({"rink":3,"bounce":3}): verify(p[0]!="rink" and p[0]!="bounce","maxed movement perks leave the draft")
	g.ranks["speed"]=12; g.pizza_time=5
	verify(g.move_speed()<=240.0,"rink respects the speed cap")
	fresh(g)
	var wait=g.flop_delay()
	g.choices=[bounce]; g.take_perk(0); g.state="play"
	verify(int(g.perk_bonuses.get("pizza",0))==1 and is_equal_approx(g.flop_delay(),wait-0.25),"bounce house grants pizza turbo and a faster flop")
	g.choices=[bounce]; g.take_perk(0); g.state="play"
	g.pizza_time=0; g.flop_cd=0; g.belly_flop()
	verify(int(g.perk_bonuses.get("pizza",0))==2 and is_equal_approx(g.pizza_time,1.0) and is_equal_approx(g.flop_cd,wait-0.5),"two bounce picks stack burst and cooldown")
	var burst=g.move_speed(); g.pizza_time=0
	verify(burst>g.move_speed(),"the flop burst is a real speed boost")
	g.pizza_time=3; g.belly_flop()
	verify(is_equal_approx(g.pizza_time,3.0),"a flop never shortens a longer pizza burst")
	g.draft_ranks["bounce"]=9
	verify(is_equal_approx(g.flop_delay(),wait-0.75),"bounce math caps at three picks")
	g.ranks["dash"]=12
	verify(is_equal_approx(g.flop_delay(),0.32),"flop wait keeps its floor")
	fresh(g)

# Called after the economy pass is integrated. Compare purchasing power, not raw price.
func audit_price_progression(g) -> void:
	var previous=[0.0,0.0,0.0]
	for stage in 10:
		fresh(g);g.level=stage;g.coins=0
		g.damage_enemy(dummy(g,Vector2(120,40),1),5)
		var income=maxi(1,g.coins)
		for tier in 3:
			var effort=float(g.chest_cost(tier))/income
			verify(effort>previous[tier],"stage "+str(stage+1)+" tier "+str(tier)+" needs more kill income")
			previous[tier]=effort

func audit_new_interactions(g) -> void:
	fresh(g);g.ranks["combo"]=2;g.combo=3;g.combo_time=1
	verify(g.streak_bonus()==2,"combo meal empowers the cannon while a streak lasts")
	g.combo_time=0;verify(g.streak_bonus()==0,"streak damage expires")
	fresh(g);g.player=Vector2(100,40);g.ranks["magnet"]=2
	g.enemies=[dummy(g,Vector2(150,40),10)];g.slurp_crumb()
	verify(g.shots.size()==1 and g.shots[0].damage==2 and g.shots[0].v.x>0,"vacuum spits a rank-scaled aimed crumb")
	fresh(g);g.player=Vector2(100,40);g.ranks["oil"]=2
	var foe=dummy(g,Vector2(116,40),20);g.enemies=[foe];g.grease(30)
	verify(foe.p.x>116 and foe.slow>=2,"nonstick flop pushes and slows")
	fresh(g);g.player=Vector2(100,40);g.ranks["munch"]=1
	foe=dummy(g,Vector2(120,40),20);g.enemies=[foe];g.chomp()
	verify(foe.hp==18 and foe.stun>=0.4,"chomp bites harder and briefly dazes")
	fresh(g);g.player=Vector2(100,40);g.ranks["gourmet"]=1
	var victim=dummy(g,Vector2(120,40),1);foe=dummy(g,Vector2(140,40),10)
	g.enemies=[victim,foe];g.damage_enemy(victim,5,true)
	verify(foe.hp==8,"trap gourmet splashes a neighboring enemy")
	fresh(g);g.ranks["leech"]=1;g.shields=0;g.elapsed=0
	var early_coins=g.coins;var early_score=g.score
	foe=dummy(g,Vector2(120,40),1);foe["reinforcement"]=true;g.damage_enemy(foe,5)
	early_coins=g.coins-early_coins;early_score=g.score-early_score
	var early_meter=g.leech_meter
	g.elapsed=g.THREAT_STEP*4;g.coins=0;g.score=0;g.leech_meter=0
	foe=dummy(g,Vector2(120,40),1);foe["reinforcement"]=true;g.damage_enemy(foe,5)
	verify(g.coins<early_coins and g.score<early_score,"late reinforcements lose both coin and score value")
	verify(g.leech_meter<early_meter,"late reinforcement kills grant less insurance credit")
	g.coins=0;g.damage_enemy(dummy(g,Vector2(120,40),1),5)
	verify(g.coins==8,"authored enemies retain full bounty at late threat")
	g.elapsed=0;var quick=g.quick_exit_bonus()
	g.elapsed=g.THREAT_STEP*4
	verify(quick>g.quick_exit_bonus() and g.quick_exit_bonus()==0,"quick exit bonus fades without forcing an exit")
	g.level=1;g.load_round()
	verify(g.threat_tier()==1 and g.threat_next()==g.THREAT_STEP,"new stages reset local threat")

func audit_vaults(g) -> void:
	for mode in 4:
		fresh(g);g.gates.clear();g.chests.clear();g.snacks.clear();g.enemies.clear()
		var door=Vector2i(2,1)
		g.gates[door]={"open":false,"mode":mode,"charge":0.0}
		g.player=g.center(door);g.keys=1;g.coins=0
		g.interact()
		var expected=30 if mode==3 else g.chest_cost(0)*2
		verify(g.gates[door].open and g.coins==expected,"door mode "+str(mode)+" pays its advertised vault once")
		g.interact()
		verify(g.coins==expected,"reusing open door cannot farm coins")
	fresh(g);g.gates.clear();g.chests.clear();g.keys=0;g.coins=0
	var door=Vector2i(2,1)
	g.gates[door]={"open":false,"mode":0,"charge":0.0};g.player=g.center(door)
	g.interact()
	verify(not g.gates[door].open and g.coins==0,"failed unlock never pays vault bonus")

	for stage in 10:
		for tier in 3:
			fresh(g);g.level=stage;g.chests.clear();g.gates.clear();g.notice_time=0
			var chest=Vector2i(2,1)
			g.chests[chest]={"open":false,"tier":tier};g.player=g.center(chest)
			var prompt=g.prompt_line()
			verify(prompt.contains("BASE KILLS") and g.FONT.get_string_size(prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x<=248,"chest estimate fits native width and identifies base bounty")
