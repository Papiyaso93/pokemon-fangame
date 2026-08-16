class_name PartySelect
extends CanvasLayer

# Écran de sélection d'un Pokémon dans l'équipe (changement en combat) —
# maquette validée par Gus (aperçus PIL itératifs, voir la conversation de
# conception) reproduite ici en vrai composant Godot. Composant pur-code
# (comme battle_intro.gd) : rien dans un .tscn, tout construit dans
# _build_ui().
#
# Layout : carte du Pokémon ACTIF à gauche (contenu fixe, simple référence —
# on ne peut pas se "switcher" sur soi-même), liste des 5 AUTRES emplacements
# d'équipe à droite (nom/sexe/niveau + barre de PV), boîte de dialogue
# standard en bas ("Choisir un Pokémon."). Un seul curseur (une flèche) se
# déplace entre les 6 emplacements (carte de gauche comprise, pour pouvoir
# s'y arrêter sans que ça ne soit un choix confirmable) — jamais deux flèches
# affichées à la fois (voir Gus). Haut/bas navigue dans la liste de droite
# uniquement (sans jamais atteindre la carte de gauche), gauche/droite bascule
# entre la carte de gauche et la liste — navigation en grille 2 colonnes,
# pas une liste linéaire de 6. Souris : survoler une carte y déplace le
# curseur, cliquer confirme (comme un bouton). Confirmation ferme l'écran et
# émet chosen(party_index), Échap/ui_cancel émet cancelled (désactivé si
# forced=true, K.O.) — pas de bouton "Sortir" visible (voir Gus).
#
# Usage : var sel := PartySelect.new(); sel.party = player_side.party;
# sel.active_index = player_side.active_index; sel.forced = ...;
# get_tree().root.add_child(sel); var idx = await sel.pick(); sel.queue_free()
# idx == -1 si annulé.

signal chosen(index: int)
signal cancelled

@export var party: Array = []   # Array[BattlePokemon] (voir player_side.party) — non typé ici : Array[BattlePokemon] combiné à @export fait échouer la résolution du membre côté appelant (Godot 4.7)
@export var active_index := 0
@export var forced := false
@export var prompt_text := "Choisir un Pokémon."

const BgTexture := preload("res://assets/ui/party_bg_screen.png")
const SlotMainTexture := preload("res://assets/ui/party_slot_main_no_hp_cropped.png")
const SlotWideTexture := preload("res://assets/ui/party_slot_wide_no_hp.png")
const HpBarTexture := preload("res://assets/ui/party_hp_bar.png")
const CursorTexture := preload("res://assets/ui/choice_arrow.png")
const FontWhite := preload("res://assets/fonts/dialogue_latin_white.fnt")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")

# Couleurs du symbole de sexe — voir battle_intro.gd/trainer_battle.gd
# (Gus a signalé que ce n'est pas encore la même méthode d'affichage qu'en
# combat, à harmoniser plus tard — voir la conversation de conception).
const GENDER_MALE_COLOR := Color(0.2, 0.501961, 0.976471)
const GENDER_FEMALE_COLOR := Color(0.976471, 0.211765, 0.501961)
const PV_LABEL_COLOR := Color(1.0, 0.745098, 0.235294)
const HP_FILL_COLOR := Color(0.352941, 0.862745, 0.431373)

const MAIN_X := 24.0
const MAIN_Y := 24.0
const MAIN_SCALE_W := 5.15
const MAIN_SCALE_H := 4.0
const MAIN_CARD_W := 80.0 * MAIN_SCALE_W
const MAIN_CARD_H := 51.0 * MAIN_SCALE_H

const FRONT_SCALE := 2.1
const LIST_ICON_SCALE := 1.3   # même sprite (front.png) que la carte de gauche, juste plus petit pour tenir dans une carte de liste — statique des 2 côtés (voir Gus)
const NAME_TO_BAR_GAP := 37.0
const MAIN_BAR_TARGET_W := 250.0
const MAIN_BAR_NATIVE_W := 69.0
const MAIN_BAR_SCALE := MAIN_BAR_TARGET_W / MAIN_BAR_NATIVE_W

