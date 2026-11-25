extends "full_run_audit.gd"
# Controlled final-boss fixture. Its starting build is injected, not earned in a campaign.
func prepare_run() -> void:
	game.new_run();game.starter_draft=false
	var picks=["gatling","pinball","bodyguard","bulldozer","carousel","popcorn","candy","toxic","royalty","cashback"]
	if build=="scrappy": picks=["inspector","royalty","cashback","inspector","royalty","cashback","bulldozer","candy","fondue","toxic"]
	for id in picks:
		var perk=game.Perks.definition(id)
		game.draft_ranks[id]=int(game.draft_ranks.get(id,0))+1
		for bonus in perk[4]: game.perk_bonuses[bonus]=int(game.perk_bonuses.get(bonus,0))+int(perk[4][bonus])
		if id=="bodyguard": game.max_hp+=2;game.hp+=2
	game.ranks={"leech":1,"armor":1,"oil":1,"finish":1,"bonus":1,"lucky":1}
	game.level=9;game.load_round();game.state="play";game.start_boss()
func run() -> void:
	game=load((get_script().resource_path.get_base_dir()+"/../scenes/Snack_Kid_Superstar.tscn").simplify_path()).instantiate()
	root.add_child(game);game.set_process(false);game.save_enabled=false;game.audio.muted=true
	tour=DisplayServer.get_name()!="headless"
	hesitant="--hesitant" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--build="): build=arg.trim_prefix("--build=")
	print("CONTROLLED BOSS FIXTURE: injected ten-perk build, normal combat HP/damage after setup")
	await campaign("selective",19)
	game.shutdown();game.queue_free();await process_frame;await process_frame;quit()

func advance(dt: float) -> void:
	super.advance(dt)
	if tour and "--capture" in OS.get_cmdline_user_args() and game.run_time>8 and game.run_time<8.05:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(get_script().resource_path.get_base_dir()+"/.boss-live.png")
		print("LIVE CAPTURE at ",game.run_time)
