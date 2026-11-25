@tool
extends Control
## Shared presentation only. The host owns player/session state and updates counts.
@onready var hearts: Node2D = $Hearts
@onready var meter: Control = $ResourceMeter
@onready var money_label: Label = $MoneyLabel
@onready var life_icon: TextureRect = $Lives/Icon
@onready var life_label: Label = $Lives/Count

func bind_player(player: Node) -> void:
	hearts.bind_player(player)
	meter.bind_resource(player.movement_resource if is_instance_valid(player) else null)

func update_money(quarters: int) -> void:
	var cents: int = quarters * 25
	money_label.text = "$%d.%02d" % [int(cents / 100.0), cents % 100]

func update_lives(lives: int) -> void:
	life_label.text = str(lives)

func life_icon_center() -> Vector2:
	# Match the uncropped 24x24 flying sprite to the cropped 24x21 HUD texture.
	return (life_icon.get_global_transform_with_canvas() * Vector2(12, 10)).round()
