extends CanvasLayer

signal finished

# Placeholder en attendant la vraie table d'espèces (roster bébés gen 1 à définir
# avec l'ami de Gus). Niveau fixe 5 pour tous les Pokémon de la Zone Safari
# (décision prise en attendant le vrai roster).
const SPECIES_NAME := "Rattata"
const SPECIES_LEVEL := 5
const SPECIES_CATCH_RATE := 255.0     # taux réel Rattata (255/255, le plus facile)
const SPECIES_FLEE_RATE := 30.0       # placeholder (pas de vraie donnée Safari par espèce encore)
const SAFARI_BALL_MULTIPLIER := 1.5   # bonus Safari Ball (pret sBallCatchBonuses = 15/10)

# Fidèle pret src/battle_main.c (HandleAction_ThrowBait/ThrowRock) :
# l'appât DIMINUE le taux de capture (mais aussi la fuite), le caillou
# l'AUGMENTE (mais aussi la fuite) — contre-intuitif mais réel.
const BASE_CATCH_FACTOR := SPECIES_CATCH_RATE * 100.0 / 1275.0
const BASE_ESCAPE_FACTOR := maxf(2.0, SPECIES_FLEE_RATE * 100.0 / 1275.0)

@onready var sprite: TextureRect = $Root/Sprite
@onready var shadow: TextureRect = $Root/Shadow
@onready var player_sprite: TextureRect = $Root/PlayerSprite
@onready var player_shadow: TextureRect = $Root/PlayerShadow
@onready var health_box: PanelContainer = $Root/HealthBox
@onready var name_label: Label = $Root/HealthBox/VBox/NameRow/NameLabel
@onready var gender_label: Label = $Root/HealthBox/VBox/NameRow/GenderLabel
@onready var level_label: Label = $Root/HealthBox/VBox/NameRow/LevelLabel
@onready var hp_fill: ColorRect = $Root/HealthBox/VBox/HPBarBg/HPBarFill
@onready var safari_box: PanelContainer = $Root/SafariBox
@onready var balls_label: Label = $Root/SafariBox/BallsLabel
@onready var label: Label = $Root/MessageBox/Label
@onready var ball_button: Button = $Root/ActionBox/Buttons/Ball
@onready var bait_button: Button = $Root/ActionBox/Buttons/Bait
@onready var rock_button: Button = $Root/ActionBox/Buttons/Rock
@onready var run_button: Button = $Root/ActionBox/Buttons/Run

var catch_factor := BASE_CATCH_FACTOR
var bait_counter := 0
var rock_counter := 0

const ESCAPE_MESSAGES := [
	"Aïe ! Le Pokémon sauvage s'est échappé d'un coup !",
	"Zut ! Il s'est libéré !",
	"Argh ! Presque !",
	"Zut ! Il s'en est fallu de peu !",
]

func _ready() -> void:
	name_label.text = SPECIES_NAME.to_upper()
	level_label.text = "N.%d" % SPECIES_LEVEL
	gender_label.text = "♂" if randf() < 0.5 else "♀"
	hp_fill.anchor_right = 1.0
	label.text = "Un %s sauvage apparaît !" % SPECIES_NAME
	_update_balls_label()
	_set_buttons_enabled(false)

	var back_path := "res://assets/characters/%s_back.png" % PlayerData.appearance
	if ResourceLoader.exists(back_path):
		player_sprite.texture = load(back_path)

	sprite.scale = Vector2.ZERO
	sprite.pivot_offset = sprite.size / 2.0
	shadow.modulate.a = 0.0
	player_sprite.modulate.a = 0.0
	player_shadow.modulate.a = 0.0
	health_box.modulate.a = 0.0
	health_box.position.x -= 200
	safari_box.modulate.a = 0.0
	safari_box.position.x += 200

