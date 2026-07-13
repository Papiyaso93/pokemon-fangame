extends CanvasLayer

signal closed
signal item_used   # utiliser un objet consommable ferme tout (sac + appelant), voir _use_key_item()/_on_repel_pressed()

# Sac (test) — v1 volontairement vide : juste la navigation entre les 5
# poches (voir BagData), pas encore d'objets ni de vrai inventaire (cf.
# HANDOFF.md pour le topo complet du système FRLG réel). Gauche/Droite pour
# changer de poche (équivalent L/R du vrai jeu, qu'on n'a pas sur PC),
# Échap pour revenir — même principe que scripts/region_map.gd.

const TabDimAlpha := 0.5
const PokedexScreenScene := preload("res://scenes/ui/pokedex_screen.tscn")
const RegionMapScene := preload("res://scenes/ui/region_map.tscn")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const ListPickerScene := preload("res://scenes/ui/list_picker.tscn")
const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const ITEMS_POCKET_INDEX := 0       # cf. BagData.POCKETS — poche "Objets"
const KEY_ITEMS_POCKET_INDEX := 1   # cf. BagData.POCKETS — poche "Objets Rares"

# Libellé de l'action "utiliser" par objet rare (voir _on_key_item_selected) —
# le Vélo n'y est pas : son libellé dépend de l'état (monter/descendre),
# calculé à la volée. Surf/Canne utilisent le "Utiliser" par défaut (voir plus
# bas) : ça déclenche directement l'action, comme un raccourci (décidé le
# 13/07/2026 — plus de "outil actif", voir _use_key_item()).
const KEY_ITEM_USE_LABELS := {
	"pokedex": "Ouvrir",
	"map": "Ouvrir",
}

# Soulignement façon onglet de navigateur : une bordure basse pleine sur
# l'onglet actif, rien du tout sur les autres (pas juste une même bordure
# atténuée — Gus voulait vraiment "rien sous les onglets inactifs").
var _underline_style: StyleBoxFlat
var _no_underline_style: StyleBoxEmpty

@onready var root: Control = $Root
@onready var window_center: CenterContainer = $Root/Center
@onready var tabs_row: HBoxContainer = $Root/Center/Window/VBox/TabsRow
@onready var empty_label: Label = $Root/Center/Window/VBox/ContentArea/Center/EmptyLabel
@onready var item_list: VBoxContainer = $Root/Center/Window/VBox/ContentArea/Center/ItemList
@onready var pokedex_button: Button = $Root/Center/Window/VBox/ContentArea/Center/ItemList/PokedexButton
@onready var surf_button: Button = $Root/Center/Window/VBox/ContentArea/Center/ItemList/SurfButton
@onready var rod_button: Button = $Root/Center/Window/VBox/ContentArea/Center/ItemList/RodButton
@onready var repel_button: Button = $Root/Center/Window/VBox/ContentArea/Center/ItemList/RepelButton
@onready var bike_button: Button = $Root/Center/Window/VBox/ContentArea/Center/ItemList/BikeButton
@onready var map_button: Button = $Root/Center/Window/VBox/ContentArea/Center/ItemList/MapButton

var current_pocket := 0
var tab_buttons: Array[Button] = []
var pokedex_screen: Node = null
var region_map_screen: Node = null

