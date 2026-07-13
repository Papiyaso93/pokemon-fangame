extends Node

# Autoload : état de la visite en cours de la Zone Safari.
# Remis à zéro à chaque nouvelle entrée (voir player.gd).

const STARTING_BALLS := 30   # fidèle FRLG (src/safari_zone.c: gNumSafariBalls = 30)

var active := false          # true tant qu'on est dans une des 4 maps safari_zone_*
var balls := STARTING_BALLS
var caught: Array[String] = []   # espèces capturées pendant cette visite (accumulent)

# Acte 1 (voir acte1-parc-safari.md) : plus aucune rencontre sauvage tant que
# les 2 tutos Camille/Yohan ne sont pas terminés — Anselme les débloque en
# personne dans le parc (PARK_HANDOFF, scripts/npc_anselme_park.gd, beat 3b).
# Pas persisté ici (autoload remis à zéro à chaque lancement) : la vraie
# source de vérité est PlayerData.park_handoff_done, resynchronisée à chaque
# entrée dans une zone (utile après un chargement de partie).
var hunting_unlocked := false

const SAFARI_MAPS := [
	"safari_zone_center", "safari_zone_east", "safari_zone_north", "safari_zone_west",
]

func enter() -> void:
	active = true
	balls = STARTING_BALLS
	caught = []
	hunting_unlocked = PlayerData.park_handoff_done

func leave() -> void:
	active = false
