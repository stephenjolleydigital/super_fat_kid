extends Control
## Center-only, pixel-snapped announcement; play_intro() runs once per entry.

const PIXEL_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const FONT_SIZE: int = 16
const CREAM := Color8(253, 243, 207)
const BLACK := Color8(0, 0, 0)
const TEXT_PADDING: int = 4

@export_group("Timing")
@export_range(0.01, 2.0, 0.01, "suffix:s") var entrance_duration: float = 0.24
@export_range(0.0, 2.0, 0.01, "suffix:s") var center_hold_duration: float = 0.65
@export_range(0.01, 1.0, 0.01, "suffix:s") var exit_duration: float = 0.16
@export_group("Optional Sound")
## Optional user-supplied sting at the center join. Empty means silent.
@export var intro_sting: AudioStream

@onready var _title_window: Control = $TitleWindow
@onready var _animated_title: Control = $TitleWindow/AnimatedTitle
@onready var _level_word: Label = $TitleWindow/AnimatedTitle/LevelWord
@onready var _level_number: Label = $TitleWindow/AnimatedTitle/LevelNumber
@onready var _sting_player: AudioStreamPlayer = $OptionalIntroSting

var _font: FontFile
var _title_size: Vector2
var _center_origin: Vector2
var _prefix_width: float
var _configured: bool = false
var _played: bool = false
var _tween: Tween


func _ready() -> void:
	# Private rasterization settings leave the other UI untouched.
	_font = PIXEL_FONT.duplicate() as FontFile
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_font.generate_mipmaps = false
	_font.oversampling = 1.0
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = FONT_SIZE
	settings.font_color = CREAM
	settings.outline_size = 2
	settings.outline_color = BLACK
	settings.shadow_size = 0
	settings.shadow_color = Color.TRANSPARENT
	_level_word.label_settings = settings
	_level_number.label_settings = settings


func configure(world: int, level: int) -> void:
	if _played:
		return
	_level_number.text = "%d-%d" % [world, level]
	_configured = true
	_layout_labels()


func _layout_labels() -> void:
	_title_size = _font.get_string_size("LEVEL " + _level_number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).ceil()
	_prefix_width = roundf(_font.get_string_size("LEVEL ", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	_center_origin = ((get_viewport_rect().size - _title_size) * 0.5).round()
	_level_word.size = Vector2(_prefix_width, _title_size.y)
	_level_number.size = Vector2(_title_size.x - _prefix_width, _title_size.y)
	_set_exit_progress(0.0)


func play_intro() -> void:
	if not _configured or _played:
		return
	_played = true
	_layout_labels()
	show()
	_set_entrance_progress(0.0)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	_tween.tween_method(_set_entrance_progress, 0.0, 1.0, entrance_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_join_title)
	_tween.tween_interval(center_hold_duration)
	_tween.tween_method(_set_exit_progress, 0.0, 1.0, exit_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_hide_announcement)


func _set_entrance_progress(progress: float) -> void:
	var left_start := -_center_origin.x - _level_word.size.x - 4.0
	var right_start := get_viewport_rect().size.x - _center_origin.x + 4.0
	_level_word.position = Vector2(roundf(lerpf(left_start, 0.0, progress)), 0)
	_level_number.position = Vector2(roundf(lerpf(right_start, _prefix_width, progress)), 0)


func _join_title() -> void:
	_set_entrance_progress(1.0)
	if intro_sting:
		_sting_player.stream = intro_sting
		_sting_player.play()


func _set_exit_progress(progress: float) -> void:
	# Close a horizontal shutter around stationary text; never scale the glyphs.
	var full_height := int(_title_size.y) + TEXT_PADDING * 2
	var cut := roundi(float(full_height) * 0.5 * progress)
	_title_window.position = Vector2(0, _center_origin.y - TEXT_PADDING + cut)
	_title_window.size = Vector2(get_viewport_rect().size.x, maxi(0, full_height - cut * 2))
	_animated_title.position = Vector2(_center_origin.x, TEXT_PADDING - cut)
	_title_window.visible = cut * 2 < full_height


func _hide_announcement() -> void:
	hide()
	_title_window.hide()
