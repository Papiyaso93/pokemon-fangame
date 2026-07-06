extends CanvasLayer

# Petite fenêtre de choix Oui/Non générique, même style que class_choice.gd
# (réutilisable pour toute future question fermée, pas juste Anselme).

signal chosen(result: bool)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

# Mêmes marges que class_choice.gd/partner_choice.gd (calée au-dessus de la
# boîte de dialogue, offset_top=-168 dans dialogue_box.tscn).
const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0

@onready var window: PanelContainer = $Root/Window

func _ready() -> void:
	window.visible = false
	for btn in window.get_node("Buttons").get_children():
		if btn is Button:
			btn.icon = BlankTexture
			btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
			btn.mouse_exited.connect(func(): btn.icon = BlankTexture)
	await get_tree().process_frame
	_place_window()
	window.visible = true

func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport().get_visible_rect().size
	window.position = Vector2(
		viewport_size.x - MARGIN_RIGHT - min_size.x,
		viewport_size.y - MARGIN_BOTTOM - min_size.y,
	)

func _on_yes_pressed() -> void:
	chosen.emit(true)

func _on_no_pressed() -> void:
	chosen.emit(false)
