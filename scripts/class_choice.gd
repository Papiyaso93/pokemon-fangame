extends Control

signal choice_made(result: String)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")

# Marges pour caler la fenêtre juste au-dessus de la boîte de dialogue
# (offset_top=-168 dans dialogue_box.tscn), même bord droit qu'elle (24px).
const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0

@onready var window: PanelContainer = $Window

func _ready() -> void:
	for btn in window.get_node("Buttons").get_children():
		if btn is Button:
			btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
			btn.mouse_exited.connect(func(): btn.icon = null)
	await get_tree().process_frame
	_place_window()

# Taille la fenêtre à son contenu (PanelContainer ne le fait pas tout seul
# hors d'un Container parent) et la cale en haut à droite de la boîte de
# dialogue plutôt qu'au centre de l'écran.
func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport_rect().size
	window.position = Vector2(
		viewport_size.x - MARGIN_RIGHT - min_size.x,
		viewport_size.y - MARGIN_BOTTOM - min_size.y,
	)

func _on_competiteur_pressed() -> void:
	choice_made.emit("competiteur")

func _on_chercheur_pressed() -> void:
	choice_made.emit("chercheur")

func _on_repeat_pressed() -> void:
	choice_made.emit("repeat")
