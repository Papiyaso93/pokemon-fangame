extends CanvasLayer

# Écran de combat dresseur (distinct de encounter.gd, qui reste l'écran de
# capture Safari) — structure visuelle dupliquée depuis encounter.tscn
# (mêmes proportions/styles déjà éprouvés), avec un 2e HealthBox pour le
# Pokémon du joueur et une boîte "Que doit faire X ?" à côté du menu
# d'action, fidèle au vrai jeu. Construit la logique pure (BattleSide/
# BattleEngine) à partir des équipes fournies par l'appelant, puis pilote un
# vrai menu à 4 boutons (Attaque/Sac/Pokémon/Fuite, comme le vrai jeu) et
# rejoue les évènements retournés par `battle_engine.gd` un par un (messages,
# dégâts animés, K.O., météo). Sac et Fuite restent visibles pour coller à
# l'écran de combat d'origine, mais refusent poliment : pas d'objet ni de
# fuite en combat dresseur officiel (voir npc_yohan_zone3.gd).
#
# Propriétés à poser par l'appelant AVANT add_child() (même convention que
# encounter.gd::species_key) :
#   player_entries / enemy_entries : Array[{"species","level","moves"}]
#   enemy_trainer_name : String
#   pre_turn_hook : Callable(int) -> void, optionnel, awaité juste avant
#     d'afficher le menu d'action de chaque tour (numéro de tour en argument,
#     1-indexé) — point d'accroche pour scripts/yohan_zone3_battle.gd qui
#     injecte les conseils de Yohan sans que ce fichier ne connaisse "Yohan".
#
# Pas d'animation d'envoi de Poké Ball ni d'animation d'attaque pour ce
# premier lot (voir la conversation de conception) — sprites statiques,
# uniquement les PV/la météo qui s'animent. Facile d'en ajouter plus tard,
# les évènements de `_play_events()` sont déjà le bon point d'accroche.

signal finished(result: String)

# Signal générique réutilisé pour tous les sous-menus de cet écran (valeur
# selon le contexte : int pour le menu principal/le switch, String pour le
# choix de capacité) — même pattern que yes_no_choice.gd/list_picker.gd
# (`chosen.emit(value)` puis `await chosen` côté appelant), plus fiable
# qu'une boucle d'attente maison sur des variables locales partagées.
signal _choice_made(value)
# Utilisé par _prompt_switch() ET _prompt_move_choice() (annulation à
# ui_cancel dans les deux cas), pas seulement le switch malgré le nom —
# gardé tel quel plutôt que renommé, un seul point d'usage par écran à la
# fois de toute façon.
var _switch_cancel_enabled := false

# Types réellement utilisés par les capacités de ce combat (voir
# move_data.gd) — pas les 18 types du jeu, même logique que
# FRENCH_MOVE_NAMES (move_data.gd) : sous-ensemble volontaire, à étendre à
# la demande plus tard.
const FRENCH_TYPE_NAMES := {
	"NORMAL": "Normal",
	"FIRE": "Feu",
	"WATER": "Eau",
	"GRASS": "Plante",
	"FIGHTING": "Combat",
}

# Les 3 seules catégories possibles (pas un sous-ensemble comme les types
# ci-dessus) — voir MoveData.MOVES::category, déjà calculée par
# kanto-pipeline/build_moves_data.py (physique/spéciale selon le type en
# Gen<4, statut si power=0).
const FRENCH_CATEGORY_NAMES := {
	"PHYSICAL": "Physique",
	"SPECIAL": "Spéciale",
	"STATUS": "Statut",
}

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const DialogueFont := preload("res://assets/fonts/dialogue_latin.fnt")
const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

var player_entries: Array = []
var enemy_entries: Array = []
var enemy_trainer_name := ""
var pre_turn_hook: Callable = Callable()

var player_side: BattleSide
var enemy_side: BattleSide
var engine: BattleEngine
var _turn_number := 0
var _empty_button_style: StyleBoxEmpty

