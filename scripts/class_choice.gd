extends Control

signal choice_made(result: String)

func _on_competiteur_pressed() -> void:
	choice_made.emit("competiteur")

func _on_chercheur_pressed() -> void:
	choice_made.emit("chercheur")

func _on_repeat_pressed() -> void:
	choice_made.emit("repeat")
