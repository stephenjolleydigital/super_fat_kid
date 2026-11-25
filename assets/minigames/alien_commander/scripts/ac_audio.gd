extends Node
class_name ACAudio

const POOL_SIZE := 8

const PITCH_SELECTION := Vector2(0.98, 1.02)
const PITCH_SHOOT := Vector2(0.95, 1.05)
const PITCH_HURT := Vector2(0.95, 1.05)
const PITCH_DEATH := Vector2(0.90, 1.10)
const PITCH_ERROR := Vector2(0.80, 0.90)

const _ALIEN_SELECT := preload("res://assets/minigames/alien_commander/audio/sfx/AC_Player_Alien_Select_01.wav")
const _ALIEN_SHOOT := [
	preload("res://assets/minigames/alien_commander/audio/sfx/AC_Player_Alien_Shoot_01.wav"),
	preload("res://assets/minigames/alien_commander/audio/sfx/AC_Player_Alien_Shoot_02.wav"),
]
const _ALIEN_HURT := preload("res://assets/minigames/alien_commander/audio/sfx/AC_Player_Alien_Hurt_01.wav")
const _ALIEN_DEATH := [
	preload("res://assets/minigames/alien_commander/audio/sfx/AC_Player_Alien_Die_01.wav"),
	preload("res://assets/minigames/alien_commander/audio/sfx/AC_Player_Alien_Die_02.wav"),
]
const _ENEMY_SHOOT := [
	preload("res://assets/minigames/alien_commander/audio/sfx/AC_Enemy_Ship_Shoot_01.wav"),
	preload("res://assets/minigames/alien_commander/audio/sfx/AC_Enemy_Ship_Shoot_02.wav"),
]
const _ENEMY_HURT := preload("res://assets/minigames/alien_commander/audio/sfx/AC_Enemy_Ship_Hurt_01.wav")
const _ENEMY_DEATH := preload("res://assets/minigames/alien_commander/audio/sfx/AC_Enemy_Ship_Die_01.wav")

var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0


func _ready() -> void:
	add_to_group(&"ac_audio")
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


func play_alien_select() -> void:
	_play_stream(_ALIEN_SELECT, PITCH_SELECTION)


func play_alien_select_error() -> void:
	# Placeholder buzz until a dedicated invalid-action SFX exists.
	_play_stream(_ALIEN_SELECT, PITCH_ERROR)


func play_alien_shoot() -> void:
	_play_random(_ALIEN_SHOOT, PITCH_SHOOT)


func play_alien_hurt() -> void:
	_play_stream(_ALIEN_HURT, PITCH_HURT)


func play_alien_death() -> void:
	_play_random(_ALIEN_DEATH, PITCH_DEATH)


func play_enemy_ship_shoot() -> void:
	_play_random(_ENEMY_SHOOT, PITCH_SHOOT)


func play_enemy_ship_hurt() -> void:
	_play_stream(_ENEMY_HURT, PITCH_HURT)


func play_enemy_ship_death() -> void:
	_play_stream(_ENEMY_DEATH, PITCH_DEATH)


func _play_random(streams: Array, pitch_range: Vector2) -> void:
	# Random variants keep rapid-fire sounds from becoming predictable.
	_play_stream(streams[randi() % streams.size()] as AudioStream, pitch_range)


func _play_stream(stream: AudioStream, pitch_range: Vector2) -> void:
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	# Small pitch variation prevents repetitive arcade SFX fatigue.
	player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	player.play()


static func find_audio(from: Node) -> Node:
	if from == null:
		return null
	return from.get_tree().get_first_node_in_group(&"ac_audio")