@onready var _root: Control = $Root
@onready var _enemy_sprite: TextureRect = $Root/Sprite
@onready var _player_sprite: TextureRect = $Root/PlayerSprite
@onready var _enemy_name_label: Label = $Root/EnemyHealthBox/VBox/NameRow/NameLabel
@onready var _enemy_gender_label: Label = $Root/EnemyHealthBox/VBox/NameRow/GenderLabel
@onready var _enemy_level_label: Label = $Root/EnemyHealthBox/VBox/NameRow/LevelLabel
@onready var _enemy_hp_fill: ColorRect = $Root/EnemyHealthBox/VBox/HPBarBg/HPBarFill
@onready var _enemy_hp_label: Label = $Root/EnemyHealthBox/VBox/HPTextLabel
@onready var _player_name_label: Label = $Root/PlayerHealthBox/VBox/NameRow/NameLabel
@onready var _player_gender_label: Label = $Root/PlayerHealthBox/VBox/NameRow/GenderLabel
@onready var _player_level_label: Label = $Root/PlayerHealthBox/VBox/NameRow/LevelLabel
@onready var _player_hp_fill: ColorRect = $Root/PlayerHealthBox/VBox/HPBarBg/HPBarFill
@onready var _player_hp_label: Label = $Root/PlayerHealthBox/VBox/HPTextLabel
@onready var _action_window: PanelContainer = $Root/ActionWindow
@onready var _menu_container: Control = $Root/ActionWindow/MenuBox

# Boîte de dialogue pleine largeur (comme partout ailleurs dans le jeu) qui
# affiche "Que doit faire X ?" et reste figée pendant que le menu d'action
# est utilisé — même pattern que player.gd::_start_surfing() (dialogue.say()
# + await page_typed + active=false, sans fermer/rouvrir la boîte). Fidèle
# au vrai jeu : la boîte ne se rétrécit PAS pour le menu, c'est le menu qui
# recouvre une partie de la boîte, par-dessus. dialogue_box.tscn est à
# layer=95 (voir son propre correctif) : _action_window doit donc être
# ressorti dans son propre CanvasLayer à un layer encore plus élevé pour
# rester visible par-dessus — voir _ready(), _action_layer.
var _prompt_dialogue: Node = null
var _action_layer: CanvasLayer = null

func _ready() -> void:
	layer = 90
	_empty_button_style = StyleBoxEmpty.new()
	_empty_button_style.content_margin_left = 8.0
	_empty_button_style.content_margin_top = 4.0
	_empty_button_style.content_margin_right = 8.0
	_empty_button_style.content_margin_bottom = 4.0

	player_side = _build_side(player_entries, true, "")
	enemy_side = _build_side(enemy_entries, false, enemy_trainer_name)
	engine = BattleEngine.new(player_side, enemy_side)

	_refresh_sprites()
	_refresh_health_display()

	# _action_window est un enfant de Root (donc du CanvasLayer TrainerBattle,
	# layer=90) dans le .tscn, pour rester facile à éditer visuellement — mais
	# à l'exécution il doit s'afficher AU-DESSUS de la boîte de dialogue
	# (layer=95). Impossible de lui donner directement un layer différent
	# tant qu'il reste un enfant de Root, et un CanvasLayer imbriqué dans un
	# autre CanvasLayer ne s'affiche pas (piège déjà rencontré ailleurs) —
	# donc on le ressort dans son propre CanvasLayer, ajouté à la racine du
	# Viewport comme la boîte de dialogue elle-même. reparent() garde ses
	# anchors intactes (toujours relatives au Viewport, même chemin que
	# n'importe quel Control posé directement sous un CanvasLayer ailleurs
	# dans le projet).
	_action_layer = CanvasLayer.new()
	_action_layer.layer = 96
	get_tree().root.add_child(_action_layer)
	_action_window.reparent(_action_layer)
	_action_window.visible = false

	await _run_battle_loop()

func _build_side(entries: Array, is_player: bool, trainer_name: String) -> BattleSide:
	var side := BattleSide.new()
	side.is_player = is_player
	side.trainer_name = trainer_name
	for e in entries:
		var moves: Array[String] = []
		for m in e["moves"]:
			moves.append(String(m))
		# "gender" absent (ex. npc_yohan_zone3.gd, qui ne passe pas encore
		# par battle_intro.gd) -> create() tire au sort lui-même. Présent
		# (voir TrainerData.roll_genders()) -> réutilisé tel quel, pour
		# rester cohérent avec ce que l'intro a déjà affiché.
		var gender := String(e.get("gender", ""))
		side.party.append(BattlePokemon.create(String(e["species"]), int(e["level"]), moves, gender))
	return side

