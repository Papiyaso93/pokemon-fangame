extends CanvasLayer

# Écran-titre. Remplace intro.tscn comme point d'entrée du jeu (voir
# project.godot, run/main_scene). "Tests" est un bouton placeholder pour
# l'instant (voir FLOW.md, section 1) — sa fonction sera définie plus tard.

const SaveSlotsScene := preload("res://scenes/ui/save_slots.tscn")
const NEW_GAME_MAP := "res://scenes/intro/intro.tscn"
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
	pass   # à définir plus tard (FLOW.md, section 1)

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
	get_tree().change_scene_to_file(NEW_GAME_MAP)
