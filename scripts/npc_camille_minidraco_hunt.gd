extends StaticBody2D

# Camille "dehors", celle qui accompagne le joueur pendant le motif du
# Minidraco (voir scripts/minidraco_quest.gd::_spawn_camille()). Script
# minimal juste pour la rendre interactive comme un vrai PNJ (groupe "npc",
# tile()/face_toward() attendus par player.gd::_try_interact()/_talk_to()) —
# sa position/son animation de marche restent entièrement pilotées par
# minidraco_quest.gd, ce script ne fait que la partie "on peut lui parler".

const LINE: Array[String] = ["Vas-y, je reste là si besoin."]

func _ready() -> void:
	add_to_group("npc")

func tile() -> Vector2i:
	return Vector2i(roundi(position.x / 16.0), roundi(position.y / 16.0))

func face_toward(target_tile: Vector2i) -> void:
	var d := target_tile - tile()
	var dir := "south"
	if abs(d.x) > abs(d.y):
		dir = "east" if d.x > 0 else "west"
	elif d.y != 0:
		dir = "south" if d.y > 0 else "north"
	MinidracoQuest.call("_camille_play", "face", dir)

func get_lines() -> Array[String]:
	return LINE