const LIST_SCALE_W := 3.6
const LIST_SCALE_H := 3.75
const LIST_CARD_W := 144.0 * LIST_SCALE_W
const LIST_CARD_H := 24.0 * LIST_SCALE_H
const LIST_GAP := 5.0
const LIST_Y0 := 12.0
const LIST_BAR_SCALE := 3.7
const CENTER_ZONE_X_FRAC := 0.19   # infos décalées un peu à gauche (voir Gus)
const LIST_ICON_LEFT_BLEED := 0.10   # sprite décalé un peu à droite (voir Gus) — plus petit que la valeur d'origine (0.18) = déborde moins sur le bord gauche

# Tailles de police : la police (dialogue_latin_white.fnt) a des glyphes
# natifs de 32px ("size=32" dans le .fnt) — un "font_size" Godot de 32
# affiche donc les glyphes à leur taille native, et demander un font_size
# différent les redimensionne proportionnellement. La maquette Python
# (aperçus PIL validés par Gus) exprimait ses tailles en multiplicateur direct
# de cette même taille native (ex. scale=1.4 -> glyphe affiché à 140% de
# 32px) : ces constantes reprennent donc 32*scale pour chaque élément, sans
# quoi le texte ressort minuscule (32*0.26 ≈ rien à voir avec la maquette).
const FONT_NATIVE_SIZE := 32.0
const MAIN_NAME_FONT := int(FONT_NATIVE_SIZE * 1.4)     # 45
const MAIN_LEVEL_FONT := int(FONT_NATIVE_SIZE * 1.15)   # 37
const MAIN_PV_LABEL_FONT := int(FONT_NATIVE_SIZE * 0.85) # 27
const MAIN_PV_TEXT_FONT := int(FONT_NATIVE_SIZE * 1.0)   # 32
const LIST_NAME_FONT := int(FONT_NATIVE_SIZE * 1.05)     # 34
const LIST_LEVEL_FONT := int(FONT_NATIVE_SIZE * 1.05 * 0.9)   # 30
const LIST_PV_LABEL_FONT := int(FONT_NATIVE_SIZE * 0.85) # 27
const LIST_PV_TEXT_FONT := int(FONT_NATIVE_SIZE * 0.95)  # 30

var _root: Control
var _main_cursor: TextureRect

var _list_rows: Array = []   # une entrée par candidat réel de la liste : {"icon", "name", "gender", "level", "bar_fill", "bar_text", "cursor"}
var _candidate_party_indices: Array = []   # index dans `party` pour chaque ligne de la liste — jamais d'emplacement vide (voir Gus : pas de carte "---" si l'équipe est incomplète)

var _dialogue: Node
var _selected := 0   # 0 = carte de gauche, 1.._list_rows.size() = liste
var _active := false

func _ready() -> void:
	# Au-dessus de tout le reste de l'écran de combat, y compris
	# _action_layer (96, voir trainer_battle.gd) — sinon la fenêtre d'action
	# (vide pendant ce choix) reste visible par-dessus. La boîte de dialogue
	# de ce composant (voir pick()) est explicitement mise encore au-dessus.
	layer = 97
	_candidate_party_indices = _compute_candidates()
	_build_ui()

func pick() -> int:
	# Curseur unique : 0 = carte de gauche (Pokémon actif, jamais un choix
	# valide), 1.._list_rows.size() = la liste. Démarre sur le premier
	# candidat réel plutôt que sur la carte de gauche (voir Gus : un seul
	# curseur visible à la fois, pas de flèche fixe en plus).
	_selected = 1 if not _list_rows.is_empty() else 0
	_refresh_cursors()
	visible = true
	_active = true

	_dialogue = DialogueBoxScene.instantiate()
	get_tree().root.add_child(_dialogue)
	_dialogue.layer = 98   # au-dessus de ce composant lui-même (97), sinon son propre fond plein écran la masquerait
	var lines: Array[String] = [prompt_text]
	_dialogue.say(lines, -1, 0.0, true)

	var result: int = await chosen
	return result

