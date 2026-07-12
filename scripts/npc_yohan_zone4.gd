extends "res://scripts/npc.gd"

# Yohan : maison de repos de la Zone 4 (safari_rest_house_west).
# Faux dialogue temporaire (voir acte1-parc-safari.md) — à remplacer une fois
# le contenu réel de cette action décidé. Donne quand même la planche de
# Surf pour de vrai, pour pouvoir tester son fonctionnement dès maintenant.

const LINES: Array[String] = ["Pouet.", "Voilà la planche de Surf."]
const AFTER: Array[String] = ["Pouet."]

func get_lines() -> Array[String]:
	if not PlayerData.yohan_zone4_done:
		PlayerData.yohan_zone4_done = true
		PlayerData.has_surf = true
		return LINES
	return AFTER