# --- Rafraîchissement visuel ---

func _refresh_sprites() -> void:
	var enemy: BattlePokemon = enemy_side.active()
	var enemy_path := "res://assets/pokemon/%s/front.png" % enemy.species_key
	if ResourceLoader.exists(enemy_path):
		_enemy_sprite.texture = load(enemy_path)

	# Dos du Pokémon du joueur (pas le sprite du dresseur, qui n'apparaît pas
	# en combat) — même dossier que les sprites de face utilisés partout
	# ailleurs (assets/pokemon/<espèce>/back.png).
	var player: BattlePokemon = player_side.active()
	var player_path := "res://assets/pokemon/%s/back.png" % player.species_key
	if ResourceLoader.exists(player_path):
		_player_sprite.texture = load(player_path)

# Symboles ♂/♀ (U+2642/U+2640, déjà dans dialogue_latin.fnt). Couleurs façon
# vrai jeu — mêmes valeurs que battle_intro.gd (GENDER_MALE_COLOR/
# GENDER_FEMALE_COLOR), à garder synchronisées.
const GENDER_MALE_COLOR := Color(0.2, 0.501961, 0.976471)
const GENDER_FEMALE_COLOR := Color(0.976471, 0.211765, 0.501961)

# Un shader "silhouette" (même technique que le Pokémon à sa sortie de
# balle, voir battle_intro.gd) rendait le symbole quasi invisible sur un
# Label — le rendu de texte de Godot ne passe pas par le même chemin qu'un
# simple TextureRect. Retour à font_color, avec des couleurs volontairement
# vives/saturées (pas pastel) : le glyphe garde un contour gris foncé qui
# reste sombre une fois teinté, une couleur vive limite ce résidu à un
# simple liseré au lieu de noyer tout le symbole.
func _set_gender_label(label: Label, gender: String) -> void:
	if gender == "male":
		label.text = " ♂"
		label.add_theme_color_override("font_color", GENDER_MALE_COLOR)
	elif gender == "female":
		label.text = " ♀"
		label.add_theme_color_override("font_color", GENDER_FEMALE_COLOR)
	else:
		label.text = ""

func _refresh_health_display(animate: bool = false) -> void:
	var enemy: BattlePokemon = enemy_side.active()
	var player: BattlePokemon = player_side.active()
	_enemy_name_label.text = enemy.display_name
	_set_gender_label(_enemy_gender_label, enemy.gender)
	_enemy_level_label.text = "N.%d" % enemy.level
	_player_name_label.text = player.display_name
	_set_gender_label(_player_gender_label, player.gender)
	_player_level_label.text = "N.%d" % player.level
	_player_hp_label.text = "%d/%d" % [player.current_hp, player.max_hp]
	_enemy_hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
	_set_hp_bar(_enemy_hp_fill, enemy, animate)
	_set_hp_bar(_player_hp_fill, player, animate)

func _set_hp_bar(fill: ColorRect, pkm: BattlePokemon, animate: bool) -> void:
	var ratio: float = float(pkm.current_hp) / float(pkm.max_hp) if pkm.max_hp > 0 else 0.0
	var target := Vector2(maxf(ratio, 0.0), 1.0)
	fill.pivot_offset = Vector2.ZERO
	if animate:
		var tw := create_tween()
		tw.tween_property(fill, "scale", target, 0.3)
	else:
		fill.scale = target
	fill.color = Color(0.45098, 1, 0.67451, 1) if ratio > 0.2 else Color(1.0, 0.4, 0.35, 1.0)

# Ouvre (ou remplace) la boîte de dialogue "Que doit faire X ?" en arrière-
# plan et affiche le menu d'action par-dessus.
func _open_prompt(text: String) -> void:
	_close_prompt()
	_prompt_dialogue = DialogueBoxScene.instantiate()
	_prompt_dialogue.style = "battle"
	# Racine du Viewport, pas current_scene : ce dernier peut lui-même être un
	# CanvasLayer (ex. title_screen.gd, voir Tests > Tester un combat), et un
	# CanvasLayer sous un autre CanvasLayer ne s'affiche pas (piège déjà
	# rencontré, voir battle_intro.gd et title_screen.gd::_open_slots()).
	get_tree().root.add_child(_prompt_dialogue)
	var lines: Array[String] = [text]
	_prompt_dialogue.say(lines)
	await _prompt_dialogue.page_typed
	_prompt_dialogue.active = false
	_action_window.visible = true

