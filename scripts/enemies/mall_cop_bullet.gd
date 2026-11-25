extends Area2D

@export var speed: float = 300.0
var direction: int = 1  # 1 = right, -1 = left

@onready var visible_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	visible_notifier.screen_exited.connect(_on_screen_exited)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta


func _on_screen_exited() -> void:
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		queue_free()
