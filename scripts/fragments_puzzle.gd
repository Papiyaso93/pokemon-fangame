extends CanvasLayer

# Puzzle des fragments de Julien (zone 2 du Parc Safari, ruines) — voir
# scripts/npc_julien_zone2.gd et acte1-parc-safari.md. Grille 4x5 (20 cases) :
# les 4 cases du haut forment le nom "PTERA", les 16 cases du dessous la
# silhouette gravée, à partir de assets/ui/julien_fragments_sheet.png généré
# depuis assets/pokemon/aerodactyl/front.png (fragments 0-3 = nom, 4-19 =
# silhouette, en lecture ligne par ligne — voir la disposition du sheet).
#
# Mécanique par sélection/échange façon puzzle Zarbi d'Or/Argent (pas de
# glisser-déposer : rien de tel n'existe ailleurs dans le projet, qui est
# entièrement piloté clavier/manette, voir yes_no_choice.gd/list_picker.gd) :
# toutes les cases sont occupées dès le départ, sélectionner deux fragments
# les échange. Comme aucune case n'est jamais vide, un fragment mal placé peut
# toujours être resélectionné et redéplacé, sans limite ni pénalité.
#
# Peut être quitté à tout moment (Échap) : la disposition en cours est alors
# sauvegardée dans PlayerData.julien_fragments_order pour reprendre exactement
# où on en était.

signal finished(solved: bool)

const SheetTexture := preload("res://assets/ui/julien_fragments_sheet.png")
const StoneTexture := preload("res://assets/ui/julien_fragments_stone.png")
const WindowTexture := preload("res://assets/ui/square_window.png")
const DialogueFont := preload("res://assets/fonts/dialogue_latin.fnt")

const FRAGMENT_SIZE := 16
const COLUMNS := 4
const FRAGMENT_COUNT := 20
const SLOT_DISPLAY_SIZE := 48.0
const LABEL_WIDTH := 360.0   # plus large que la grille (4*48=192), pour que les textes d'instruction s'étalent sur moins de lignes

const SELECTED_MODULATE := Color(1.0, 1.0, 0.5)
const NORMAL_MODULATE := Color(1.0, 1.0, 1.0)

var order: Array[int] = []
var slot_buttons: Array[TextureButton] = []
var stone_bgs: Array[TextureRect] = []
var selected_index := -1
var _busy := false   # true pendant l'animation de victoire, ignore les clics/entrées

func _ready() -> void:
	layer = 90   # au-dessus du monde, sous ScreenFade (layer 100)
	_load_or_shuffle_order()
	_build_ui()

func _load_or_shuffle_order() -> void:
	if PlayerData.julien_fragments_order.size() == FRAGMENT_COUNT:
		order = PlayerData.julien_fragments_order.duplicate()
		return
	order = []
	for i in range(FRAGMENT_COUNT):
		order.append(i)
	order.shuffle()
	# Cas limite improbable (mélange qui retombe pile sur la solution) : un
	# seul échange suffit à l'éviter, pour être sûr que le joueur ait bien un
	# puzzle à résoudre.
	if _is_solved():
		var tmp: int = order[0]
		order[0] = order[1]
		order[1] = tmp

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = WindowTexture
	stylebox.texture_margin_left = 12
	stylebox.texture_margin_top = 12
	stylebox.texture_margin_right = 12
	stylebox.texture_margin_bottom = 12
	stylebox.content_margin_left = 20
	stylebox.content_margin_top = 16
	stylebox.content_margin_right = 20
	stylebox.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", stylebox)
	# Léger ton chaud/parchemin sur le cadre (juste cette instance, ne
	# retouche pas square_window.png qui sert partout ailleurs) pour
	# accompagner le fond pierre des fragments.
	panel.modulate = Color(0.96, 0.92, 0.82)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	vbox.add_child(_make_label("Sélectionne deux fragments pour les échanger.", 18))

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	# La grille (192px) est plus étroite que les labels (LABEL_WIDTH) : sans
	# ça elle resterait collée à gauche dans le VBox au lieu d'être centrée.
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	slot_buttons.clear()
	stone_bgs.clear()
	for i in range(FRAGMENT_COUNT):
		var slot := _make_slot(i)
		grid.add_child(slot)

	vbox.add_child(_make_label("Échap : quitter\n(ta progression est gardée)", 14))

	await get_tree().process_frame
	if slot_buttons.size() > 0:
		slot_buttons[0].grab_focus()

