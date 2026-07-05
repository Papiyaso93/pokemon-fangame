extends StaticBody2D

# PNJ statique interactif. Le joueur interagit en appuyant sur "ui_accept"
# en lui faisant face, à 1 case de distance (voir player.gd, groupe "npc").

@export var sprite_name := "worker_f"   # fichier dans assets/characters/ (frame 0 = sud debout)
@export var facing := "west"            # south / north / west / east

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("npc")
	var tex := load("res://assets/characters/%s.png" % sprite_name) as Texture2D
	var at := AtlasTexture.new()
	at.atlas = tex
	var col: int = {"south": 0, "north": 1, "west": 2, "east": 2}.get(facing, 0)
	at.region = Rect2(col * 16, 0, 16, 32)
	sprite.texture = at
	sprite.flip_h = (facing == "east")
	sprite.centered = false
	sprite.position = Vector2(0, -16)

func tile() -> Vector2i:
	return Vector2i(round(position.x / 16.0), round(position.y / 16.0))

# Surchargé par les PNJ spécifiques (voir npc_worker_f.gd, npc_worker_m.gd).
func get_lines() -> Array[String]:
	return []
