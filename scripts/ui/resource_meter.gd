@tool
extends Control
## Pixel resource bar. Layout/colors are Inspector-editable; points never rescale.
const MovementResource = preload("res://scripts/player/player_resource.gd")
const STAMINA_GREEN := Color8(156, 203, 94)
const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const EMPTY_SOUNDS = [
	preload("res://assets/audio/sfx/ui/sfx_ui_gas_meter_empty_01.wav"),
	preload("res://assets/audio/sfx/ui/sfx_ui_gas_meter_empty_02.wav"),
]

@export_group("Layout")
@export_range(1, 3, 1) var pixels_per_point: int = 1:
	set(next):
		pixels_per_point = next
		_refresh_layout()
@export_range(2, 8, 1) var fill_height: int = 4:
	set(next):
		fill_height = next
		_refresh_layout()
@export var show_label: bool = false:
	set(next):
		show_label = next
		_refresh_layout()
@export var display_label: String = "GAS":
	set(next):
		display_label = next
		_refresh_layout()
@export_group("Palette")
@export var fill_color := Color("#5E7646"):
	set(next):
		fill_color = next
		queue_redraw()
@export var highlight_color := Color("#7E9862"):
	set(next):
		highlight_color = next
		queue_redraw()
@export var recovery_zone_color := Color("#3E4F31"):
	set(next):
		recovery_zone_color = next
		queue_redraw()
@export var background_color := Color("#2B2D42"):
	set(next):
		background_color = next
		queue_redraw()
@export var frame_color := Color("#000000"):
	set(next):
		frame_color = next
		queue_redraw()
@export var label_color := Color("#B2B2B2"):
	set(next):
		label_color = next
		queue_redraw()
@export var flash_color := Color("#F9C74F"):
	set(next):
		flash_color = next
		queue_redraw()
@export_group("Editor Preview")
@export_range(20, 200, 10) var preview_capacity: float = 50.0:
	set(next):
		preview_capacity = next
		_refresh_layout()
@export_range(0, 1, 0.05) var preview_fraction: float = 1.0:
	set(next):
		preview_fraction = next
		queue_redraw()

@export var preview_exhausted: bool = false:
	set(next):
		preview_exhausted = next
		queue_redraw()

var reveal_progress: float = 1.0
var transmutation_progress: float = 0.0

func set_transmutation_progress(progress: float) -> void:
	transmutation_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()

var resource: MovementResource
var flash_remaining: float = 0.0
var sound: AudioStreamPlayer
var next_empty_sound: int = 0

func set_reveal_progress(progress: float) -> void:
	reveal_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	if not Engine.is_editor_hint():
		sound = AudioStreamPlayer.new()
		sound.volume_db = -12.0
		add_child(sound)
	_refresh_layout()

func bind_resource(next: MovementResource) -> void:
	if resource != null:
		resource.resource_changed.disconnect(_on_resource_changed)
		resource.exhaustion_changed.disconnect(_on_exhaustion_changed)
		resource.enabled_changed.disconnect(_on_enabled_changed)
		resource.appearance_changed.disconnect(queue_redraw)
	resource = next
	reveal_progress = 1.0
	transmutation_progress = 0.0
	flash_remaining = 0.0
	set_process(false)
	if sound != null:
		sound.stop()
	if resource != null:
		resource.resource_changed.connect(_on_resource_changed)
		resource.exhaustion_changed.connect(_on_exhaustion_changed)
		resource.enabled_changed.connect(_on_enabled_changed)
		resource.appearance_changed.connect(queue_redraw)
	_refresh_layout()

func _process(delta: float) -> void:
	flash_remaining = maxf(0.0, flash_remaining - delta)
	queue_redraw()
	if flash_remaining <= 0.0:
		set_process(false)

func _on_resource_changed(_value: float, _capacity: float) -> void:
	_refresh_layout()

func _on_enabled_changed(_active: bool) -> void:
	_refresh_layout()

func _on_exhaustion_changed(active: bool) -> void:
	flash_remaining = 0.4 if active else 0.0
	set_process(active)
	if active and sound != null:
		sound.stream = EMPTY_SOUNDS[next_empty_sound]
		sound.play()
		next_empty_sound = (next_empty_sound + 1) % EMPTY_SOUNDS.size()
	queue_redraw()

func _label_width() -> float:
	return float(display_label.length() * 8 + 8) if show_label else 0.0

func _refresh_layout() -> void:
	var capacity: float = resource.capacity if resource != null else preview_capacity
	custom_minimum_size = Vector2(_label_width() + roundf(capacity * pixels_per_point) + 2, maxi(fill_height + 2, 12 if show_label else 0))
	# Allow both growth and shrink when a capacity is changed.
	size = custom_minimum_size
	if is_node_ready():
		visible = resource.enabled if resource != null else Engine.is_editor_hint()
	queue_redraw()

func _draw() -> void:
	if resource == null and not Engine.is_editor_hint():
		return
	if resource != null and not resource.enabled:
		return
	var capacity: float = resource.capacity if resource != null else preview_capacity
	var value: float = resource.value if resource != null else capacity * preview_fraction
	var exhausted: bool = resource.exhausted if resource != null else preview_exhausted
	var threshold: float = resource.resume_threshold if resource != null else 20.0
	var flashing: bool = flash_remaining > 0 and int((0.4 - flash_remaining) / 0.1) % 2 == 0
	var x: float = _label_width()
	var full_width: float = roundf(capacity * pixels_per_point)
	# Draw the frame and fill outward in whole pixels during the curse reveal.
	var reveal_width := roundf(full_width * reveal_progress)
	if reveal_width <= 0.0:
		return
	var width: float = clampf(roundf(value * pixels_per_point), 0, reveal_width)
	if show_label:
		draw_string(FONT, Vector2(0, 9), display_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, flash_color if flashing else label_color)
	draw_rect(Rect2(x, 0, reveal_width + 2, fill_height + 2), flash_color if flashing else frame_color)
	draw_rect(Rect2(x + 1, 1, reveal_width, fill_height), background_color)
	# Show the recovery target behind the normal fill only while exhausted.
	if exhausted:
		var recovery_width: float = clampf(roundf(threshold * pixels_per_point), 0, reveal_width)
		draw_rect(Rect2(x + 1, 1, recovery_width, fill_height), recovery_zone_color)
	if width > 0:
		var is_stamina: bool = resource != null and resource.stamina_phase
		draw_rect(Rect2(x + 1, 1, width, fill_height), STAMINA_GREEN if is_stamina else fill_color)
		draw_rect(Rect2(x + 1, 1, width, 1), STAMINA_GREEN if is_stamina else highlight_color)
		if is_stamina and transmutation_progress > 0.0:
			var converted := minf(width, roundf(full_width * transmutation_progress))
			draw_rect(Rect2(x + 1, 1, converted, fill_height), fill_color)
			draw_rect(Rect2(x + 1, 1, converted, 1), highlight_color)

	if reveal_progress < 1.0:
		draw_rect(Rect2(x + reveal_width, 0, 2, fill_height + 2), flash_color)
