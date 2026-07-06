extends CanvasLayer

# Écran-titre. Remplace intro.tscn comme point d'entrée du jeu (voir
# project.godot, run/main_scene). "Tests" est un bouton placeholder pour
# l'instant (voir FLOW.md, section 1) — sa fonction sera définie plus tard.

const SaveSlotsScene := preload("res://scenes/ui/save_slots.tscn")
const NEW_GAME_MAP := "res://scenes/intro/intro.tscn"

@onready var buttons_window: Control = $Root/Center

var slots_screen: Node = null

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
