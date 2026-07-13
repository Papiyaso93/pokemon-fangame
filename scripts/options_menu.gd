extends CanvasLayer

# Écran Options : raccourcis objets uniquement pour l'instant (voir
# scripts/key_bindings.gd) — pas de remapping des touches de déplacement/
# validation/annulation, décidé le 13/07/2026. Même style de fenêtre que
# scripts/bag.gd.

signal closed

const ROW_COUNT := 4
const ListPickerScene := preload("res://scenes/ui/list_picker.tscn")

@onready var root: Control = $Root
@onready var window_center: CenterContainer = $Root/Center
@onready var error_label: Label = $Root/Center/Window/VBox/ErrorLabel

var item_buttons: Array[Button] = []
var key_buttons: Array[Button] = []

var capturing_slot := -1   # -1 = pas en train de capturer une touche

func _ready() -> void:
	for i in ROW_COUNT:
		var row := get_node("Root/Center/Window/VBox/Rows/Row%d" % (i + 1))
		var item_button: Button = row.get_node("ItemButton")
		var key_button: Button = row.get_node("KeyButton")
		item_buttons.append(item_button)
		key_buttons.append(key_button)
		item_button.pressed.connect(_pick_item.bind(i))
		key_button.pressed.connect(_start_capture.bind(i))
	_refresh_all()

func _refresh_all() -> void:
	for i in ROW_COUNT:
		_refresh_row(i)

func _refresh_row(slot: int) -> void:
	var item_key: String = KeyBindings.slot_items[slot]
	item_buttons[slot].text = String(KeyBindings.ITEMS.get(item_key, "(aucun)"))
	if capturing_slot != slot:
		key_buttons[slot].text = KeyBindings.key_label(slot)

# Même petite liste de choix que bag.gd (scripts/list_picker.gd) : seulement
# les objets déjà possédés (+ "(aucun)" pour libérer le raccourci) — pas de
# quoi choisir un objet qu'on n'a pas encore. Le menu Options reste affiché
# derrière (pas de window_center masqué) : la fenêtre de choix se pose
# par-dessus, comme partout ailleurs.
func _pick_item(slot: int) -> void:
	var options := []
	for item_key in KeyBindings.ITEMS:
		if KeyBindings.is_item_available(item_key):
			options.append({"label": String(KeyBindings.ITEMS[item_key]), "value": item_key})
	var picker := ListPickerScene.instantiate()
	get_tree().root.add_child(picker)
	picker.setup(options)
	var chosen_key = await picker.chosen
	picker.queue_free()
	if chosen_key != null:
		KeyBindings.assign_item(slot, String(chosen_key))
		_refresh_all()   # l'objet a pu disparaître d'un autre slot (voir assign_item)

func _start_capture(slot: int) -> void:
	capturing_slot = slot
	error_label.text = "Appuie sur une touche pour définir le raccourci"
	# Texte court : la colonne Touche est dimensionnée pour "Aa" pas pour une
	# phrase, un texte long ferait bouger toute la ligne (vécu, cf. Gus).
	key_buttons[slot].text = "..."

func _unhandled_input(event: InputEvent) -> void:
	if capturing_slot >= 0:
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			_try_bind_captured_key(event as InputEventKey)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()

func _try_bind_captured_key(event: InputEventKey) -> void:
	var slot := capturing_slot
	var code := event.physical_keycode
	var error := KeyBindings.validate_new_key(slot, code)
	capturing_slot = -1
	if error.is_empty():
		KeyBindings.rebind(slot, code)
		error_label.text = ""
	else:
		error_label.text = error
	_refresh_row(slot)