func _close_prompt() -> void:
	_action_window.visible = false
	if _prompt_dialogue != null:
		_prompt_dialogue.queue_free()
		_prompt_dialogue = null

# --- Boucle de combat ---

func _run_battle_loop() -> void:
	while true:
		_turn_number += 1
		if pre_turn_hook.is_valid():
			await pre_turn_hook.call(_turn_number)

		var player_action := await _prompt_player_action()
		_close_prompt()
		var enemy_action := engine.choose_ai_action()
		var events := engine.resolve_turn(player_action, enemy_action)
		var result := await _play_events(events)
		if result != "":
			_finish(result)
			return

		if enemy_side.active().is_fainted():
			engine.auto_switch_enemy_if_fainted()
			if enemy_side.active_index >= 0 and not enemy_side.active().is_fainted():
				await _say(["%s envoie %s !" % [enemy_side.trainer_name, enemy_side.active().display_name]])
				_refresh_sprites()
				_refresh_health_display()

		if player_side.active().is_fainted() and player_side.has_alive():
			await _open_prompt("Choisis le prochain Pokémon.")
			var idx := await _prompt_switch(true)
			_close_prompt()
			engine.resolve_turn({"kind": "switch", "index": idx}, {"kind": "switch", "index": player_side.active_index})
			_refresh_sprites()
			_refresh_health_display()

func _finish(result: String) -> void:
	finished.emit(result)
	# _action_layer n'est PAS un enfant de ce CanvasLayer (ajouté directement
	# à la racine du Viewport, voir _ready()) : il ne serait donc jamais
	# libéré automatiquement par le queue_free() ci-dessous.
	if _action_layer != null:
		_action_layer.queue_free()
	queue_free()

# Rejoue les évènements un par un ; retourne "win"/"lose" si le combat vient
# de se terminer, "" sinon.
func _play_events(events: Array[Dictionary]) -> String:
	for ev in events:
		match String(ev["type"]):
			"switch":
				_refresh_sprites()
				_refresh_health_display()
			"move_used":
				await _say(["%s utilise %s !" % [String(ev["pokemon"]), String(ev["move"])]])
			"message":
				await _say([String(ev["text"])])
			"hp_changed":
				_refresh_health_display(true)
				await get_tree().create_timer(0.3).timeout
			"status":
				await _say(["%s est brûlé !" % String(ev["pokemon"])])
			"weather_changed":
				if String(ev["weather"]) == "RAIN":
					await _say(["Le temps se met à changer... il commence à pleuvoir !"])
				else:
					await _say(["La pluie s'arrête."])
			"pokemon_fainted":
				await _say(["%s est mis K.O. !" % String(ev["pokemon"])])
			"battle_ended":
				return String(ev["result"])
	return ""

func _say(lines: Array[String]) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	dialogue.style = "battle"
	get_tree().root.add_child(dialogue)
	# force_arrow=true : un message de combat n'est jamais vraiment "la fin"
	# (le tour continue, ou le menu réapparaît juste après) — sans ça la
	# flèche de continuation ne s'affiche pas sur un message d'une seule
	# ligne, alors qu'une action du joueur est bien attendue (signalé par
	# Gus). Voir dialogue_box.gd::say().
	dialogue.say(lines, -1, 0.0, true)
	await dialogue.finished
	dialogue.queue_free()

# --- Menus ---

func _clear_menu() -> void:
	for c in _menu_container.get_children():
		c.queue_free()

