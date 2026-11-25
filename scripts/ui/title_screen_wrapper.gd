extends Control

@onready var _title_viewport: SubViewport = $TitleViewport
@onready var _title_texture: TextureRect = $TitleTexture


func _ready() -> void:
	await get_tree().process_frame
	_title_texture.texture = _title_viewport.get_texture()
