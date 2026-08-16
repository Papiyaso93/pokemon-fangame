class_name PartySelect
extends CanvasLayer

# Écran de sélection d'un Pokémon dans l'équipe (changement en combat) —
# maquette validée par Gus (aperçus PIL itératifs, voir la conversation de
# conception) reproduite ici en vrai composant Godot. Composant pur-code
# (comme battle_intro.gd) : rien dans un .tscn, tout construit dans
# _build_ui().
#
# Layout : carte du Pokémon ACTIF à gauche (contenu fixe, simple référence —
# on ne peut pas se "switcher" sur soi-même), liste des AUTRES emplacements
# d'équipe à droite (nom/sexe/niveau + barre de PV), boîte de dialogue
# standard en bas ("Choisir un Pokémon."). Un seul curseur (une flèche) se
# déplace entre la carte de gauche et la liste — jamais deux flèches
# affichées à la fois (voir Gus). Haut/bas parcourt une boucle unique : carte
# de gauche -> 1er candidat -> ... -> dernier candidat -> retour à la carte
# de gauche (et inversement avec la flèche du haut) — voir Gus, ce n'est PAS
# une grille à 2 colonnes séparées. Souris : survoler une carte y déplace le
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
signal _menu_choice(value: String)   # local au sous-menu Échanger/Résumé/Revenir, voir _open_action_menu()

@export var party: Array = []   # Array[BattlePokemon] (voir player_side.party) — non typé ici : Array[BattlePokemon] combiné à @export fait échouer la résolution du membre côté appelant (Godot 4.7)
@export var active_index := 0
@export var forced := false
@export var prompt_text := "Choisir un Pokémon."

const BgTexture := preload("res://assets/ui/party_bg_screen.png")
const SlotMainTexture := preload("res://assets/ui/party_slot_main_no_hp_cropped.png")
const SlotWideTexture := preload("res://assets/ui/party_slot_wide_no_hp.png")
const HpBarTexture := preload("res://assets/ui/party_hp_bar.png")
const CursorTexture := preload("res://assets/ui/choice_arrow.png")
const BlankCursorTexture := preload("res://assets/ui/choice_arrow_blank.png")
const FontWhite := preload("res://assets/fonts/dialogue_latin_white.fnt")
# Même police que le reste des menus de combat (ATTAQUE/SAC/POKÉMON/FUITE,
# choix d'attaque) — voir trainer_battle.gd::DialogueFont. FontWhite (ci-
# dessus) reste réservé aux cartes (maquette validée), pas au sous-menu.
const DialogueFont := preload("res://assets/fonts/dialogue_latin.fnt")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const PokedexScreenScene := preload("res://scenes/ui/pokedex_screen.tscn")
const MenuWindowTexture := preload("res://assets/ui/square_window.png")

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
var _menu_active := false   # sous-menu Échanger/Résumé/Revenir ouvert — voir _open_action_menu()
var _menu_buttons: Dictionary = {}   # "echanger"/"resume"/"revenir" -> Button, voir _build_action_menu()

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
	# valide), 1.._list_rows.size() = la liste. Démarre sur la carte de
	# gauche (le Pokémon actuellement au combat) — voir Gus.
	_selected = 0
	_refresh_cursors()
	visible = true
	_active = true

	_dialogue = DialogueBoxScene.instantiate()
	get_tree().root.add_child(_dialogue)
	_dialogue.layer = 98   # au-dessus de ce composant lui-même (97), sinon son propre fond plein écran la masquerait
	var lines: Array[String] = [prompt_text]
	_dialogue.say(lines)   # pas de force_arrow : "Choisir un Pokémon." reste affiché sans rien à continuer, la flèche n'a pas de sens ici (voir Gus)
	# `active = false` : sinon dialogue_box.gd garde l'écoute de ui_accept
	# (queue vide après ce say(), donc prêt à se fermer sur le prochain appui)
	# et peut intercepter l'appui destiné à ouvrir le sous-menu de la carte
	# sélectionnée avant que PartySelect ne le reçoive — même piège que
	# battle_intro.gd::_send_out(), voir _show_message() pour la réactivation
	# ponctuelle le temps d'un message bloquant.
	_dialogue.active = false

	var result: int = await chosen
	return result

# Les candidats de la liste = toute l'équipe SAUF le Pokémon actif (déjà
# représenté par la carte de gauche), dans l'ordre de party — pas de padding
# (voir Gus, aucune carte "---" vide affichée). Les K.O. restent dans la
# liste (contrairement à avant) : on peut cliquer dessus, "Échanger" répond
# juste par un message au lieu de switcher, voir _try_switch().
func _compute_candidates() -> Array:
	var out: Array = []
	for i in range(party.size()):
		if i != active_index:
			out.append(i)
	return out

