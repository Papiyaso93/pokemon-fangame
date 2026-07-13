extends CanvasLayer

signal finished

# Espèce tirée au hasard dans SafariRoster (tous les Pokémon de base de la
# 1ère gen, sauf légendaires — cf. safari_roster.gd) à chaque rencontre.
# Niveau fixe 5 pour tous, pour l'instant (pas de vraie donnée de niveau par
# zone/espèce encore).
const SPECIES_LEVEL := 5
const SAFARI_BALL_MULTIPLIER := 1.5   # bonus Safari Ball (pret sBallCatchBonuses = 15/10)

var species_key := ""
var species_name := ""
var species_catch_rate := 45.0
var species_flee_rate := 30.0

# Fidèle pret src/battle_main.c (HandleAction_ThrowBait/ThrowRock) :
# l'appât DIMINUE le taux de capture (mais aussi la fuite), le caillou
# l'AUGMENTE (mais aussi la fuite) — contre-intuitif mais réel. Calculés dans
# _ready() une fois l'espèce tirée (dépendent de species_catch_rate/flee_rate).
var base_catch_factor := 0.0
var base_escape_factor := 0.0

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const CONTINUE_ARROW_TEXTURES := [
	preload("res://assets/ui/down_arrow_3.png"),
	preload("res://assets/ui/down_arrow_4.png"),
]
const ARROW_BLINK := 0.3   # même vitesse que dialogue_box.gd

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
@onready var label: Label = $Root/BottomBox/Mid/Inner/Content/Label
@onready var continue_arrow: TextureRect = $Root/BottomBox/Mid/Inner/Content/Arrow
@onready var ball_button: Button = $Root/ActionWindow/Buttons/Ball
@onready var bait_button: Button = $Root/ActionWindow/Buttons/Bait
@onready var rock_button: Button = $Root/ActionWindow/Buttons/Rock
@onready var run_button: Button = $Root/ActionWindow/Buttons/Run

var catch_factor := 0.0
var bait_counter := 0
var rock_counter := 0
var intro_message := ""
var typewriter: Typewriter

const ESCAPE_MESSAGES := [
	"Aïe ! Le Pokémon sauvage s'est échappé d'un coup !",
	"Zut ! Il s'est libéré !",
	"Argh ! Presque !",
	"Zut ! Il s'en est fallu de peu !",
]

func _ready() -> void:
	species_key = SafariRoster.base_species().pick_random()
	var sp: Dictionary = SpeciesData.SPECIES[species_key]
	species_name = sp["name"]
	species_catch_rate = float(sp["catch_rate"])
	species_flee_rate = float(sp["safari_flee_rate"])
	base_catch_factor = species_catch_rate * 100.0 / 1275.0
	base_escape_factor = maxf(2.0, species_flee_rate * 100.0 / 1275.0)
	catch_factor = base_catch_factor
	sprite.texture = load("res://assets/pokemon/%s/front.png" % species_key)
	if species_key not in PlayerData.pokedex_seen:
		PlayerData.pokedex_seen.append(species_key)

	typewriter = Typewriter.new(label)
	name_label.text = species_name.to_upper()
	level_label.text = "N.%d" % SPECIES_LEVEL
	gender_label.text = "♂" if randf() < 0.5 else "♀"
	hp_fill.anchor_right = 1.0
	intro_message = "Un %s sauvage apparaît !" % species_name
	label.text = ""
	_update_balls_label()
	_set_buttons_enabled(false)
	for btn in [ball_button, bait_button, rock_button, run_button]:
		btn.icon = BlankTexture
		# Le survol souris déplace le focus clavier au lieu de gérer sa propre
		# flèche : sinon 2 flèches peuvent s'afficher à la fois (une au clavier,
		# une à la souris) si elles ne pointent pas le même bouton.
		btn.mouse_entered.connect(func(): btn.grab_focus())
		btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
		btn.focus_exited.connect(func(): btn.icon = BlankTexture)

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
	_type_text(intro_message)   # tape pendant que l'animation joue, pas d'attente ici
	await tw.finished

	# Le message d'apparition enchaîne seul après un court délai (pas d'appui
	# requis, cf. plus bas) — mais un appui pendant ce délai fait quand même
	# passer à la suite immédiatement, avec la même flèche de continuation que
	# dialogue_box.gd, pour rester iso avec les discussions PNJ.
	await _wait_or_continue(1.3)
	await _type_text("Que veux-tu faire ?")
	_set_buttons_enabled(true)

