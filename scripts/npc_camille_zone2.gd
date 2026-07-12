extends "res://scripts/npc.gd"

# Camille : maison de repos de la Zone 2 (safari_rest_house_east).
# Faux dialogue temporaire (voir acte1-parc-safari.md) — à remplacer une fois
# le contenu réel de cette action décidé.

const LINES: Array[String] = ["Pouet."]

func get_lines() -> Array[String]:
	PlayerData.camille_zone2_done = true
	return LINES
