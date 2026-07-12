extends "res://scripts/npc.gd"

# Camille : maison de repos de la Zone 2 (safari_rest_house_east).
# Faux dialogue temporaire (voir acte1-parc-safari.md) — à remplacer une fois
# le contenu réel de cette action décidé.
# La canne à pêche n'est PLUS donnée ici (décidé le 13/07/2026) : ça n'a pas
# de sens tant que la capture n'est pas débloquée (hunting_unlocked). C'est
# Anselme qui la remettra plus tard, avec les Safari Balls (PARK_HANDOFF,
# scripts/npc_worker_m.gd) — la mécanique de pêche elle-même reste prête
# dans scripts/player.gd, juste pas encore accessible.

const LINES: Array[String] = ["Pouet."]

func get_lines() -> Array[String]:
	PlayerData.camille_zone2_done = true
	return LINES
