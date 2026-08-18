extends CanvasLayer

# Écran-titre. Remplace intro.tscn comme point d'entrée du jeu (voir
# project.godot, run/main_scene). "Tests" ouvre un petit menu de tests
# techniques (pour l'instant : essayer un sprite custom en jeu, voir
# _on_tests_pressed()) — sans lien avec une vraie partie/sauvegarde.

const SaveSlotsScene := preload("res://scenes/ui/save_slots.tscn")
const ListPickerScene := preload("res://scenes/ui/list_picker.tscn")
const TrainerBattleScene := preload("res://scenes/ui/trainer_battle.tscn")
const DuoBattleScene := preload("res://scenes/ui/duo_battle.tscn")
const NEW_GAME_MAP := "res://scenes/intro/intro.tscn"
const TEST_SPRITES_ROOM := "res://scenes/maps/test_sprites_room.tscn"
const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

@onready var buttons_window: Control = $Root/Center

var slots_screen: Node = null

func _ready() -> void:
	# Reprend le fondu (ScreenFade autoload) si l'écran-titre est atteint via
	# un fondu sortant (ex. "Quitter" du menu pause) — sans ça l'écran reste
	# noir, rien d'autre n'appelle fade_in() ici (contrairement aux cartes, où
	# c'est player.gd::_load_world() qui s'en charge). Sans effet si l'alpha
	# est déjà à 0 (démarrage normal du jeu).
	ScreenFade.fade_in()

	# Flèche affichée dans un TextureRect dédié (pas Button.icon) : Button
	# centre son texte uniquement dans l'espace restant après l'icône, ce qui
	# décale visuellement le texte vers la droite (marges gauche/droite
	# inégales, signalé par Gus). Ici la flèche et un espaceur invisible de
	# même largeur encadrent le Label au sein d'un HBoxContainer, donc le
	# texte reste centré au milieu du bouton, marges symétriques.
	# Le survol souris déplace le focus clavier au lieu de gérer sa propre
	# flèche (même principe que partout ailleurs dans le jeu) : focus par
	# défaut sur "Nouvelle partie", jouable au clavier direct sans souris.
	var first_button: Button = null
	for btn in $Root/Center/Window/Buttons.get_children():
		if btn is Button:
			var icon: TextureRect = btn.get_node("Content/Icon")
			icon.texture = BlankTexture
			btn.mouse_entered.connect(func(): btn.grab_focus())
			btn.focus_entered.connect(func(): icon.texture = ArrowTexture)
			btn.focus_exited.connect(func(): icon.texture = BlankTexture)
			if first_button == null:
				first_button = btn
	if first_button:
		first_button.grab_focus()

func _on_new_game_pressed() -> void:
	# Pas besoin de faire choisir un slot pour une nouvelle partie : on prend
	# silencieusement le premier libre et on file directement dans le jeu.
	# L'écran de slots ne sert alors que si les 3 sont déjà pris (il faut en
	# libérer un avant de pouvoir commencer).
	var slot := SaveManager.first_empty_slot()
	if slot == -1:
		_open_slots("new")
	else:
		_on_new_game_chosen(slot)

func _on_load_game_pressed() -> void:
	_open_slots("load")

func _on_tests_pressed() -> void:
	var picker := ListPickerScene.instantiate()
	get_tree().root.add_child(picker)
	picker.setup([
		{"label": "Tester des sprites", "value": "sprites"},
		{"label": "Tester un combat contre un dresseur", "value": "battle"},
		{"label": "Tester un combat duo", "value": "duo_battle"},
		{"label": "Annuler", "value": null},
	])
	var choice = await picker.chosen
	picker.queue_free()
	if choice == "sprites":
		await _open_sprite_test_menu()
	elif choice == "battle":
		await _open_trainer_battle_test()
	elif choice == "duo_battle":
		await _open_duo_battle_test()

# Un item par sprite custom testable (voir assets/characters/custom/) — pas
# une vraie partie : on saute directement sur la carte de test avec le
# personnage en apparence Red par défaut (voir Gus, décidé le jour de l'ajout
# de Cartman), sans passer par la création de perso ni une sauvegarde.
func _open_sprite_test_menu() -> void:
	var picker := ListPickerScene.instantiate()
	get_tree().root.add_child(picker)
	picker.setup([
		{"label": "Tester PNJ Cartman", "value": "cartman"},
		{"label": "Annuler", "value": null},
	])
	var choice = await picker.chosen
	picker.queue_free()
	if choice != null:
		PlayerData.appearance = "red_normal"
		PlayerData.gender = "male"
		PlayerData.player_name = "Red"
		get_tree().change_scene_to_file(TEST_SPRITES_ROOM)

