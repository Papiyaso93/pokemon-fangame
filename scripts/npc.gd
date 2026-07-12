extends StaticBody2D

# PNJ statique interactif. Le joueur interagit en appuyant sur "ui_accept"
# en lui faisant face, à 1 case de distance (voir player.gd, groupe "npc").

@export var sprite_name := "worker_f"   # fichier dans assets/characters/ (frame 0 = sud debout)
@export var facing := "west"            # south / north / west / east

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("npc")
	sprite.centered = false
	sprite.position = Vector2(0, -16)
	_update_sprite()

func _update_sprite() -> void:
	var tex := load("res://assets/characters/%s.png" % sprite_name) as Texture2D
	var at := AtlasTexture.new()
	at.atlas = tex
	var col: int = {"south": 0, "north": 1, "west": 2, "east": 2}.get(facing, 0)
	at.region = Rect2(col * 16, 0, 16, 32)
	sprite.texture = at
	sprite.flip_h = (facing == "east")

# Change la direction affichée (ex: se tourner vers le joueur qui vient
# d'engager la conversation, voir player.gd::_talk_to()).
func face(dir: String) -> void:
	facing = dir
	_update_sprite()

# Se tourne vers une case donnée (celle du joueur), fidèle FRLG : les PNJ se
# tournent vers toi quand tu leur parles.
func face_toward(target_tile: Vector2i) -> void:
	var d := target_tile - tile()
	if abs(d.x) > abs(d.y):
		face("east" if d.x > 0 else "west")
	elif d.y != 0:
		face("south" if d.y > 0 else "north")

func tile() -> Vector2i:
	return Vector2i(round(position.x / 16.0), round(position.y / 16.0))

# Surchargé par les PNJ spécifiques (voir npc_worker_f.gd, npc_worker_m.gd).
func get_lines() -> Array[String]:
	return []
