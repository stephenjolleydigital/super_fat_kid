extends SceneTree
# Repeatable input/render inspection. This is a controlled fixture, not a campaign.
var game
var age=0.0
var last_direction=Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load((get_script().resource_path.get_base_dir()+"/../scenes/Snack_Kid_Superstar.tscn").simplify_path()).instantiate()
	root.add_child(game);game.save_enabled=false;game.audio.muted=true
	game.new_run();game.starter_draft=false;game.state="play"
	game.player=Vector2(120,40);game.enemies.clear();game.snacks.clear();game.spawn_cd=999
	game.set_process(false)
func _process(dt: float) -> bool:
	if game==null: return false
	age+=dt
	var direction=Vector2.RIGHT if fmod(age,4.0)<2.0 else Vector2.LEFT
	for pair in [[KEY_A,Vector2.LEFT],[KEY_D,Vector2.RIGHT],[KEY_Z,Vector2.ZERO]]:
		var event=InputEventKey.new()
		event.keycode=pair[0];event.physical_keycode=pair[0]
		event.pressed=pair[1]==direction or pair[0]==KEY_Z
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	game._process(minf(dt,0.05))
	game.notice=("RIGHT + Z" if direction.x>0 else "LEFT + Z")+" / INPUT FIXTURE"
	game.notice_time=1
	if direction!=last_direction:
		print("FACING ",direction," aim ",game.facing)
		last_direction=direction
	if age>60:
		game.shutdown();quit()
	return false
