extends CanvasLayer

# Boîte de dialogue réutilisable (overworld + intro). Affiche une file de
# lignes de texte, avance à l'appui sur "ui_accept" (Entrée / Espace / A).

signal finished

@onready var panel: NinePatchRect = $Panel
@onready var label: Label = $Panel/Label

var queue: Array[String] = []
var active := false

func _ready() -> void:
	visible = false

func say(lines: Array[String]) -> void:
	queue = lines.duplicate()
	active = true
	visible = true
	_show_next()

func _show_next() -> void:
	if queue.is_empty():
		active = false
		visible = false
		finished.emit()
		return
	label.text = String(queue.pop_front())

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_accept"):
		_show_next()
		get_viewport().set_input_as_handled()
