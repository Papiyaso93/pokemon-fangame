extends "res://scripts/npc.gd"

# Yohan : maison de repos de la Zone 4 (safari_rest_house_west).
# Faux dialogue temporaire (voir acte1-parc-safari.md) — à remplacer une fois
# le contenu réel de cette action décidé.
# Ne donne plus la planche de Surf (décidée le 14/07/2026 côté scénario) :
# c'est désormais Camille qui la remet à la fin de la quête du Minidraco
# (voir scripts/minidraco_quest.gd). Récompense de remplacement pour cette
# zone pas encore définie — point ouvert, voir acte1-parc-safari.md.

const LINES: Array[String] = ["Pouet."]
const AFTER: Array[String] = ["Pouet."]

func get_lines() -> Array[String]:
	if not PlayerData.yohan_zone4_done:
		PlayerData.yohan_zone4_done = true
		return LINES
	return AFTER
