extends CanvasLayer

signal closed

# Sac (test) — v1 volontairement vide : juste la navigation entre les 5
# poches (voir BagData), pas encore d'objets ni de vrai inventaire (cf.
# HANDOFF.md pour le topo complet du système FRLG réel). Gauche/Droite pour
# changer de poche (équivalent L/R du vrai jeu, qu'on n'a pas sur PC),
# Échap pour revenir — même principe que scripts/region_map.gd.

const TabDimAlpha := 0.5
const PokedexScreenScene := preload("res://scenes/ui/pokedex_screen.tscn")
const KEY_ITEMS_POCKET_INDEX := 1   # cf. BagData.POCKETS — poche "Objets Rares"

# Soulignement façon onglet de navigateur : une bordure basse pleine sur
# l'onglet actif, rien du tout sur les autres (pas juste une même bordure
# atténuée — Gus voulait vraiment "rien sous les onglets inactifs").
var _underline_style: StyleBoxFlat
var _no_underline_style: StyleBoxEmpty

@onready var root: Control = $Root
@onready var tabs_row: HBoxContainer = $Root/Center/Window/VBox/TabsRow
@onready var empty_label: Label = $Root/Center/Window/VBox/ContentArea/Center/EmptyLabel
@onready var item_list: VBoxContainer = $Root/Center/Window/VBox/ContentArea/Center/ItemList
@onready var pokedex_button: Button = $Root/Center/Window/VBox/ContentArea/Center/ItemList/PokedexButton
@onready var surf_button: Button = $Root/Center/Window/VBox/ContentArea/Center/ItemList/SurfButton

var current_pocket := 0
var tab_buttons: Array[Button] = []
var pokedex_screen: Node = null

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
	pokedex_button.pressed.connect(_on_pokedex_pressed)
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
	# Pas de vrai inventaire pour l'instant (v1 test) — seule exception : les
	# objets rares obtenus pendant l'acte 1 (Pokédex, Surf...), affichés ici
	# dès qu'on les a reçus (voir acte1-parc-safari.md).
	var in_key_pocket := current_pocket == KEY_ITEMS_POCKET_INDEX
	pokedex_button.visible = in_key_pocket and PlayerData.camille_zone1_done
	surf_button.visible = in_key_pocket and PlayerData.has_surf
	var has_any_item := pokedex_button.visible or surf_button.visible
	item_list.visible = in_key_pocket and has_any_item
	empty_label.visible = not (in_key_pocket and has_any_item)

func _on_pokedex_pressed() -> void:
	pokedex_screen = PokedexScreenScene.instantiate()
	get_tree().root.add_child(pokedex_screen)
	root.visible = false
	pokedex_screen.closed.connect(_on_pokedex_closed)

func _on_pokedex_closed() -> void:
	pokedex_screen = null
	root.visible = true

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
