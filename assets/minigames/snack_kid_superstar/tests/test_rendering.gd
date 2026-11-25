extends SceneTree
# Requires a real renderer (omit --headless). Validates actual pixels, not only settings.
var checks=0
var failures=0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL ",message)
func surface(size: Vector2i) -> SubViewport:
	var v=SubViewport.new()
	v.size=size;v.disable_3d=true;v.transparent_bg=false
	v.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	v.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(v)
	return v
func find_surface(node: Node) -> SubViewport:
	for child in node.get_children():
		if child is SubViewport: return child
		var result=find_surface(child)
		if result!=null: return result
	return null
func frames() -> void:
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Run test_rendering.gd with a real renderer, without --headless.");quit(2);return
	var host=surface(Vector2i(480,270))
	var cab=load((get_script().resource_path.get_base_dir()+"/../scenes/Cabinet_Demo.tscn").simplify_path()).instantiate()
	cab.center_in(Vector2i(480,270));host.add_child(cab)
	var g=cab.game
	g.save_enabled=false;g.audio.muted=true;g.set_process(false)
	var native=find_surface(cab)
	verify(native!=null,"cabinet owns a native render target")
	if native==null: cab.queue_free();host.queue_free();quit(1);return
	verify(native.snap_2d_transforms_to_pixel,"cabinet snaps transforms to native pixels")
	verify(native.snap_2d_vertices_to_pixel,"cabinet snaps vertices to native pixels")
	verify(native.canvas_item_default_texture_filter==Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,"cabinet uses nearest filtering")
	verify(native.size==Vector2i(256,224),"cabinet surface stays 256x224 inside 480x270")
	verify(native.msaa_2d==Viewport.MSAA_DISABLED,"no multisample smoothing")
	g.new_run();g.starter_draft=false;g.level=9;g.load_round();g.start_boss();g.state="play"
	g.player=Vector2(152,140);g.shields=1;g.invincible=0
	g.boss.action="rain_warn";g.boss.timer=0.5
	g.boss.marks=[{"p":Vector2(130.4,120.7)},{"p":Vector2(170.2,145.6)}]
	g.add_zone(Vector2(100.4,130.7),31.3,1,2,g.GREEN)
	g.effects=[{"p":Vector2(155.2,125.6),"life":0.2,"radius":34,"color":g.GOLD,"text":""}]
	g.queue_redraw()
	var enlarged=surface(Vector2i(768,672))
	var display=Sprite2D.new();display.texture=native.get_texture();display.centered=false
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;display.scale=Vector2(3,3);enlarged.add_child(display)
	var preview=Sprite2D.new();preview.texture=native.get_texture();preview.centered=false;preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;root.add_child(preview)
	await frames()
	var original=native.get_texture().get_image()
	var embedded=host.get_texture().get_image()
	var large=enlarged.get_texture().get_image()
	var mismatched_host=0;var mismatched_large=0
	for y in 224:
		for x in 256:
			var color=original.get_pixel(x,y)
			if embedded.get_pixel(x+112,y+23)!=color: mismatched_host+=1
			for dy in 3:
				for dx in 3:
					if large.get_pixel(x*3+dx,y*3+dy)!=color: mismatched_large+=1
	verify(mismatched_host==0,"all 57344 cabinet pixels match 1:1 inside the main-game-sized frame")
	verify(mismatched_large==0,"all 516096 enlarged pixels form exact nearest-neighbor 3x3 blocks")
	verify(root.get_texture().get_size()==Vector2(480,270),"main-game window retains its 480x270 grid")
	verify(cab.plate.get_viewport()==native,"result overlay uses the same native pixel grid")
	cab.scale=Vector2(1.5,1.5);cab.position=Vector2(13.4,7.6);cab.rotation=0.1
	var camera=Camera2D.new();camera.zoom=Vector2(1.7,1.7);host.add_child(camera)
	await frames()
	var transformed=host.get_texture().get_image();var camera_mismatches=0
	for y in 224:
		for x in 256:
			if transformed.get_pixel(x+112,y+23)!=original.get_pixel(x,y): camera_mismatches+=1
	verify(camera_mismatches==0,"host camera and parent transforms cannot distort cabinet pixels")
	# Route key events through the containing viewport, as a host would.
	g.state="play"
	var key=InputEventKey.new();key.keycode=KEY_P;key.physical_keycode=KEY_P;key.pressed=true
	host.push_input(key);await process_frame
	verify(g.state=="pause","host pause input arrives exactly once")
	var release=key.duplicate();release.pressed=false;host.push_input(release)
	host.push_input(key.duplicate());await process_frame
	verify(g.state=="play","host resume input arrives exactly once")
	if "--capture" in OS.get_cmdline_user_args():
		original.save_png(get_script().resource_path.get_base_dir()+"/.render-native.png")
		embedded.save_png(get_script().resource_path.get_base_dir()+"/.render-host.png")
		large.save_png(get_script().resource_path.get_base_dir()+"/.render-3x.png")
	print("RENDER CHECKS ",checks," FAILED ",failures,"; host mismatches=",mismatched_host,"; scaled mismatches=",mismatched_large)
	g.shutdown();preview.queue_free();enlarged.queue_free();host.queue_free()
	await process_frame;await process_frame;quit(1 if failures else 0)