# Les candidats de la liste = toute l'équipe SAUF le Pokémon actif et les
# K.O. (comme l'ancien _prompt_switch), dans l'ordre de party — pas de
# padding : si l'équipe n'a que 3 Pokémon, la liste n'a que 2 cartes (voir
# Gus, aucune carte "---" vide affichée).
func _compute_candidates() -> Array:
	var out: Array = []
	for i in range(party.size()):
		if i == active_index:
			continue
		var pkm: BattlePokemon = party[i]
		if pkm != null and pkm.is_fainted():
			continue
		out.append(i)
	return out

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_up"):
		_move_in_list(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_in_list(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_select(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		if _selected == 0:
			_move_in_list(0)   # revient au premier candidat valide, voir _move_in_list()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm_if_valid()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if not forced:
			_cancel()
		get_viewport().set_input_as_handled()

# Navigation en grille 2 colonnes (voir l'en-tête du fichier) : haut/bas ne
# déplace le curseur QUE dans la liste de droite (jamais vers la carte de
# gauche, contrairement à une ancienne version) ; gauche/droite bascule entre
# les 2 colonnes (_select(0) / ceci). direction=0 depuis la carte de gauche
# revient simplement au premier candidat de la liste. Plus d'emplacements
# vides à sauter (voir _compute_candidates()) : chaque ligne construite est
# un choix valide.
func _move_in_list(direction: int) -> void:
	if _list_rows.is_empty():
		return
	if direction == 0:
		_select(1)
		return
	var start := _selected if _selected != 0 else 1
	_select(wrapi(start - 1 + direction, 0, _list_rows.size()) + 1)

func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	_refresh_cursors()

func _confirm_if_valid() -> void:
	if _selected != 0:
		_confirm()

# --- souris : survoler une carte déplace le curseur, cliquer confirme
# (comme un bouton) — voir Gus, la navigation clavier ne suffisait pas.
func _on_row_hovered(slot_index: int) -> void:
	if _active:
		_select(slot_index)

func _on_row_gui_input(slot_index: int, event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(slot_index)
		_confirm()

func _confirm() -> void:
	_active = false
	if _dialogue != null:
		_dialogue.queue_free()
		_dialogue = null
	chosen.emit(_candidate_party_indices[_selected - 1])

func _cancel() -> void:
	_active = false
	if _dialogue != null:
		_dialogue.queue_free()
		_dialogue = null
	cancelled.emit()
	chosen.emit(-1)

# ---------------------------------------------------------------- UI build

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = BgTexture
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(bg)

	_build_main_card()

	for i in range(_candidate_party_indices.size()):
		_build_list_row(i)

func _rect_control(x: float, y: float, w: float, h: float) -> Control:
	var c := Control.new()
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h
	return c

func _tex_rect(texture: Texture2D, x: float, y: float, w: float, h: float) -> TextureRect:
	var t := TextureRect.new()
	t.anchor_left = 0.0
	t.anchor_top = 0.0
	t.anchor_right = 0.0
	t.anchor_bottom = 0.0
	t.offset_left = x
	t.offset_top = y
	t.offset_right = x + w
	t.offset_bottom = y + h
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t

func _make_label(text: String, x: float, y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_top = 0.0
	l.offset_left = x
	l.offset_top = y
	l.text = text
	l.add_theme_font_override("font", FontWhite)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.size = Vector2(400, font_size * 1.4)
	return l

func _gender_color(gender: String) -> Color:
	return GENDER_FEMALE_COLOR if gender == "female" else GENDER_MALE_COLOR

func _gender_symbol(gender: String) -> String:
	if gender == "female":
		return "♀"
	if gender == "male":
		return "♂"
	return ""

# --- carte du Pokémon actif (fixe, à gauche) ---

func _build_main_card() -> void:
	var main_card := _rect_control(MAIN_X, MAIN_Y, MAIN_CARD_W, MAIN_CARD_H)
	main_card.mouse_filter = Control.MOUSE_FILTER_STOP
	main_card.mouse_entered.connect(func(): _select(0))
	_root.add_child(main_card)

	var bg := _tex_rect(SlotMainTexture, 0, 0, MAIN_CARD_W, MAIN_CARD_H)
	main_card.add_child(bg)

	# Fait partie du même curseur unique que la liste de droite (voir
	# _move_selection()/_refresh_cursors()) — masquée par défaut, visible
	# uniquement quand le curseur est sur cet emplacement.
	_main_cursor = _tex_rect(CursorTexture, -26.0, MAIN_CARD_H * 0.5 - 12.0, 24.0, 24.0)
	_main_cursor.visible = false
	main_card.add_child(_main_cursor)

	var pkm: BattlePokemon = party[active_index] if active_index < party.size() else null
	if pkm == null:
		return

	var sprite := TextureRect.new()
	sprite.anchor_left = 0.0
	sprite.anchor_top = 0.0
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	main_card.add_child(sprite)

	var front_path := "res://assets/pokemon/%s/front.png" % pkm.species_key
	if ResourceLoader.exists(front_path):
		var front_tex: Texture2D = load(front_path)
		sprite.texture = front_tex
		var w := front_tex.get_width() * FRONT_SCALE
		var h := front_tex.get_height() * FRONT_SCALE
		sprite.offset_left = 10.0
		sprite.offset_top = (MAIN_CARD_H - h) * 0.5 - 34.0
		sprite.offset_right = sprite.offset_left + w
		sprite.offset_bottom = sprite.offset_top + h

	var text_x := 165.0
	var name_y := 40.0
	var name := _make_label(pkm.display_name, text_x, name_y, MAIN_NAME_FONT, Color.WHITE)
	main_card.add_child(name)
	var name_w: float = name.get_theme_font("font").get_string_size(pkm.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, MAIN_NAME_FONT).x
	var gender := _make_label(_gender_symbol(pkm.gender), text_x + name_w + 8.0, name_y, MAIN_NAME_FONT, _gender_color(pkm.gender))
	main_card.add_child(gender)

	var level_y := name_y + 34.0
	var level := _make_label("N.%d" % pkm.level, text_x, level_y, MAIN_LEVEL_FONT, Color.WHITE)
	main_card.add_child(level)

	var bar_x := 128.0
	var bar_y := level_y + NAME_TO_BAR_GAP
	var bar := _build_hp_bar(main_card, bar_x, bar_y, MAIN_BAR_SCALE, MAIN_PV_LABEL_FONT, MAIN_PV_TEXT_FONT)
	_set_bar(bar["fill"], bar["text"], pkm.current_hp, pkm.max_hp, bar_x, bar_y, MAIN_BAR_SCALE)

# --- rangée de la liste (les 5 autres, à droite) ---

func _build_list_row(index: int) -> void:
	var yy := LIST_Y0 + index * (LIST_CARD_H + LIST_GAP)
	var right_x := MAIN_X + MAIN_CARD_W + 40.0
	var row := _rect_control(right_x, yy, LIST_CARD_W, LIST_CARD_H)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var slot_index := index + 1
	row.mouse_entered.connect(func(): _on_row_hovered(slot_index))
	row.gui_input.connect(func(e: InputEvent): _on_row_gui_input(slot_index, e))
	_root.add_child(row)

	var bg := _tex_rect(SlotWideTexture, 0, 0, LIST_CARD_W, LIST_CARD_H)
	row.add_child(bg)

	var cursor := _tex_rect(CursorTexture, -26.0, LIST_CARD_H * 0.5 - 12.0, 24.0, 24.0)
	cursor.visible = false
	row.add_child(cursor)

	# Géométrie posée plus tard, dans _refresh_row() : la taille dépend du
	# sprite (front.png) réel de l'espèce, pas connue à la construction (les
	# 5 lignes sont construites avant que _compute_candidates() ne sache
	# quel Pokémon va dans quelle ligne).
	var icon := TextureRect.new()
	icon.anchor_left = 0.0
	icon.anchor_top = 0.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)

	var center_zone_x := LIST_CARD_W * CENTER_ZONE_X_FRAC
	var name_y2 := LIST_CARD_H * 0.18
	var name := _make_label("", center_zone_x, name_y2, LIST_NAME_FONT, Color.WHITE)
	row.add_child(name)
	var gender := _make_label("", center_zone_x, name_y2, LIST_NAME_FONT, GENDER_MALE_COLOR)
	row.add_child(gender)

	var level_y2 := LIST_CARD_H * 0.55
	var level := _make_label("", center_zone_x, level_y2, LIST_LEVEL_FONT, Color.WHITE)
	row.add_child(level)

	var bar_x2 := LIST_CARD_W * 68.0 / 144.0
	var bar_y2 := LIST_CARD_H * 0.18
	var bar := _build_hp_bar(row, bar_x2, bar_y2, LIST_BAR_SCALE, LIST_PV_LABEL_FONT, LIST_PV_TEXT_FONT)

	_list_rows.append({
		"icon": icon,
		"name": name,
		"gender": gender,
		"level": level,
		"bar_fill": bar["fill"],
		"bar_text": bar["text"],
		"cursor": cursor,
	})
	_refresh_row(index)

# --- barre de PV réutilisable (même recette carte principale / liste) ---
# Coordonnées natives (dans party_hp_bar.png, qui commence à x=68,y=6 de
# l'asset source party_slot_wide.png) : label "PV" en (5,2), remplissage en
# (14,5)-(60,7), texte PV aligné sur (63,10).
func _build_hp_bar(parent: Control, x: float, y: float, scale: float, label_font: int, text_font: int) -> Dictionary:
	var w := HpBarTexture.get_width() * scale
	var h := HpBarTexture.get_height() * scale
	var tex := _tex_rect(HpBarTexture, x, y, w, h)
	parent.add_child(tex)

	var label := _make_label("PV", x + 5.0 * scale, y + 2.0 * scale, label_font, PV_LABEL_COLOR)
	parent.add_child(label)

	var fill := ColorRect.new()
	fill.color = HP_FILL_COLOR
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.offset_left = x + 14.0 * scale
	fill.offset_top = y + 5.0 * scale
	fill.offset_right = fill.offset_left
	fill.offset_bottom = y + 7.0 * scale
	parent.add_child(fill)

	var text := _make_label("", 0, 0, text_font, Color.WHITE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.offset_top = y + 10.0 * scale + 2.0
	text.offset_left = x
	text.offset_right = x + 63.0 * scale
	text.size = Vector2(63.0 * scale, 20)
	parent.add_child(text)

	return {"fill": fill, "text": text}

func _set_bar(fill: ColorRect, text: Label, current_hp: int, max_hp: int, x: float, y: float, scale: float) -> void:
	var ratio: float = clampf(float(current_hp) / float(max(max_hp, 1)), 0.0, 1.0)
	var fill_left := x + 14.0 * scale
	var fill_right_max := x + 60.0 * scale
	fill.offset_left = fill_left
	fill.offset_top = y + 5.0 * scale
	fill.offset_right = fill_left + (fill_right_max - fill_left) * ratio
	fill.offset_bottom = y + 7.0 * scale
	text.text = "%d/%d" % [current_hp, max_hp]

# ---------------------------------------------------------------- refresh

func _refresh_main_card() -> void:
	pass   # fixe (le Pokémon actif ne change pas pendant que ce composant est affiché), déjà rempli une fois par _build_main_card()

func _refresh_row(index: int) -> void:
	var row_data: Dictionary = _list_rows[index]
	var party_index: int = _candidate_party_indices[index]
	var pkm: BattlePokemon = party[party_index]

	var icon: TextureRect = row_data["icon"]
	var front_path := "res://assets/pokemon/%s/front.png" % pkm.species_key
	if ResourceLoader.exists(front_path):
		var front_tex: Texture2D = load(front_path)
		icon.texture = front_tex
		var w := front_tex.get_width() * LIST_ICON_SCALE
		var h := front_tex.get_height() * LIST_ICON_SCALE
		icon.offset_left = -w * LIST_ICON_LEFT_BLEED
		icon.offset_top = (LIST_CARD_H - h) * 0.5
		icon.offset_right = icon.offset_left + w
		icon.offset_bottom = icon.offset_top + h

	row_data["name"].text = pkm.display_name
	var name_w: float = row_data["name"].get_theme_font("font").get_string_size(pkm.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, LIST_NAME_FONT).x
	row_data["gender"].text = _gender_symbol(pkm.gender)
	row_data["gender"].offset_left = LIST_CARD_W * CENTER_ZONE_X_FRAC + name_w + 6.0
	row_data["gender"].add_theme_color_override("font_color", _gender_color(pkm.gender))

	row_data["level"].text = "N.%d" % pkm.level
	row_data["bar_fill"].visible = true

	var bar_x2 := LIST_CARD_W * 68.0 / 144.0
	var bar_y2 := LIST_CARD_H * 0.18
	_set_bar(row_data["bar_fill"], row_data["bar_text"], pkm.current_hp, pkm.max_hp, bar_x2, bar_y2, LIST_BAR_SCALE)

func _refresh_cursors() -> void:
	_main_cursor.visible = (_selected == 0)
	for i in range(_list_rows.size()):
		_list_rows[i]["cursor"].visible = (_selected == i + 1)

