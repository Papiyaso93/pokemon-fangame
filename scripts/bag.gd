extends CanvasLayer

signal closed

# Sac (test) — v1 volontairement vide : juste la navigation entre les 5
# poches (voir BagData), pas encore d'objets ni de vrai inventaire (cf.
# HANDOFF.md pour le topo complet du système FRLG réel). Gauche/Droite pour
# changer de poche (équivalent L/R du vrai jeu, qu'on n'a pas sur PC),
# Échap pour revenir — même principe que scripts/region_map.gd.

const TabDimAlpha := 0.5

# Soulignement façon onglet de navigateur : une bordure basse pleine sur
# l'onglet actif, rien du tout sur les autres (pas juste une même bordure
# atténuée — Gus voulait vraiment "rien sous les onglets inactifs").
var _underline_style: StyleBoxFlat
var _no_underline_style: StyleBoxEmpty

@onready var tabs_row: HBoxContainer = $Root/Center/Window/VBox/TabsRow
@onready var empty_label: Label = $Root/Center/Window/VBox/ContentArea/EmptyLabel

var current_pocket := 0
var tab_buttons: Array[Button] = []

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
	# Rien d'autre à afficher pour l'instant : pas de vrai inventaire (v1
	# test), donc le contenu de chaque poche est toujours vide.
	empty_label.text = "Aucun objet"

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