# Petite entrée animée (rebond du sprite + glissement des boîtes) jouée par
# player.gd juste après l'ouverture du rideau de transition, pour ne pas être
# masquée par l'écran noir.
func play_entrance() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(shadow, "modulate:a", 1.0, 0.3).set_delay(0.15)
	tw.tween_property(player_sprite, "modulate:a", 1.0, 0.3).set_delay(0.1)
	tw.tween_property(player_shadow, "modulate:a", 1.0, 0.3).set_delay(0.1)
	tw.tween_property(health_box, "position:x", health_box.position.x + 200, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(health_box, "modulate:a", 1.0, 0.25)
	tw.tween_property(safari_box, "position:x", safari_box.position.x - 200, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(safari_box, "modulate:a", 1.0, 0.25)
	await tw.finished
	_set_buttons_enabled(true)

func _set_buttons_enabled(enabled: bool) -> void:
	ball_button.disabled = not enabled or SafariState.balls <= 0
	bait_button.disabled = not enabled
	rock_button.disabled = not enabled
	run_button.disabled = not enabled

func _update_balls_label() -> void:
	balls_label.text = "SAFARI BALLS\nNb : %d" % SafariState.balls

func _say(text: String, wait := 1.3) -> void:
	label.text = text
	await get_tree().create_timer(wait).timeout

# Formule réelle FRLG (pret src/battle_script_commands.c, Cmd_handleballthrow) :
# odds = (catchRate * ballMultiplier/10) * facteur HP (toujours 1/3, jamais blessé
# en Zone Safari). Si odds > 254 : capture garantie. Sinon, simulation des 4
# "secousses" (Sqrt(Sqrt(16711680/odds)) puis 4 tirages successifs).
func _attempt_catch(effective_catch_rate: float) -> int:
	var odds := effective_catch_rate * SAFARI_BALL_MULTIPLIER / 3.0
	if odds > 254.0:
		return 4
	var shake_odds := sqrt(sqrt(16711680.0 / odds))
	var shake_threshold := 1048560.0 / shake_odds
	var shakes := 0
	while shakes < 4 and (randi() % 65536) < shake_threshold:
		shakes += 1
	return shakes

func _on_ball_pressed() -> void:
	_set_buttons_enabled(false)
	SafariState.balls -= 1
	_update_balls_label()

	# safariCatchFactor -> taux de capture "brut" (échelle 0-255), pret
	# src/battle_script_commands.c : catchRate = safariCatchFactor * 1275/100.
	var effective_catch_rate := catch_factor * 1275.0 / 100.0
	var shakes := _attempt_catch(effective_catch_rate)

	if shakes >= 4:
		await _say("Gotcha ! %s a été capturé !" % SPECIES_NAME, 1.5)
		SafariState.caught.append(SPECIES_NAME)
		finished.emit()
		return

	await _say(ESCAPE_MESSAGES[shakes], 1.3)
	await _end_of_round()

func _on_bait_pressed() -> void:
	_set_buttons_enabled(false)
	rock_counter = 0
	bait_counter = mini(6, bait_counter + (randi() % 5 + 2))
	catch_factor = maxf(3.0, catch_factor / 2.0)
	await _say("Vous lancez un appât !")
	await _end_of_round()

func _on_rock_pressed() -> void:
	_set_buttons_enabled(false)
	bait_counter = 0
	rock_counter = mini(6, rock_counter + (randi() % 5 + 2))
	catch_factor = minf(20.0, catch_factor * 2.0)
	await _say("Vous lancez une pierre !")
	await _end_of_round()

func _on_run_pressed() -> void:
	_set_buttons_enabled(false)
	await _say("Vous prenez la fuite.")
	finished.emit()

# Réaction du Pokémon sauvage + décompte des effets appât/pierre, fidèle à
# HandleAction_WatchesCarefully (pret src/battle_main.c) : le caillou "s'use"
# et redonne le taux de capture normal une fois épuisé ; l'appât, lui, ne
# revient PAS au taux de base une fois épuisé (fidèle au comportement réel,
# une bizarrerie connue du jeu original).
func _end_of_round() -> void:
	if rock_counter > 0:
		rock_counter -= 1
		if rock_counter == 0:
			catch_factor = BASE_CATCH_FACTOR
			await _say("Le Pokémon sauvage vous regarde avec attention.")
		else:
			await _say("Le Pokémon sauvage est en colère !")
	elif bait_counter > 0:
		bait_counter -= 1
		if bait_counter == 0:
			await _say("Le Pokémon sauvage vous regarde avec attention.")
		else:
			await _say("Le Pokémon sauvage mange !")
	else:
		await _say("Le Pokémon sauvage vous regarde avec attention.")

	# Jet de fuite fidèle Cmd_if_random_safari_flee (pret
	# src/battle_ai_script_commands.c) : le caillou augmente le risque de
	# fuite, l'appât le diminue.
	var flee_rate := BASE_ESCAPE_FACTOR
	if rock_counter > 0:
		flee_rate = minf(20.0, BASE_ESCAPE_FACTOR * 2.0)
	elif bait_counter > 0:
		flee_rate = maxf(1.0, BASE_ESCAPE_FACTOR / 4.0)
	var flee_chance := flee_rate * 5.0   # pourcentage (0-100)

	if randf() * 100.0 < flee_chance:
		await _say("Le Pokémon sauvage s'est enfui !", 1.5)
		finished.emit()
		return

	label.text = "Que faites-vous ?"
	_set_buttons_enabled(true)
