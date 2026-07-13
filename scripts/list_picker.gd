extends CanvasLayer

# Petite liste de choix générique, réutilisée par bag.gd (menu "Utiliser" /
# "Assigner un raccourci", puis choix de la touche) et options_menu.gd (choix
# de l'objet d'un raccourci) — même style que yes_no_choice.gd/
# partner_choice.gd. `setup()` prend une Array de {"label": String,
# "value": Variant} ; `chosen` émet la valeur choisie, ou null si annulé
# (Échap).

signal chosen(value)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0

@onready var window: PanelContainer = $Root/Window
@onready var buttons_box: VBoxContainer = $Root/Window/VBox/Buttons

func _ready() -> void:
	window.visible = false

func setup(options: Array) -> void:
	var first_button: Button = null
	for option in options:
		var opt: Dictionary = option
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 0)
		btn.text = String(opt.get("label", ""))
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = false
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = BlankTexture
		# Même principe que partout ailleurs : le survol souris déplace le
		# focus clavier au lieu de gérer sa propre flèche (évite le double
		# affichage si souris et clavier ne pointent pas le même bouton).
		btn.mouse_entered.connect(func(): btn.grab_focus())
		btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
		btn.focus_exited.connect(func(): btn.icon = BlankTexture)
		var value = opt.get("value")
		btn.pressed.connect(func(): chosen.emit(value))
		buttons_box.add_child(btn)
		if first_button == null:
			first_button = btn
	await get_tree().process_frame
	_place_window()
	window.visible = true
	if first_button:
		first_button.grab_focus()

func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport().get_visible_rect().size
	window.position = Vector2(
		viewport_size.x - MARGIN_RIGHT - min_size.x,
		viewport_size.y - MARGIN_BOTTOM - min_size.y,
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		chosen.emit(null)