func _unhandled_input(event: InputEvent) -> void:
	if _menu_active:
		if event.is_action_pressed("ui_cancel"):
			_menu_choice.emit("revenir")
			get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		if _selected == 0 and not _list_rows.is_empty():
			_select(1)   # carte de gauche -> 1re carte de la liste (voir Gus)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		if _selected != 0:
			_select(0)   # n'importe quelle carte de la liste -> carte de gauche (voir Gus)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_open_action_menu(_selected_party_index())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if not forced:
			_cancel()
		get_viewport().set_input_as_handled()

func _selected_party_index() -> int:
	return active_index if _selected == 0 else _candidate_party_indices[_selected - 1]

# Boucle unique (voir l'en-tête du fichier) : 0 = carte de gauche,
# 1.._list_rows.size() = liste, et ça boucle d'un bout à l'autre (dernier
# candidat + bas -> carte de gauche ; carte de gauche + haut -> dernier
# candidat) — voir Gus.
func _move_cursor(direction: int) -> void:
	if _list_rows.is_empty():
		return
	var total := _list_rows.size() + 1
	_select(wrapi(_selected + direction, 0, total))

func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	_refresh_cursors()

# --- souris : survoler une carte déplace le curseur, cliquer ouvre le
# sous-menu Échanger/Résumé/Revenir (comme un appui sur ui_accept) — voir Gus.
func _on_row_hovered(slot_index: int) -> void:
	if _active:
		_select(slot_index)

