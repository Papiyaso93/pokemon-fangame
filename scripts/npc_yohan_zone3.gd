extends "res://scripts/npc.gd"

# Yohan : maison de repos de la Zone 3 (safari_rest_house_north).
# Faux dialogue temporaire (voir acte1-parc-safari.md) — à remplacer une fois
# le contenu réel de cette action décidé.

const LINES: Array[String] = ["Pouet."]

func get_lines() -> Array[String]:
	PlayerData.yohan_zone3_done = true
	return LINES
