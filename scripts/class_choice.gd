extends Control

signal choice_made(result: String)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")

func _ready() -> void:
	for btn in $Center/Window/Buttons.get_children():
		if btn is Button:
			btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
			btn.mouse_exited.connect(func(): btn.icon = null)

func _on_competiteur_pressed() -> void:
	choice_made.emit("competiteur")

func _on_chercheur_pressed() -> void:
	choice_made.emit("chercheur")

func _on_repeat_pressed() -> void:
	choice_made.emit("repeat")
