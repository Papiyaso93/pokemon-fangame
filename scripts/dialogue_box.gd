extends CanvasLayer

# Boîte de dialogue réutilisable (overworld + intro). Affiche une file de
# lignes de texte, effet machine à écrire (fidèle FRLG), avance à l'appui sur
# "ui_accept" (Entrée / Espace / A) — un appui pendant l'écriture affiche le
# reste du texte instantanément ; un appui une fois complet passe à la ligne
# suivante. Flèche de continuation (vrais sprites FRLG) tant qu'il reste du
# texte à afficher.

signal finished

const CHAR_DELAY := 0.02   # secondes entre chaque caractère
const ARROW_BLINK := 0.3   # secondes entre les 2 frames de la flèche

@onready var panel: NinePatchRect = $Panel
@onready var label: Label = $Panel/Label
@onready var arrow: TextureRect = $Panel/Arrow

var queue: Array[String] = []
var active := false

var current_text := ""
var revealed := 0
var typing := false
var char_timer := 0.0

var arrow_frame := 0
var arrow_timer := 0.0
const ARROW_TEXTURES := [
	preload("res://assets/ui/down_arrow_3.png"),
	preload("res://assets/ui/down_arrow_4.png"),
]

func _ready() -> void:
	visible = false
	arrow.visible = false

func say(lines: Array[String]) -> void:
	queue = lines.duplicate()
	active = true
	visible = true
	_show_next()

func _show_next() -> void:
	arrow.visible = false
	if queue.is_empty():
		active = false
		visible = false
		finished.emit()
		return
	current_text = String(queue.pop_front())
	revealed = 0
	typing = true
	char_timer = 0.0
	label.text = ""

func _process(delta: float) -> void:
	if typing:
		char_timer += delta
		while char_timer >= CHAR_DELAY and revealed < current_text.length():
			char_timer -= CHAR_DELAY
			revealed += 1
			label.text = current_text.substr(0, revealed)
		if revealed >= current_text.length():
			typing = false
			arrow.visible = not queue.is_empty()
	elif arrow.visible:
		arrow_timer += delta
		if arrow_timer >= ARROW_BLINK:
			arrow_timer = 0.0
			arrow_frame = 1 - arrow_frame
			arrow.texture = ARROW_TEXTURES[arrow_frame]

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_accept"):
		if typing:
			revealed = current_text.length()
			label.text = current_text
			typing = false
			arrow.visible = not queue.is_empty()
		else:
			_show_next()
		get_viewport().set_input_as_handled()
