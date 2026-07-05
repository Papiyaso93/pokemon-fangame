extends Node

# Autoload : état de la visite en cours de la Zone Safari.
# Remis à zéro à chaque nouvelle entrée (voir player.gd).

const STARTING_BALLS := 30   # fidèle FRLG (src/safari_zone.c: gNumSafariBalls = 30)

var active := false          # true tant qu'on est dans une des 4 maps safari_zone_*
var balls := STARTING_BALLS
var caught: Array[String] = []   # espèces capturées pendant cette visite (accumulent)

const SAFARI_MAPS := [
	"safari_zone_center", "safari_zone_east", "safari_zone_north", "safari_zone_west",
]

func enter() -> void:
	active = true
	balls = STARTING_BALLS
	caught = []

func leave() -> void:
	active = false
