extends "res://scripts/npc.gd"

# Yohan : maison de repos de la Zone 3 (safari_rest_house_north).
# Faux dialogue temporaire (voir acte1-parc-safari.md) — à remplacer une fois
# le contenu réel de cette action décidé. Donne quand même 5 Répulsifs pour
# de vrai (voir PlayerData.repel_count), utilisables dès maintenant dans le
# parc pour éviter les rencontres sauvages dans une zone donnée.

const LINES: Array[String] = ["Pouet. Voilà 5 Répulsifs."]
const AFTER: Array[String] = ["Pouet."]

func get_lines() -> Array[String]:
	if not PlayerData.yohan_zone3_done:
		PlayerData.yohan_zone3_done = true
		PlayerData.repel_count += 5
		return LINES
	return AFTER
