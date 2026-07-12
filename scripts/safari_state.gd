extends Node

# Autoload : état de la visite en cours de la Zone Safari.
# Remis à zéro à chaque nouvelle entrée (voir player.gd).

const STARTING_BALLS := 30   # fidèle FRLG (src/safari_zone.c: gNumSafariBalls = 30)

var active := false          # true tant qu'on est dans une des 4 maps safari_zone_*
var balls := STARTING_BALLS
var caught: Array[String] = []   # espèces capturées pendant cette visite (accumulent)

# Acte 1 (voir acte1-parc-safari.md) : plus aucune rencontre sauvage tant que
# les 2 tutos Camille/Yohan ne sont pas terminés — Anselme doit les débloquer
# en personne dans le parc (PARK_HANDOFF, npc_worker_m.gd), pas encore câblé
# aujourd'hui (12/07/2026) faute des tutos eux-mêmes. En attendant, ce
# drapeau reste à false en dur : aucune rencontre possible dans les hautes
# herbes, quel que soit le nombre de balls. À mettre à true depuis le futur
# PARK_HANDOFF une fois les tutos codés.
var hunting_unlocked := false

const SAFARI_MAPS := [
	"safari_zone_center", "safari_zone_east", "safari_zone_north", "safari_zone_west",
]

func enter() -> void:
	active = true
	balls = STARTING_BALLS
	caught = []

func leave() -> void:
	active = false