func _ready() -> void:
	_underline_style = StyleBoxFlat.new()
	_underline_style.bg_color = Color(0, 0, 0, 0)
	_underline_style.border_width_bottom = 3
	# Les onglets sont sur le fond BLANC de square_window.png, pas le fond
	# marine de l'écran (piège vécu : un soulignement blanc y est invisible).
	# Même encre foncée que dialogue_latin.fnt (cf. HANDOFF.md).
	_underline_style.border_color = Color(56.0 / 255.0, 56.0 / 255.0, 56.0 / 255.0, 1)
	_underline_style.content_margin_left = 10.0
	_underline_style.content_margin_right = 10.0
	_underline_style.content_margin_top = 6.0
	_underline_style.content_margin_bottom = 6.0
	_no_underline_style = StyleBoxEmpty.new()
	_no_underline_style.content_margin_left = 10.0
	_no_underline_style.content_margin_right = 10.0
	_no_underline_style.content_margin_top = 6.0
	_no_underline_style.content_margin_bottom = 6.0

	# Onglets construits depuis BagData.POCKETS (pas codés en dur dans la
	# scène) : une seule source de vérité pour les noms de poche.
	for i in BagData.POCKETS.size():
		var btn := Button.new()
		btn.text = BagData.POCKETS[i]["label"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tabs_row.add_child(btn)
		tab_buttons.append(btn)

	repel_button.pressed.connect(_on_repel_pressed)
	pokedex_button.pressed.connect(_on_key_item_selected.bind("pokedex"))
	surf_button.pressed.connect(_on_key_item_selected.bind("surf"))
	rod_button.pressed.connect(_on_key_item_selected.bind("rod"))
	bike_button.pressed.connect(_on_key_item_selected.bind("bike"))
	map_button.pressed.connect(_on_key_item_selected.bind("map"))

	# Pointeur clavier par défaut sur les entrées d'objets (voir
	# _update_item_focus_visuals) : même survol-souris-déplace-le-focus que
	# partout ailleurs, pour n'avoir jamais deux flèches affichées à la fois.
	for btn in [pokedex_button, surf_button, rod_button, repel_button, bike_button, map_button]:
		btn.icon = BlankTexture
		btn.mouse_entered.connect(func(): btn.grab_focus())
		btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
		btn.focus_exited.connect(func(): btn.icon = BlankTexture)

	_update_tabs()

func _on_tab_pressed(index: int) -> void:
	current_pocket = index
	_update_tabs()

func _update_tabs() -> void:
	for i in tab_buttons.size():
		var is_current := i == current_pocket
		tab_buttons[i].modulate.a = 1.0 if is_current else TabDimAlpha
		var style: StyleBox = _underline_style if is_current else _no_underline_style
		for state in ["normal", "hover", "pressed", "focus"]:
			tab_buttons[i].add_theme_stylebox_override(state, style)
	# Pas de vrai inventaire pour l'instant (v1 test) — seules exceptions : les
	# objets rares obtenus pendant l'acte 1 (Pokédex, Surf...) dans la poche
	# "Objets Rares", et le Répulsif (consommable, voir zone 3) dans la poche
	# "Objets" — affichés ici dès qu'on les a reçus (acte1-parc-safari.md).
	var in_key_pocket := current_pocket == KEY_ITEMS_POCKET_INDEX
	var in_items_pocket := current_pocket == ITEMS_POCKET_INDEX
	pokedex_button.visible = in_key_pocket and PlayerData.camille_zone1_done
	surf_button.visible = in_key_pocket and PlayerData.has_surf
	rod_button.visible = in_key_pocket and PlayerData.has_fishing_rod
	bike_button.visible = in_key_pocket and PlayerData.has_bike
	# Toujours "Vélo" (pas "Monter à vélo"/"Descendre du vélo") : cette
	# nuance vit maintenant dans le menu "Utiliser" qui s'affiche à la
	# sélection, voir _on_key_item_selected().
	# Carte de Kanto : pas encore de vrai flag narratif (voir
	# acte1-parc-safari.md, "pas encore câblée") — accès "test" toujours
	# disponible ici en attendant, comme avant dans le menu pause.
	map_button.visible = in_key_pocket
	repel_button.visible = in_items_pocket and PlayerData.repel_count > 0
	if repel_button.visible:
		repel_button.text = "Répulsif x%d" % PlayerData.repel_count
	var has_any_item := pokedex_button.visible or surf_button.visible or rod_button.visible or bike_button.visible or map_button.visible or repel_button.visible
	item_list.visible = (in_key_pocket or in_items_pocket) and has_any_item
	empty_label.visible = not item_list.visible

	# Focus clavier par défaut sur la première entrée visible de la poche
	# courante (recalculé à chaque changement de poche/état, la liste visible
	# n'étant pas figée).
	for btn in [pokedex_button, surf_button, rod_button, bike_button, map_button, repel_button]:
		if btn.visible:
			btn.grab_focus()
			break

# Répulsif : consommable, pas assignable à un raccourci (voir
# KeyBindings.ITEMS, décidé le 13/07/2026 — seuls les objets rares le sont)
# donc pas de menu Utiliser/Assigner, action directe comme avant. Un usage
# refusé (déjà actif/plus aucun) ne change rien, on reste dans le sac. Un
# usage réussi ferme tout d'un coup (sac + menu pause appelant) — voir
# item_used, géré par pause_menu.gd. État réel partagé avec player.gd
# (apply_repel_effect()), affichage local au sac pour garder le fond bleu
# visible derrière (voir _show_blocking_message).
func _on_repel_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var result: Dictionary = player.apply_repel_effect()
	await _show_blocking_message(String(result["message"]))
	if result["consumed"]:
		item_used.emit()
		queue_free()
	else:
		window_center.visible = true
		_update_tabs()

# Sélectionner un objet rare ouvre un petit menu "Utiliser"/"Assigner un
# raccourci" (comme Utiliser/Donner/Enregistrer dans le sac des vrais jeux
# Pokémon) plutôt que de déclencher l'action directement — nécessaire pour
# offrir l'assignation de raccourci sans dupliquer un bouton par ligne.
func _on_key_item_selected(item_key: String) -> void:
	var use_label: String
	if item_key == "bike":
		use_label = "Descendre du vélo" if PlayerData.is_biking else "Monter à vélo"
	else:
		use_label = String(KEY_ITEM_USE_LABELS.get(item_key, "Utiliser"))
	# Le menu du sac reste affiché derrière (pas de root.visible/window_center
	# masqué ici) : la fenêtre de choix se pose par-dessus, comme les autres
	# choix qui accompagnent un dialogue ailleurs dans le jeu.
	var picker := ListPickerScene.instantiate()
	get_tree().root.add_child(picker)
	picker.setup([
		{"label": use_label, "value": "use"},
		{"label": "Assigner un raccourci", "value": "assign"},
		{"label": "Annuler", "value": "cancel"},
	])
	var action = await picker.chosen
	picker.queue_free()
	match action:
		"use":
			await _use_key_item(item_key)
		"assign":
			await _assign_item_shortcut(item_key)
		_:
			_update_tabs()

# Vélo : bascule monter/descendre (pas de confirmation, contrairement au Surf
# qui demande "Tu veux surfer ?" — le vélo est réversible et sans risque),
# ferme tout d'un coup comme un objet consommable — voir item_used, géré par
# pause_menu.gd. Logique réelle partagée avec le raccourci clavier
# (player.gd::toggle_bike()). Pokédex/Carte : rouvrent l'écran existant, on
# reste dans le sac une fois refermés (comme avant cette fonctionnalité).
# Surf/Canne : déclenchent directement l'action (comme le raccourci clavier,
# voir player.gd::_use_shortcut_item()) — même contraintes de terrain (face à
# l'eau) qu'ailleurs, un refus affiche un message et laisse le sac ouvert.
func _use_key_item(item_key: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	match item_key:
		"bike":
			if not PlayerData.is_biking and player.is_indoors():
				await _show_blocking_message("Impossible de faire du vélo ici.")
				window_center.visible = true
				_update_tabs()
				return
			player.toggle_bike()
			item_used.emit()
			queue_free()
		"pokedex":
			_on_pokedex_pressed()
		"map":
			_on_map_pressed()
		"surf":
			if player.is_surfing:
				await _show_blocking_message("Tu surfes déjà.")
				window_center.visible = true
				_update_tabs()
				return
			if not player.can_use_surf_here():
				await _show_blocking_message("Il n'y a pas d'eau ici.")
				window_center.visible = true
				_update_tabs()
				return
			item_used.emit()
			queue_free()
			player.start_surfing_from_bag()
		"rod":
			if not player.can_use_rod_here():
				await _show_blocking_message("Il n'y a pas d'eau ici.")
				window_center.visible = true
				_update_tabs()
				return
			item_used.emit()
			queue_free()
			player.start_fishing_from_bag()

# Choix de la touche (1-4) à laquelle assigner cet objet — affiche l'objet
# déjà en place sur chaque touche, le cas échéant (voir KeyBindings.assign_item :
# le retire automatiquement de son ancien raccourci s'il en avait un).
func _assign_item_shortcut(item_key: String) -> void:
	var options := []
	for i in range(KeyBindings.SLOT_COUNT):
		var current_item: String = KeyBindings.slot_items[i]
		var label := 'Touche "%s"' % KeyBindings.key_label(i)
		if current_item != "":
			label += " — actuellement : %s" % String(KeyBindings.ITEMS.get(current_item, ""))
		options.append({"label": label, "value": i})
	options.append({"label": "Annuler", "value": null})
	var picker := ListPickerScene.instantiate()
	get_tree().root.add_child(picker)
	picker.setup(options)
	var slot = await picker.chosen
	picker.queue_free()
	if slot != null:
		KeyBindings.assign_item(int(slot), item_key)
		await _show_blocking_message('Raccourci assigné à la touche "%s" !' % KeyBindings.key_label(int(slot)))
	window_center.visible = true
	_update_tabs()

# Ne masque que la fenêtre (pas tout `root`) : le fond bleu du sac reste
# visible derrière le message, moins bizarre que de révéler le jeu par
# transparence — surtout que dans le cas "déjà actif" on revient dessus juste
# après (voir _on_repel_pressed()).
func _show_blocking_message(text: String) -> void:
	window_center.visible = false
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().root.add_child(dialogue)
	var lines: Array[String] = [text]
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()

func _on_pokedex_pressed() -> void:
	pokedex_screen = PokedexScreenScene.instantiate()
	get_tree().root.add_child(pokedex_screen)
	root.visible = false
	pokedex_screen.closed.connect(_on_pokedex_closed)

func _on_pokedex_closed() -> void:
	pokedex_screen = null
	root.visible = true
	pokedex_button.grab_focus()

# Repris du menu pause (retiré le 13/07/2026, voir acte1-parc-safari.md) :
# même principe que _on_pokedex_pressed().
func _on_map_pressed() -> void:
	region_map_screen = RegionMapScene.instantiate()
	get_tree().root.add_child(region_map_screen)
	root.visible = false
	region_map_screen.closed.connect(_on_map_closed)

func _on_map_closed() -> void:
	region_map_screen = null
	root.visible = true
	map_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		current_pocket = (current_pocket - 1 + tab_buttons.size()) % tab_buttons.size()
		_update_tabs()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		current_pocket = (current_pocket + 1) % tab_buttons.size()
		_update_tabs()
