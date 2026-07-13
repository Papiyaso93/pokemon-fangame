extends "res://scripts/npc.gd"

# Anselme, beat 3b (voir acte1-parc-safari.md) : réapparaît en personne dans
# le parc une fois les 2 tutos (Camille + Yohan) terminés, pour remettre la
# canne à pêche + les Safari Balls et débloquer enfin les rencontres sauvages
# (PARK_HANDOFF, dialogue partagé avec scripts/npc_worker_m.gd). Placé pour
# tester l'arc de bout en bout dans la maison secrète de la zone 4
# (safari_secret_house, atteignable depuis safari_zone_west, jusque-là vide
# de tout PNJ) et conditionné à l'obtention de la planche de Surf comme
# repère simple — sera sans doute déplacé/retravaillé une fois le contenu
# réel des zones 2/3 décidé.

const WorkerM = preload("res://scripts/npc_worker_m.gd")

const NOT_YET: Array[String] = [
	"Retrouve-moi une fois que tu auras fait le tour des deux voies, avec Camille et Yohan.",
]

const AFTER: Array[String] = [
	"Bonne chasse dans les hautes herbes !",
]

func get_lines() -> Array[String]:
	if not PlayerData.has_surf:
		return NOT_YET
	if not PlayerData.park_handoff_done:
		PlayerData.park_handoff_done = true
		PlayerData.has_fishing_rod = true
		SafariState.hunting_unlocked = true
		return WorkerM.PARK_HANDOFF.duplicate()
	return AFTER