func _set_buttons_enabled(enabled: bool) -> void:
	ball_button.disabled = not enabled or SafariState.balls <= 0
	bait_button.disabled = not enabled
	rock_button.disabled = not enabled
	run_button.disabled = not enabled
	# Focus par défaut sur la première action jouable (voir yes_no_choice.gd) :
	# Safari Ball, sauf s'il n'en reste plus, auquel cas Appât prend sa place.
	if enabled:
		(bait_button if ball_button.disabled else ball_button).grab_focus()

# Même comportement que dialogue_box.gd (via le composant partagé Typewriter) :
# un appui pendant la frappe affiche le reste du texte instantanément ; un
# appui pendant la pause qui suit (flèche visible) passe à la suite tout de
# suite au lieu d'attendre le délai. Vaut pour tous les messages de cet écran
# (apparition, capture, appât/pierre...).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if typewriter.typing:
		typewriter.skip()
		get_viewport().set_input_as_handled()
	elif waiting:
		advance_requested = true
		get_viewport().set_input_as_handled()

func _update_balls_label() -> void:
	balls_label.text = "SAFARI BALLS\nNb : %d" % SafariState.balls

# État de la pause "flèche de continuation" après un texte complet (voir
# _wait_or_continue) — waiting=true tant que la flèche est affichée,
# advance_requested passe à true sur un appui pour couper court au délai.
var waiting := false
var advance_requested := false
var arrow_frame := 0
var arrow_timer := 0.0

func _process(delta: float) -> void:
	if typewriter.typing:
		typewriter.update(delta)
	if not waiting:
		return
	arrow_timer += delta
	if arrow_timer >= ARROW_BLINK:
		arrow_timer = 0.0
		arrow_frame = 1 - arrow_frame
		continue_arrow.texture = CONTINUE_ARROW_TEXTURES[arrow_frame]

func _type_text(text: String) -> void:
	typewriter.start(text)
	await typewriter.completed

# Affiche la flèche de continuation (comme dialogue_box.gd) et attend soit le
# délai indiqué, soit un appui du joueur — le premier des deux qui arrive.
func _wait_or_continue(duration: float) -> void:
	waiting = true
	advance_requested = false
	arrow_frame = 0
	continue_arrow.texture = CONTINUE_ARROW_TEXTURES[0]
	continue_arrow.visible = true
	var elapsed := 0.0
	while elapsed < duration and not advance_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	waiting = false
	continue_arrow.visible = false

func _say(text: String, wait := 1.3) -> void:
	await _type_text(text)
	await _wait_or_continue(wait)

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
		await _say("Gotcha ! %s a été capturé !" % species_name, 1.5)
		SafariState.caught.append(species_name)
		if species_key not in PlayerData.pokedex_caught:
			PlayerData.pokedex_caught.append(species_key)
	else:
		await _say(ESCAPE_MESSAGES[shakes], 1.3)

	# Plus aucune Ball : le combat s'arrête net ici, pas de tour de plus avec
	# appât/pierre (le joueur ne pourra de toute façon plus jamais relancer
	# une Ball). Le message "on te raccompagne" suit séparément une fois
	# revenu côté player.gd.
	if SafariState.balls <= 0:
		await _say("Il ne te reste plus aucune Safari Ball !")
		finished.emit()
		return

	if shakes >= 4:
		finished.emit()
		return

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
			catch_factor = base_catch_factor
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
	var flee_rate := base_escape_factor
	if rock_counter > 0:
		flee_rate = minf(20.0, base_escape_factor * 2.0)
	elif bait_counter > 0:
		flee_rate = maxf(1.0, base_escape_factor / 4.0)
	var flee_chance := flee_rate * 5.0   # pourcentage (0-100)

	if randf() * 100.0 < flee_chance:
		await _say("Le Pokémon sauvage s'est enfui !", 1.5)
		finished.emit()
		return

	await _type_text("Que veux-tu faire ?")
	_set_buttons_enabled(true)
