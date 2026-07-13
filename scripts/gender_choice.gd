extends CanvasLayer

# Fenêtre de choix seule (les options, rien d'autre) — la question
# ("Es-tu un garçon ou une fille ?") s'affiche dans une boîte de dialogue
# classique tenue ouverte par l'appelant (character_creation.gd), même
# principe que class_choice.gd.

signal chosen(gender: String)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0

@onready var window: PanelContainer = $Root/Window

func _ready() -> void:
	window.visible = false
	var first_button: Button = null
	for btn in window.get_node("Buttons").get_children():
		if btn is Button:
			btn.icon = BlankTexture
			# Le survol souris déplace le focus clavier au lieu de gérer sa propre
			# flèche : sinon 2 flèches peuvent s'afficher à la fois (une au
			# clavier, une à la souris) si elles ne pointent pas le même bouton.
			btn.mouse_entered.connect(func(): btn.grab_focus())
			btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
			btn.focus_exited.connect(func(): btn.icon = BlankTexture)
			if first_button == null:
				first_button = btn
	await get_tree().process_frame
	_place_window()
	window.visible = true
	# Focus par défaut sur la première option (voir yes_no_choice.gd).
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

func _on_boy_pressed() -> void:
	chosen.emit("male")

func _on_girl_pressed() -> void:
	chosen.emit("female")