func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", DialogueFont)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	return label

# Chaque case = un fond pierre (julien_fragments_stone.png, moucheté/fissuré,
# pour l'aspect "fragment de ruines") derrière le fragment gravé lui-même
# (transparent en dehors de la silhouette/du texte). Les deux sont découpés
# au même index que le fragment affecté à cette case (pas à la position de la
# case) : ainsi le fond "suit" le fragment quand il est échangé, si bien que
# les mouchetures/fissures se raccordent avec leurs voisines une fois le
# puzzle résolu, comme une vraie dalle fissurée qu'on reconstitue.
func _make_slot(index: int) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(SLOT_DISPLAY_SIZE, SLOT_DISPLAY_SIZE)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.texture = _fragment_texture(StoneTexture, order[index])
	wrapper.add_child(bg)
	stone_bgs.append(bg)

	var btn := TextureButton.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.focus_mode = Control.FOCUS_ALL
	btn.pivot_offset = Vector2(SLOT_DISPLAY_SIZE, SLOT_DISPLAY_SIZE) / 2.0
	btn.texture_normal = _fragment_texture(SheetTexture, order[index])
	# Même convention que yes_no_choice.gd/list_picker.gd : le survol souris
	# déplace le focus clavier plutôt que de gérer un indicateur séparé.
	btn.mouse_entered.connect(func(): btn.grab_focus())
	btn.pressed.connect(_on_slot_pressed.bind(index))
	wrapper.add_child(btn)
	slot_buttons.append(btn)

	return wrapper

func _fragment_texture(atlas: Texture2D, fragment_id: int) -> AtlasTexture:
	var col := fragment_id % COLUMNS
	var row := fragment_id / COLUMNS
	var at := AtlasTexture.new()
	at.atlas = atlas
	at.region = Rect2(col * FRAGMENT_SIZE, row * FRAGMENT_SIZE, FRAGMENT_SIZE, FRAGMENT_SIZE)
	return at

func _on_slot_pressed(index: int) -> void:
	if _busy:
		return
	if selected_index == -1:
		selected_index = index
		slot_buttons[index].modulate = SELECTED_MODULATE
		return
	if selected_index == index:
		slot_buttons[index].modulate = NORMAL_MODULATE
		selected_index = -1
		return

	var tmp: int = order[selected_index]
	order[selected_index] = order[index]
	order[index] = tmp
	slot_buttons[selected_index].modulate = NORMAL_MODULATE
	selected_index = -1
	_refresh_textures()

	if _is_solved():
		await _play_success_sequence()

func _refresh_textures() -> void:
	for i in range(FRAGMENT_COUNT):
		slot_buttons[i].texture_normal = _fragment_texture(SheetTexture, order[i])
		stone_bgs[i].texture = _fragment_texture(StoneTexture, order[i])

func _is_solved() -> bool:
	for i in range(FRAGMENT_COUNT):
		if order[i] != i:
			return false
	return true

# Petite animation en cascade (chaque fragment pulse brièvement l'un après
# l'autre) pour que la réussite soit lisible avant le fondu de sortie —
# demandé par Gus, voir la conversation de conception associée à cette quête.
func _play_success_sequence() -> void:
	_busy = true
	PlayerData.julien_fragments_order = order.duplicate()
	for i in range(slot_buttons.size()):
		var btn := slot_buttons[i]
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.08).set_delay(i * 0.02)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	await get_tree().create_timer(slot_buttons.size() * 0.02 + 0.3).timeout

	PlayerData.julien_fragments_solved = true
	await ScreenFade.fade_out()
	finished.emit(true)
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_exit_without_solving()

func _exit_without_solving() -> void:
	PlayerData.julien_fragments_order = order.duplicate()
	finished.emit(false)
	queue_free()
