extends CanvasLayer

# Transition d'entrée en combat façon FRLG : flash blanc rapide (x2) puis
# rideau noir qui se ferme (vertical, depuis les bords vers le centre).
# Réutilisable : jouer play_close() -> instancier ce qu'il faut cacher
# derrière -> jouer play_open() pour révéler.

signal covered    # écran totalement masqué : moment pour instancier la suite
signal finished   # rideau rouvert, transition terminée

const FLASH_COUNT := 2
const FLASH_TIME := 0.08
const CURTAIN_TIME := 0.25

@onready var flash: ColorRect = $Root/Flash
@onready var curtain_left: ColorRect = $Root/CurtainLeft
@onready var curtain_right: ColorRect = $Root/CurtainRight

func _ready() -> void:
	flash.modulate.a = 0.0
	curtain_left.anchor_right = 0.0
	curtain_right.anchor_left = 1.0

func play_close() -> void:
	for i in range(FLASH_COUNT):
		var tw := create_tween()
		tw.tween_property(flash, "modulate:a", 1.0, FLASH_TIME)
		tw.tween_property(flash, "modulate:a", 0.0, FLASH_TIME)
		await tw.finished
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(curtain_left, "anchor_right", 0.5, CURTAIN_TIME)
	tw2.tween_property(curtain_right, "anchor_left", 0.5, CURTAIN_TIME)
	await tw2.finished
	covered.emit()

func play_open() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(curtain_left, "anchor_right", 0.0, CURTAIN_TIME)
	tw.tween_property(curtain_right, "anchor_left", 1.0, CURTAIN_TIME)
	await tw.finished
	finished.emit()