func _on_row_gui_input(slot_index: int, event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(slot_index)
		_open_action_menu(_selected_party_index())

func _on_main_card_gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(0)
		_open_action_menu(active_index)

# Ferme tout l'écran de sélection sur un switch confirmé (voir _try_switch()) —
# distinct de _cancel() : ici party_index vient d'être validé comme cible
# valide (ni actif, ni K.O.).
func _confirm_switch(party_index: int) -> void:
	_active = false
	if _dialogue != null:
		_dialogue.queue_free()
		_dialogue = null
	chosen.emit(party_index)

func _cancel() -> void:
	_active = false
	if _dialogue != null:
		_dialogue.queue_free()
		_dialogue = null
	cancelled.emit()
	chosen.emit(-1)

# ---------------------------------------------------------------- sous-menu Échanger/Résumé/Revenir
# Ouvert au clic ou à ui_accept sur n'importe quelle carte (gauche ou liste),
# voir Gus. Reste ouvert (revient à lui-même) tant que "Échanger" se heurte à
# un message (actif ou K.O.) ou que "Résumé" est consulté ; seul un switch
# réellement effectué ou "Revenir" le referme.
func _open_action_menu(party_index: int) -> void:
	_menu_active = true
	_active = false
	var menu := _build_action_menu()

	while true:
		var choice: String = await _menu_choice
		match choice:
			"echanger":
				if await _try_switch(party_index):
					break   # écran entier fermé par _confirm_switch(), rien d'autre à faire
			"resume":
				await _open_summary(party[party_index].species_key)
				# La fiche Pokédex prend le focus pour elle-même en s'ouvrant ;
				# une fois refermée, rien ne le rend automatiquement au bouton
				# du sous-menu (signalé par Gus) — on le refait nous-mêmes.
				if _menu_buttons.has("resume"):
					_menu_buttons["resume"].grab_focus()
			"revenir":
				break

	menu.queue_free()
	_menu_buttons.clear()
	_menu_active = false
	_active = true

# true si le switch a bien eu lieu (et donc fermé tout l'écran) ; false si un
# message a juste été affiché (actif ou K.O.) et qu'il faut rouvrir le
# sous-menu. Pas encore d'animation de switch ici (voir Gus, à ajouter plus
# tard) : le remplacement effectif est géré par l'appelant (trainer_battle.gd)
# une fois chosen(party_index) émis, comme pour un switch normal.
func _try_switch(party_index: int) -> bool:
	var pkm: BattlePokemon = party[party_index]
	if party_index == active_index:
		await _show_message("%s est déjà en combat !" % pkm.display_name)
		return false
	if pkm.is_fainted():
		await _show_message("%s n'a plus d'énergie pour combattre !" % pkm.display_name)
		return false
	_confirm_switch(party_index)
	return true

# Affiche un message bloquant dans la boîte de dialogue existante (celle de
# "Choisir un Pokémon.") — attend un appui du joueur pour continuer (say()
# réactive active=true le temps du message), puis restaure le texte
# d'origine derrière le sous-menu qui reste ouvert et redevient passive.
func _show_message(text: String) -> void:
	# Perd le focus le temps du message : sinon le bouton "Échanger" (celui
	# qui a mené ici) garde le focus, et l'appui sur la touche d'action qui
	# fait avancer/fermer le message active AUSSI ce bouton via la
	# navigation clavier native de Godot, ce qui relance "Échanger" en
	# boucle (signalé par Gus).
	var echanger_btn: Button = _menu_buttons.get("echanger")
	if echanger_btn != null:
		echanger_btn.release_focus()

	var lines: Array[String] = [text]
	# force_arrow=true : une seule ligne, donc pas de flèche par défaut (voir
	# dialogue_box.gd), alors qu'une action du joueur est bien attendue pour
	# continuer — même besoin déjà rencontré pour les messages de combat
	# (trainer_battle.gd::_say()) et de l'intro (battle_intro.gd).
	_dialogue.say(lines, -1, 0.0, true)
	await _dialogue.finished
	var restore: Array[String] = [prompt_text]
	_dialogue.say(restore)
	_dialogue.active = false

	if echanger_btn != null:
		echanger_btn.grab_focus()

# Fiche Pokédex de l'espèce (voir Gus : "Résumé" amène sur cette fiche, pas
# un écran de résumé de combat dédié — rien de tel n'existe encore). Saute
# directement au détail plutôt que d'ouvrir la liste complète.
func _open_summary(species_key: String) -> void:
	_active = false   # PartySelect ignore les entrées pendant que la fiche est ouverte (elle a son propre _unhandled_input)
	var screen := PokedexScreenScene.instantiate()
	get_tree().root.add_child(screen)
	# layer=1 par défaut (rien de précisé dans pokedex_screen.tscn) : restait
	# sous le fond plein écran de ce composant (layer 97) et du sous-menu
	# (99), donc invisible — même piège rencontré plusieurs fois déjà.
	screen.layer = 100
	screen._show_detail(species_key)
	await screen.closed
	_active = true

# Même fenêtre/style que le menu d'action de trainer_battle.gd (StyleBoxTexture
# square_window.png, boutons à fond transparent avec flèche sur celui
# survolé/focus au lieu d'un fond gris, même police) — voir Gus, il ne faut
# pas réinventer un style différent pour ce sous-menu. Positionnée en bas à
# droite comme les autres fenêtres d'action du combat (mêmes proportions que
# _action_window dans trainer_battle.tscn : left=0.65 top=0.74 right=0.98
# bottom=0.96, converties en pixels ici car ce composant positionne tout en
# absolu plutôt qu'en anchors fractionnaires).
func _build_action_menu() -> CanvasLayer:
	# CanvasLayer dédié au-dessus de _dialogue (98) : même piège/pattern que
	# trainer_battle.gd::_action_layer (96, au-dessus de _prompt_dialogue à
	# 95) — un Control simplement ajouté à _root (calque 97, celui de ce
	# composant) resterait SOUS la boîte de dialogue plutôt qu'au-dessus.
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 99
	get_tree().root.add_child(menu_layer)

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP   # absorbe les clics sur les cartes derrière tant que le sous-menu est ouvert
	menu_layer.add_child(overlay)

	var style := StyleBoxTexture.new()
	style.texture = MenuWindowTexture
	style.texture_margin_left = 12.0
	style.texture_margin_top = 12.0
	style.texture_margin_right = 12.0
	style.texture_margin_bottom = 12.0
	style.content_margin_left = 18.0
	style.content_margin_top = 12.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 12.0

	# Ne doit PAS chevaucher la boîte de dialogue (top=648-168=480, voir
	# dialogue_box.tscn) : flotte au-dessus, avec une marge, comme l'exemple
	# fourni par Gus (choix garçon/fille) — ni collée ni superposée. Largeur
	# resserrée au contenu plutôt qu'étirée sur toute la largeur habituelle
	# d'une fenêtre d'action (inutile ici, seulement 3 lignes de texte court).
	const MENU_W := 210.0
	const MENU_H := 130.0
	const DIALOGUE_TOP := 480.0
	const MENU_MARGIN := 30.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_right = 1152.0 - 24.0
	panel.offset_left = panel.offset_right - MENU_W
	panel.offset_bottom = DIALOGUE_TOP - MENU_MARGIN
	panel.offset_top = panel.offset_bottom - MENU_H
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var empty_style := StyleBoxEmpty.new()
	empty_style.content_margin_left = 8.0
	empty_style.content_margin_top = 4.0
	empty_style.content_margin_right = 8.0
	empty_style.content_margin_bottom = 4.0

	var first: Button = null
	for entry in [["Échanger", "echanger"], ["Résumé", "resume"], ["Revenir", "revenir"]]:
		var value: String = String(entry[1])
		var btn := _menu_action_button(String(entry[0]), empty_style)
		btn.pressed.connect(func(): _menu_choice.emit(value))
		box.add_child(btn)
		_menu_buttons[value] = btn
		if first == null:
			first = btn
	if first:
		first.grab_focus()

	return menu_layer

func _menu_action_button(text: String, empty_style: StyleBoxEmpty) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", DialogueFont)
	btn.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty_style)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.icon = BlankCursorTexture
	btn.mouse_entered.connect(func(): btn.grab_focus())
	btn.focus_entered.connect(func(): btn.icon = CursorTexture)
	btn.focus_exited.connect(func(): btn.icon = BlankCursorTexture)
	return btn

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
	main_card.gui_input.connect(_on_main_card_gui_input)
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

