extends CanvasLayer

# Écran "Quêtes" (menu pause). Reprend le pattern déjà utilisé par le
# Pokédex (scripts/pokedex_screen.gd) : liste de titres seuls, clic pour voir
# le détail sur une page séparée, Échap revient à la liste — même langage
# visuel entre les deux écrans plutôt que d'inventer un nouveau pattern.
#
# 2 onglets (Principales/Secondaires), pas 3 : le statut (en cours/terminée)
# se lit DANS la liste (coche + grisé) plutôt que comme un 3e onglet — sinon
# une quête principale terminée devrait vivre dans 2 onglets à la fois
# (Principales ET Terminées), ce qui casse le principe d'onglets exclusifs.
#
# Toujours codé en dur (voir la conversation de conception) : une entrée par
# quête existante, pas de moteur de quêtes générique pour l'instant. Ajouter
# une quête = une entrée dans QUESTS + un cas dans _quest_visible()/
# _quest_done()/_quest_description() ci-dessous.

signal closed

const CHECK_PREFIX := "✓ "
const DONE_MODULATE := Color(1, 1, 1, 0.55)
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const ArrowTexture := preload("res://assets/ui/choice_arrow.png")

# order : sert uniquement à trier "plus récent d'abord" au sein d'un même
# statut (voir _sorted_entries) — plus la valeur est grande, plus la quête a
# été lancée récemment. Pas de vrai horodatage pour l'instant, une seule
# quête existe donc ça n'a pas encore d'effet visible.
const QUESTS: Array[Dictionary] = [
	{"id": "minidraco", "category": "main", "order": 1, "title": "Le Pokémon échappé"},
]

@onready var main_tab: Button = $Root/Center/Window/VBox/Tabs/MainTab
@onready var side_tab: Button = $Root/Center/Window/VBox/Tabs/SideTab
@onready var list_page: Control = $Root/Center/Window/VBox/ListPage
@onready var rows_box: VBoxContainer = $Root/Center/Window/VBox/ListPage/Scroll/Buttons
@onready var empty_label: Label = $Root/Center/Window/VBox/ListPage/EmptyLabel
@onready var detail_page: Control = $Root/Center/Window/VBox/DetailPage
@onready var detail_title: Label = $Root/Center/Window/VBox/DetailPage/Title
@onready var detail_status: Label = $Root/Center/Window/VBox/DetailPage/Status
@onready var detail_description: Label = $Root/Center/Window/VBox/DetailPage/Description
@onready var hint: Label = $Root/Center/Window/VBox/Hint

var current_category := "main"
var tab_buttons: Array[Button] = []

# Soulignement façon onglet (voir bag.gd) : bordure basse pleine sur l'onglet
# actif, rien sur les autres — pas le style bouton gris par défaut du moteur.
var _underline_style: StyleBoxFlat
var _no_underline_style: StyleBoxEmpty

func _ready() -> void:
	_underline_style = StyleBoxFlat.new()
	_underline_style.bg_color = Color(0, 0, 0, 0)
	_underline_style.border_width_bottom = 3
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

	tab_buttons = [main_tab, side_tab]
	main_tab.pressed.connect(_select_category.bind("main"))
	side_tab.pressed.connect(_select_category.bind("side"))
	_select_category("main")

func _select_category(category: String) -> void:
	current_category = category
	for btn in tab_buttons:
		var is_current := (btn == main_tab and category == "main") or (btn == side_tab and category == "side")
		btn.modulate.a = 1.0 if is_current else 0.5
		var style: StyleBox = _underline_style if is_current else _no_underline_style
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, style)
	detail_page.visible = false
	list_page.visible = true
	hint.text = "Échap : revenir"
	_refresh_list()

func _refresh_list() -> void:
	for child in rows_box.get_children():
		child.queue_free()
	var entries := _sorted_entries(current_category)
	empty_label.visible = entries.is_empty()
	empty_label.text = "Aucune quête."
	var first_button: Button = null
	for entry in entries:
		var id: String = entry["id"]
		var done := _quest_done(id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 0)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = false
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = (CHECK_PREFIX if done else "") + String(entry["title"])
		if done:
			btn.modulate = DONE_MODULATE
		btn.icon = BlankTexture
		# Même principe que partout ailleurs : le survol souris déplace le
		# focus clavier, les flèches haut/bas naviguent nativement entre les
		# boutons focusables (gauche/droite reste réservé aux onglets, voir
		# _unhandled_input).
		btn.mouse_entered.connect(func(): btn.grab_focus())
		btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
		btn.focus_exited.connect(func(): btn.icon = BlankTexture)
		btn.pressed.connect(_show_detail.bind(id))
		rows_box.add_child(btn)
		if first_button == null:
			first_button = btn
	if first_button:
		first_button.grab_focus()

func _show_detail(id: String) -> void:
	var entry := _quest_by_id(id)
	var done := _quest_done(id)
	detail_title.text = String(entry.get("title", ""))
	detail_status.visible = done
	detail_status.text = CHECK_PREFIX + "Terminée"
	detail_description.text = _quest_description(id)
	list_page.visible = false
	detail_page.visible = true
	hint.text = "Échap : revenir"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if detail_page.visible:
			list_page.visible = true
			detail_page.visible = false
			hint.text = "Échap : revenir"
		else:
			closed.emit()
			queue_free()
	elif list_page.visible and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		_select_category("side" if current_category == "main" else "main")

func _quest_by_id(id: String) -> Dictionary:
	for q in QUESTS:
		if q["id"] == id:
			return q
	return {}

# Actives d'abord, terminées ensuite ; au sein d'un même statut, la plus
# récemment lancée (order le plus grand) en premier.
func _sorted_entries(category: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for q in QUESTS:
		if String(q["category"]) == category and _quest_visible(String(q["id"])):
			entries.append(q)
	entries.sort_custom(func(a, b):
		var a_done := _quest_done(String(a["id"]))
		var b_done := _quest_done(String(b["id"]))
		if a_done != b_done:
			return not a_done
		return int(a["order"]) > int(b["order"])
	)
	return entries

# --- État par quête (un cas par id, à étendre au fil des futures quêtes) ---

func _quest_visible(id: String) -> bool:
	match id:
		"minidraco":
			return PlayerData.camille_zone1_done
	return false

func _quest_done(id: String) -> bool:
	match id:
		"minidraco":
			return PlayerData.minidraco_captured
	return false

func _quest_description(id: String) -> String:
	match id:
		"minidraco":
			if PlayerData.minidraco_captured:
				return "Le Pokémon a été capturé et confié à Camille pour étude au labo."
			elif PlayerData.minidraco_spot_found:
				return "Il semble se cacher dans un coin isolé du parc. Approche-toi sans le brusquer."
			else:
				return "Un Pokémon s'est échappé quelque part dans le parc. Sa fiche dans le Pokédex devrait donner une piste."
	return ""