# Retourne {"kind": "attack", "move_key": ...} ou {"kind": "switch", "index": ...}.
# Boucle sur le menu principal tant que le joueur annule un sous-menu (choix
# de capacité ou de Pokémon) ou choisit Sac/Fuite (refusés, message puis
# retour au menu), plutôt qu'un enchaînement de signaux à sens unique qui
# laisserait un menu vide en cas d'annulation.
func _prompt_player_action() -> Dictionary:
	# false seulement juste après une annulation du choix de capacité (voir
	# plus bas) : _prompt_move_choice() a déjà rendu l'ancienne boîte "Que
	# doit faire X ?" visible telle quelle (texte déjà tapé), pas besoin de
	# la redétruire/retaper via _open_prompt() dans ce cas précis (signalé
	# par Gus).
	var need_new_prompt := true
	while true:
		if need_new_prompt:
			await _open_prompt("Que doit faire %s ?" % player_side.active().display_name)
		need_new_prompt = true
		_clear_menu()

		var grid := GridContainer.new()
		grid.columns = 2
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 2)
		var attack_btn := _menu_button("ATTAQUE")
		var bag_btn := _menu_button("SAC")
		var switch_btn := _menu_button("POKÉMON")
		var run_btn := _menu_button("FUITE")
		for b in [attack_btn, bag_btn, switch_btn, run_btn]:
			grid.add_child(b)
		_menu_container.add_child(grid)
		attack_btn.grab_focus()

		attack_btn.pressed.connect(func(): _choice_made.emit(0))
		bag_btn.pressed.connect(func(): _choice_made.emit(1))
		switch_btn.pressed.connect(func(): _choice_made.emit(2))
		run_btn.pressed.connect(func(): _choice_made.emit(3))
		var choice: int = await _choice_made

		match choice:
			0:
				var move_key := await _prompt_move_choice()
				if move_key != "":
					return {"kind": "attack", "move_key": move_key}
				need_new_prompt = false
			1:
				_close_prompt()
				await _say(["Impossible d'utiliser un objet en combat officiel !"])
			2:
				var idx := await _prompt_switch(false)
				if idx >= 0:
					return {"kind": "switch", "index": idx}
			3:
				_close_prompt()
				await _say(["Tu ne peux pas fuir un combat de dresseur !"])
		# Sous-menu annulé, ou Sac/Fuite refusés : on reboucle et réaffiche le menu.
	return {}   # inatteignable (while true ne sort que par un return ci-dessus), pour l'analyseur statique

# Chaîne vide = le joueur a annulé (bouton "Retour").
# Fidèle au vrai jeu (voir Gus) : la boîte "Que doit faire X ?" est
# remplacée par une grille 2x2 des capacités (tiret dans les emplacements
# vides s'il y en a moins de 4), tandis que la fenêtre d'action garde ses
# dimensions mais affiche PP/Type de la capacité survolée au lieu des
# boutons. Annulation à ui_cancel (pas de bouton RETOUR : plus de place
# dans une grille 2x2 pleine, fidèle au vrai jeu qui utilise le bouton B).
func _prompt_move_choice() -> String:
	if _prompt_dialogue != null:
		_prompt_dialogue.visible = false

	var move_box := _make_move_list_box()
	var grid: GridContainer = move_box.get_child(0)

	_clear_menu()
	# Taille plus grande que la valeur par défaut de _info_label()/_menu_button()
	# (utilisées ailleurs par le menu principal et le choix de Pokémon) : il
	# restait de la place, à tester (voir Gus).
	var pp_label := _info_label(28)
	# Type + catégorie combinés sur une seule ligne ("Eau / Spéciale") plutôt
	# que 2 lignes séparées avec un préfixe ("TYPE/EAU" + "Spéciale") — sans
	# ambiguïté pour qui connaît un peu Pokémon, et évite l'incohérence de
	# casse relevée par Gus (tout en minuscules sauf PP, comme le reste du
	# menu).
	var type_category_label := _info_label(28)
	var info_box := VBoxContainer.new()
	info_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_box.add_theme_constant_override("separation", 8)
	info_box.add_child(pp_label)
	info_box.add_child(type_category_label)
	_menu_container.add_child(info_box)

	var moves: Array[Dictionary] = player_side.active().moves
	var first: Button = null
	for i in range(4):
		if i < moves.size():
			var mv: Dictionary = moves[i]
			var key: String = String(mv["key"])
			var move: Dictionary = MoveData.MOVES[key]
			var btn := _menu_button(String(move["name"]), 28)
			var pp_text := "PP  %d/%d" % [int(mv["pp_current"]), int(mv["pp_max"])]
			var type_name: String = FRENCH_TYPE_NAMES.get(String(move["type"]), String(move["type"]))
			var category_name: String = FRENCH_CATEGORY_NAMES.get(String(move["category"]), String(move["category"]))
			var type_category_text := "%s / %s" % [type_name, category_name]
			btn.focus_entered.connect(func():
				pp_label.text = pp_text
				type_category_label.text = type_category_text
			)
			btn.pressed.connect(func(): _choice_made.emit(key))
			grid.add_child(btn)
			if first == null:
				first = btn
				pp_label.text = pp_text
				type_category_label.text = type_category_text
		else:
			var empty_btn := _menu_button("-", 28)
			empty_btn.disabled = true
			# disabled=true seul n'empêche ni la navigation clavier/manette
			# (les flèches peuvent quand même s'y arrêter) ni le survol
			# souris (mouse_entered déclenche quand même grab_focus() dans
			# _menu_button()) — FOCUS_NONE coupe les deux, aucune flèche ne
			# doit apparaître sur un emplacement vide.
			empty_btn.focus_mode = Control.FOCUS_NONE
			grid.add_child(empty_btn)

	_switch_cancel_enabled = true
	if first:
		first.grab_focus()
	var chosen: Variant = await _choice_made
	_switch_cancel_enabled = false
	move_box.queue_free()
	_clear_menu()
	if _prompt_dialogue != null:
		_prompt_dialogue.visible = true
	return "" if chosen == -1 else String(chosen)

