extends CanvasLayer

signal finished

# Placeholder en attendant la vraie table d'espèces (roster bébés gen 1 à définir).
const SPECIES_NAME := "Rattata"
const SPECIES_CATCH_RATE := 255   # taux réel Rattata (255/255, le plus facile)
const SAFARI_BALL_MULTIPLIER := 1.5   # bonus Safari Ball (pret sBallCatchBonuses = 15/10)

@onready var sprite: TextureRect = $Root/Sprite
@onready var label: Label = $Root/MessageBox/Label
@onready var balls_label: Label = $Root/SafariBox/BallsLabel
@onready var throw_button: Button = $Root/ActionBox/Buttons/Throw
@onready var flee_button: Button = $Root/ActionBox/Buttons/Flee

func _ready() -> void:
	label.text = "Un %s sauvage apparaît !" % SPECIES_NAME
	_update_balls_label()

func _update_balls_label() -> void:
	balls_label.text = "Safari Balls\n× %d" % SafariState.balls

func _on_throw_pressed() -> void:
	throw_button.disabled = true
	flee_button.disabled = true
	SafariState.balls -= 1
	_update_balls_label()

	# Formule réelle FRLG (pret src/battle_script_commands.c, Cmd_handleballthrow) :
	# odds = (catchRate * ballMultiplier/10) * (maxHP*3 - hp*2) / (3*maxHP)
	# Le Pokémon n'étant jamais blessé ici, le facteur HP vaut toujours 1/3.
	# Simplification : un seul jet de probabilité (odds/255) au lieu de simuler
	# les 4 "secousses" du jeu original (TODO si on veut la fidélité exacte).
	var odds := SPECIES_CATCH_RATE * SAFARI_BALL_MULTIPLIER / 3.0
	var caught := randf() < odds / 255.0

	if caught:
		label.text = "Gotcha ! %s a été capturé !" % SPECIES_NAME
		SafariState.caught.append(SPECIES_NAME)
	else:
		label.text = "Zut ! %s s'est enfui !" % SPECIES_NAME

	await get_tree().create_timer(1.5).timeout
	finished.emit()

func _on_flee_pressed() -> void:
	finished.emit()
