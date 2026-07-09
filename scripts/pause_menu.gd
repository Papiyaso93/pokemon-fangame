extends CanvasLayer

# Mini-menu pause (Start), minimal pour l'instant : seulement Sauvegarder et
# Reprendre. Le vrai menu FRLG (Pokédex/Pokémon/Sac/Dresseur/Options/Sortie)
# viendra plus tard, au fur et à mesure que ces systèmes existeront.

signal closed

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const SaveSlotsScene := preload("res://scenes/ui/save_slots.tscn")
const RegionMapScene := preload("res://scenes/ui/region_map.tscn")

@onready var window: PanelContainer = $Root/Window

var slots_screen: Node = null
var region_map: Node = null

func _ready() -> void:
	window.visible = false
	for btn in window.get_node("Buttons").get_children():
		if btn is Button:
			btn.icon = BlankTexture
			btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
			btn.mouse_exited.connect(func(): btn.icon = BlankTexture)
	await get_tree().process_frame
	_place_window()
	window.visible = true

func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport().get_visible_rect().size
	window.position = (viewport_size - min_size) / 2.0

func _on_save_pressed() -> void:
	# Le joueur choisit délibérément le slot (écraser une sauvegarde
	# existante ou en remplir une nouvelle), plutôt que d'écrire
	# silencieusement sur le slot de la partie en cours.
	slots_screen = SaveSlotsScene.instantiate()
	slots_screen.mode = "save"
	# Ajouté à la racine du Viewport, pas à `self` : `self` est un CanvasLayer
	# et un CanvasLayer imbriqué dans un autre CanvasLayer ne s'affiche pas
	# (voir HANDOFF.md, piège rencontré sur title_screen.gd).
	get_tree().root.add_child(slots_screen)
	window.visible = false
	slots_screen.back_pressed.connect(_on_slots_back)
	slots_screen.slot_chosen.connect(_on_slot_chosen_for_save)

func _on_slots_back() -> void:
	if slots_screen != null:
		slots_screen.queue_free()
		slots_screen = null
	window.visible = true

func _on_slot_chosen_for_save(slot: int) -> void:
	SaveManager.save_to_slot(slot)
	if slots_screen != null:
		slots_screen.queue_free()
		slots_screen = null
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	var lines: Array[String] = ["Partie sauvegardée !"]
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()
	closed.emit()

func _on_resume_pressed() -> void:
	closed.emit()

# Entrée "test" (voir HANDOFF.md) : ajoutée à la racine du Viewport, pas à
# `self`, même piège que _on_save_pressed() (CanvasLayer imbriqué).
func _on_map_pressed() -> void:
	region_map = RegionMapScene.instantiate()
	get_tree().root.add_child(region_map)
	window.visible = false
	region_map.closed.connect(_on_region_map_closed)

func _on_region_map_closed() -> void:
	region_map = null
	window.visible = true

# Retour à l'écran-titre, fondu noir comme un warp normal (pas de sauvegarde
# automatique — si le joueur veut garder sa progression, il doit sauvegarder
# avant). Pas d'appel à `closed` : la scène change entièrement, `player.gd`
# (et ce menu avec) sera libéré avec le reste de la carte.
func _on_quit_pressed() -> void:
	window.visible = false
	await ScreenFade.fade_out()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
