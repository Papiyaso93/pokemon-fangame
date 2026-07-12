extends Node2D

# Verrouille l'accès aux zones du Parc Safari tant qu'on n'a pas parlé au PNJ
# de la maison de repos de la zone précédente (voir acte1-parc-safari.md).
# Attaché aux 4 cartes extérieures (safari_zone_center/east/north/west) :
# le blocage se fait sur la carte CIBLE du warp, peu importe par quel chemin
# physique on y arrive (Center est un carrefour relié aux 3 autres zones).

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const ExclamationTexture := preload("res://assets/ui/exclamation.png")
const OPPOSITE := {"south": "north", "north": "south", "east": "west", "west": "east"}

# target de warp -> (condition remplie ?, PNJ à voir en attendant)
const REQUIREMENTS := {
	"safari_zone_east": {"flag": "camille_zone1_done", "npc": "Camille"},
	"safari_zone_north": {"flag": "camille_zone2_done", "npc": "Camille"},
	"safari_zone_west": {"flag": "yohan_zone3_done", "npc": "Yohan"},
}

func gate_check(warp: Dictionary) -> bool:
	var target := String(warp.get("target", ""))
	var req: Dictionary = REQUIREMENTS.get(target, {})
	if req.is_empty():
		return true
	return bool(PlayerData.get(String(req["flag"])))

func on_gate_blocked(warp: Dictionary, player: Node) -> void:
	var target := String(warp.get("target", ""))
	var req: Dictionary = REQUIREMENTS.get(target, {})
	var npc_name: String = String(req.get("npc", "quelqu'un"))

	player.is_busy = true
	player.facing = OPPOSITE.get(player.facing, player.facing)
	player._play("face")
	_show_exclamation(player)

	var lines: Array[String] = ["Va d'abord voir %s avant de passer à la zone suivante." % npc_name]
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()
	player.is_busy = false

# Identique à safari_entrance_gate.gd::_show_exclamation() — dupliqué plutôt
# que factorisé, pas d'utilitaire partagé existant dans le projet pour ça.
func _show_exclamation(player: Node) -> void:
	var icon := Sprite2D.new()
	icon.texture = ExclamationTexture
	icon.scale = Vector2(1.3, 1.3)
	icon.position = Vector2(8, -28)
	player.add_child(icon)
	var tw := create_tween()
	tw.tween_property(icon, "position:y", icon.position.y - 4, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "position:y", icon.position.y, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.6).timeout
	icon.queue_free()