# Même fenêtre/style que _action_window (même StyleBox, même thème), même
# hauteur qu'elle (lue dynamiquement plutôt que dupliquée en constante — si
# Gus retouche encore les dimensions de _action_window, celle-ci reste
# calée dessus automatiquement), positionnée à gauche à la place de la
# boîte de dialogue masquée. Dimensions volontairement identiques à
# _action_window (déjà validées, ne plus y toucher) : le sprite/la
# plateforme du joueur qui dépassaient par-dessus (voir Gus) sont masqués
# à la place, voir _prompt_move_choice().
func _make_move_list_box() -> PanelContainer:
	var box := PanelContainer.new()
	box.theme = _action_window.theme
	box.add_theme_stylebox_override("panel", _action_window.get_theme_stylebox("panel"))
	_action_layer.add_child(box)
	box.anchor_left = 0.02
	box.anchor_top = _action_window.anchor_top
	box.anchor_right = _action_window.anchor_left - 0.02
	box.anchor_bottom = _action_window.anchor_bottom
	box.offset_left = 0.0
	box.offset_top = 0.0
	box.offset_right = 0.0
	box.offset_bottom = 0.0

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	return box

func _info_label(font_size: int = 20) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", DialogueFont)
	label.add_theme_font_size_override("font_size", font_size)
	return label

# forced == true : K.O., pas d'annulation possible. forced == false : choix
# libre depuis le menu principal, Échap annule (retourne -1). Écran dédié
# (maquette validée par Gus, voir la conversation de conception) plutôt que
# les anciens boutons texte empilés : carte du Pokémon actif à gauche, les
# autres emplacements de l'équipe à droite.
func _prompt_switch(forced: bool) -> int:
	_clear_menu()
	if _prompt_dialogue != null:
		_prompt_dialogue.visible = false

	var sel := PartySelect.new()
	sel.party = player_side.party
	sel.active_index = player_side.active_index
	sel.forced = forced
	get_tree().root.add_child(sel)
	var idx: int = await sel.pick()
	sel.queue_free()

	if _prompt_dialogue != null:
		_prompt_dialogue.visible = true
	return idx

func _unhandled_input(event: InputEvent) -> void:
	if _switch_cancel_enabled and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_choice_made.emit(-1)

func _menu_button(text: String, font_size: int = 22) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 32)
	# EXPAND_FILL sur les 2 axes : chaque bouton occupe tout son quart de la
	# grille 2x2 (voir Gus) plutôt que sa seule taille minimale — la GridContainer
	# elle-même est ancrée sur tout _menu_container, voir _prompt_player_action().
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", DialogueFont)
	btn.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, _empty_button_style)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.icon = BlankTexture
	btn.mouse_entered.connect(func(): btn.grab_focus())
	btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
	btn.focus_exited.connect(func(): btn.icon = BlankTexture)
	return btn
