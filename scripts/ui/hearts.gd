@tool
extends Node2D
signal layout_changed

@export var player_path: NodePath
@export_range(0, 8) var heart_gap: int = 2:
	set(next):
		heart_gap = next
		_refresh_art_layout()
@export_range(8, 24) var row_height: int = 16:
	set(next):
		row_height = next
		_refresh_art_layout()
@export_range(1, 12) var preview_hearts: int = 2:
	set(next):
		preview_hearts = next
		if is_node_ready():
			_update_hearts()
var _last_hp: int = -1
var _last_max_hp: int = -1

@onready var _template: Sprite2D = $Heart_1

var player: Node
var _hearts: Array[Sprite2D] = []
var _base_position: Vector2 = Vector2.ZERO
var _pitch: int = 0

func _ready() -> void:
	_measure_heart_art()
	player = get_node_or_null(player_path) if not player_path.is_empty() and not Engine.is_editor_hint() else null
	_update_hearts()

func _process(_delta: float) -> void:
	_update_hearts()

# Lays the row out by the visible pixels shared by the full (0) and empty (1) frames,
# so frame padding never offsets the row and taking damage never shifts it.
func _measure_heart_art() -> void:
	var sheet: Image = _template.texture.get_image()
	var frame_size := Vector2i(_template.texture.get_size() / Vector2(_template.hframes, _template.vframes))
	var art := Rect2i()
	for frame: int in [0, 1]:
		var cell := Rect2i(Vector2i(frame * frame_size.x, 0), frame_size)
		var used := sheet.get_region(cell).get_used_rect()
		art = used if frame == 0 else art.merge(used)
	_pitch = art.size.x + heart_gap
	_base_position = Vector2(-art.position.x, floori((row_height - art.size.y) / 2.0) - art.position.y)

func _update_hearts() -> void:
	if not Engine.is_editor_hint() and not is_instance_valid(player):
		return
	var hp: int = preview_hearts if Engine.is_editor_hint() else player.hp
	var max_hp: int = preview_hearts if Engine.is_editor_hint() else player.max_hp
	if hp == _last_hp and max_hp == _last_max_hp:
		return
	_last_hp = hp
	_last_max_hp = max_hp

	_rebuild_hearts(max_hp)
	layout_changed.emit()

	for i in _hearts.size():
		_hearts[i].position = _base_position + Vector2(_pitch * i, 0)
		_hearts[i].frame = 0 if hp > i else 1

# One heart sprite per point of max HP, so extra max HP upgrades need no scene edits.
func _rebuild_hearts(count: int) -> void:
	if _hearts.size() == count:
		return

	while _hearts.size() > count:
		var extra: Sprite2D = _hearts.pop_back()
		if extra == _template:
			extra.visible = false
		else:
			extra.queue_free()

	while _hearts.size() < count:
		var slot: int = _hearts.size()
		var heart: Sprite2D = _template
		if slot > 0:
			heart = _template.duplicate() as Sprite2D
			heart.name = "Heart_%d" % (slot + 1)
			add_child(heart)
		heart.position = _base_position + Vector2(_pitch * slot, 0.0)
		heart.visible = true
		_hearts.append(heart)


func bind_player(next: Node) -> void:
	player = next
	_last_hp = -1
	_last_max_hp = -1
	if is_node_ready():
		_update_hearts()


func get_content_rect() -> Rect2:
	return Rect2(position, Vector2(maxi(0, _pitch * _hearts.size() - heart_gap), row_height))

func _refresh_art_layout() -> void:
	if is_node_ready():
		_measure_heart_art()
		_last_hp = -1
		_update_hearts()
