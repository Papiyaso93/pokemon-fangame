extends CanvasLayer

# Saisie du nom : la question ("Quel est ton nom ?") est posée dans une boîte
# de dialogue classique tenue ouverte par l'appelant (character_creation.gd),
# cette fenêtre ne contient que le champ de texte + le bouton de validation,
# même principe que class_choice.gd/partner_choice.gd.

signal confirmed(chosen_name: String)

const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0

@onready var window: PanelContainer = $Root/Window
@onready var name_edit: LineEdit = $Root/Window/VBox/NameEdit
@onready var confirm_button: Button = $Root/Window/VBox/Confirm

func _ready() -> void:
	# Caché tant que _place_window() n'a pas calculé sa position définitive
	# (même piège que class_choice.gd : sinon flash en haut à gauche).
	window.visible = false
	name_edit.max_length = PlayerData.NAME_MAX_LENGTH
	name_edit.text_submitted.connect(_on_confirm)
	confirm_button.pressed.connect(func(): _on_confirm(name_edit.text))
	await get_tree().process_frame
	_place_window()
	window.visible = true
	name_edit.grab_focus()

func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport().get_visible_rect().size
	window.position = Vector2(
		viewport_size.x - MARGIN_RIGHT - min_size.x,
		viewport_size.y - MARGIN_BOTTOM - min_size.y,
	)

func _on_confirm(text: String) -> void:
	var n := text.strip_edges()
	if n.is_empty():
		return
	confirmed.emit(n)
