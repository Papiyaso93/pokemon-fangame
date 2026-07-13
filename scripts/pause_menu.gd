extends CanvasLayer

# Mini-menu pause (Start), minimal pour l'instant : seulement Sauvegarder et
# Reprendre. Le vrai menu FRLG (Pokédex/Pokémon/Sac/Dresseur/Options/Sortie)
# viendra plus tard, au fur et à mesure que ces systèmes existeront.

signal closed

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const YesNoChoiceScene := preload("res://scenes/ui/yes_no_choice.tscn")
const SaveSlotsScene := preload("res://scenes/ui/save_slots.tscn")
const RegionMapScene := preload("res://scenes/ui/region_map.tscn")
const BagScene := preload("res://scenes/ui/bag.tscn")

@onready var window: PanelContainer = $Root/Window
@onready var quit_button: Button = $Root/Window/Buttons/Quit

var slots_screen: Node = null
var region_map: Node = null
var bag: Node = null
var first_button: Button = null

func _ready() -> void:
	window.visible = false
	for btn in window.get_node("Buttons").get_children():
		if btn is Button:
			btn.icon = BlankTexture
			# Le survol souris déplace le focus clavier au lieu de gérer sa propre
			# flèche : sinon 2 flèches peuvent s'afficher à la fois (une au
			# clavier, une à la souris) si elles ne pointent pas le même bouton.
			btn.mouse_entered.connect(func(): btn.grab_focus())
			btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
			btn.focus_exited.connect(func(): btn.icon = BlankTexture)
			if first_button == null:
				first_button = btn
	await get_tree().process_frame
	_place_window()
	window.visible = true
	# Focus par défaut sur la première option (voir yes_no_choice.gd) :
	# jouable au clavier direct sans passer par la souris.
	if first_button:
		first_button.grab_focus()

func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport().get_visible_rect().size
	window.position = (viewport_size - min_size) / 2.0

# Échap referme le menu comme "Reprendre" — seulement quand la liste
# principale est affichée : les sous-écrans (Sac/Carte/Sauvegarde) gèrent
# déjà eux-mêmes leur propre Échap (voir bag.gd, region_map.gd, save_slots.gd)
# et redeviennent visibles via leurs signaux respectifs, donc rien à faire ici
# tant que `window` n'est pas celui qui est montré.
func _unhandled_input(event: InputEvent) -> void:
	if window.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

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
	if first_button:
		first_button.grab_focus()

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
	if first_button:
		first_button.grab_focus()

# Entrée "test" (voir HANDOFF.md) : même piège CanvasLayer imbriqué que
# _on_save_pressed()/_on_map_pressed() ci-dessus.
func _on_bag_pressed() -> void:
	bag = BagScene.instantiate()
	get_tree().root.add_child(bag)
	window.visible = false
	bag.closed.connect(_on_bag_closed)
	bag.item_used.connect(_on_bag_item_used)

func _on_bag_closed() -> void:
	bag = null
	window.visible = true
	if first_button:
		first_button.grab_focus()

# Un objet consommable vient d'être utilisé pour de vrai (voir bag.gd,
# item_used) : on ne revient pas sur ce menu, on ferme tout d'un coup jusqu'au
# jeu directement — pas de raison de repasser par le menu pause juste après.
func _on_bag_item_used() -> void:
	bag = null
	closed.emit()

# Retour à l'écran-titre, fondu noir comme un warp normal (pas de sauvegarde
# automatique — si le joueur veut garder sa progression, il doit sauvegarder
# avant). Demande confirmation d'abord (misclick facile depuis "Reprendre" ou
# "Sauvegarder" juste au-dessus) — focus par défaut sur "Non" pour qu'un appui
# rapide et habituel sur la touche d'action ne valide pas "Oui" par réflexe.
# Pas d'appel à `closed` si confirmé : la scène change entièrement, `player.gd`
# (et ce menu avec) sera libéré avec le reste de la carte.
func _on_quit_pressed() -> void:
	window.visible = false
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().root.add_child(dialogue)
	var lines: Array[String] = ["Veux-tu vraiment quitter ? Toute progression non sauvegardée sera perdue."]
	dialogue.say(lines)
	await dialogue.page_typed
	dialogue.active = false

	var choice := YesNoChoiceScene.instantiate()
	choice.default_focus_index = 1
	get_tree().root.add_child(choice)
	var confirmed: bool = await choice.chosen
	choice.queue_free()
	dialogue.queue_free()

	if confirmed:
		await ScreenFade.fade_out()
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
	else:
		window.visible = true
		quit_button.grab_focus()