# Lance directement l'écran de combat dresseur (Yohan zone 3, seul combat
# scripté à ce jour, voir trainer_data.gd) sans passer par la carte/le PNJ —
# pour itérer vite sur l'UI de combat elle-même (voir la conversation de
# conception). "brock" est un portrait de combat provisoire (aucun sprite de
# combat pour Yohan n'existe encore, voir assets/characters/custom/battle/) :
# à remplacer dès qu'un vrai sprite existe, `enemy_sprite_key` est fait pour
# ça.
func _open_trainer_battle_test() -> void:
	PlayerData.appearance = "red_normal"
	PlayerData.gender = "male"
	PlayerData.player_name = "Red"

	var trainer: Dictionary = TrainerData.TRAINERS["YOHAN_ZONE3"]
	# Sexe tiré une seule fois ici, transmis tel quel à l'intro ET à l'écran
	# de combat (voir TrainerData.roll_genders()) — sinon chacun tirerait le
	# sien indépendamment et pourrait afficher 2 sexes différents pour le
	# même Pokémon.
	var enemy_team: Array = TrainerData.roll_genders(trainer["party"])
	var player_team: Array = TrainerData.roll_genders(TrainerData.PLAYER_LOAN_TEAM)

	var intro := BattleIntro.new()
	intro.enemy_trainer_name = String(trainer["name"])
	intro.enemy_sprite_key = "brock"
	intro.enemy_party = enemy_team
	intro.player_party = player_team
	get_tree().root.add_child(intro)
	await intro.play()
	intro.queue_free()

	var battle := TrainerBattleScene.instantiate()
	battle.player_entries = player_team
	battle.enemy_entries = enemy_team
	battle.enemy_trainer_name = String(trainer["name"])
	get_tree().root.add_child(battle)
	await battle.finished

# Lance directement l'écran de combat duo (2v2, 4 dresseurs — voir la
# conversation de conception, futur contenu zone 4 Parc Safari) sur des
# données PROVISOIRES (TrainerData.DUO_TEST, voir son en-tête) : un banc
# d'essai pour valider le moteur/l'écran avant de construire le vrai contenu
# (noms/équipes réels de l'allié et du rival pas encore décidés).
func _open_duo_battle_test() -> void:
	PlayerData.appearance = "red_normal"
	PlayerData.gender = "male"
	PlayerData.player_name = "Red"

	var duo: Dictionary = TrainerData.DUO_TEST
	var player_team: Array = TrainerData.roll_genders(TrainerData.PLAYER_LOAN_TEAM)
	var ally_team: Array = TrainerData.roll_genders(duo["ally_party"])
	var enemy1_team: Array = TrainerData.roll_genders(duo["enemy1_party"])
	var enemy2_team: Array = TrainerData.roll_genders(duo["enemy2_party"])

	var intro := BattleIntroDuo.new()
	intro.player_party = player_team
	intro.ally_party = ally_team
	intro.ally_trainer_name = String(duo["ally_name"])
	intro.ally_sprite_key = String(duo["ally_sprite_key"])
	intro.enemy1_party = enemy1_team
	intro.enemy1_trainer_name = String(duo["enemy1_name"])
	intro.enemy1_sprite_key = String(duo["enemy1_sprite_key"])
	intro.enemy2_party = enemy2_team
	intro.enemy2_trainer_name = String(duo["enemy2_name"])
	intro.enemy2_sprite_key = String(duo["enemy2_sprite_key"])
	get_tree().root.add_child(intro)
	await intro.play()
	intro.queue_free()

	var battle := DuoBattleScene.instantiate()
	battle.player_entries = player_team
	battle.ally_entries = ally_team
	battle.ally_trainer_name = String(duo["ally_name"])
	battle.enemy1_entries = enemy1_team
	battle.enemy1_trainer_name = String(duo["enemy1_name"])
	battle.enemy2_entries = enemy2_team
	battle.enemy2_trainer_name = String(duo["enemy2_name"])
	get_tree().root.add_child(battle)
	await battle.finished

func _open_slots(mode: String) -> void:
	if slots_screen != null:
		return
	slots_screen = SaveSlotsScene.instantiate()
	slots_screen.mode = mode
	# Piège Godot : un CanvasLayer ajouté comme enfant d'un AUTRE CanvasLayer
	# ne s'affiche pas (contrairement à un CanvasLayer ajouté à la racine
	# d'une scène Node2D classique, le pattern utilisé partout ailleurs dans
	# le jeu — dialogue_box, menus de choix, bandeau de lieu). Ici la "scène
	# courante" EST elle-même un CanvasLayer (title_screen), donc on ajoute
	# explicitement à la racine de l'arbre (le Viewport) plutôt qu'à `self`.
	get_tree().root.add_child(slots_screen)
	buttons_window.visible = false
	slots_screen.back_pressed.connect(_close_slots)
	if mode == "new":
		slots_screen.new_game_chosen.connect(_on_new_game_chosen)

func _close_slots() -> void:
	if slots_screen != null:
		slots_screen.queue_free()
		slots_screen = null
	buttons_window.visible = true

func _on_new_game_chosen(slot: int) -> void:
	_close_slots()
	SaveManager.current_slot = slot
	SaveManager.play_seconds = 0.0
	# Les raccourcis objets suivent la sauvegarde, pas l'installation (voir
	# scripts/key_bindings.gd) — une partie qui vient de démarrer n'en garde
	# aucun, même si PlayerData retient encore ceux d'une partie précédente
	# chargée plus tôt dans cette session.
	KeyBindings.reset_to_defaults()
	get_tree().change_scene_to_file(NEW_GAME_MAP)
