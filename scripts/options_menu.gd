extends CanvasLayer

# Écran Options : raccourcis objets uniquement pour l'instant (voir
# scripts/key_bindings.gd) — pas de remapping des touches de déplacement/
# validation/annulation, décidé le 13/07/2026. Même style de fenêtre que
# scripts/bag.gd.

signal closed

const ROW_COUNT := 4

@onready var root: Control = $Root
@onready var error_label: Label = $Root/Center/Window/VBox/ErrorLabel

var item_labels: Array[Label] = []
var key_buttons: Array[Button] = []

var capturing_slot := -1   # -1 = pas en train de capturer une touche

func _ready() -> void:
	for i in ROW_COUNT:
		var row := get_node("Root/Center/Window/VBox/Rows/Row%d" % (i + 1))
		var item_label: Label = row.get_node("ItemLabel")
		var key_button: Button = row.get_node("KeyButton")
		item_labels.append(item_label)
		key_buttons.append(key_button)
		row.get_node("ItemLeft").pressed.connect(_cycle_item.bind(i, -1))
		row.get_node("ItemRight").pressed.connect(_cycle_item.bind(i, 1))
		key_button.pressed.connect(_start_capture.bind(i))
	_refresh_all()

func _refresh_all() -> void:
	for i in ROW_COUNT:
		_refresh_row(i)

func _refresh_row(slot: int) -> void:
	var item_key: String = KeyBindings.slot_items[slot]
	item_labels[slot].text = String(KeyBindings.ITEMS.get(item_key, "(aucun)"))
	if capturing_slot != slot:
		key_buttons[slot].text = KeyBindings.key_label(slot)

func _cycle_item(slot: int, direction: int) -> void:
	var keys := KeyBindings.ITEMS.keys()
	var current: String = KeyBindings.slot_items[slot]
	var idx := keys.find(current)
	idx = (idx + direction + keys.size()) % keys.size()
	KeyBindings.assign_item(slot, keys[idx])
	_refresh_row(slot)

func _start_capture(slot: int) -> void:
	capturing_slot = slot
	error_label.text = ""
	key_buttons[slot].text = "Appuie sur une touche..."

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
