extends Node2D

const CharacterCreationScene := preload("res://scenes/ui/character_creation.tscn")

@onready var dialogue: CanvasLayer = $DialogueBox

func _ready() -> void:
	dialogue.finished.connect(_on_intro_dialogue_finished)
	var lines: Array[String] = [
		"Bonjour !",
		"J'imagine que tu es là pour choisir ta future classe.",
		"Avant de commencer, remplis ce formulaire.",
	]
	dialogue.say(lines)

func _on_intro_dialogue_finished() -> void:
	var creation := CharacterCreationScene.instantiate()
	add_child(creation)
	creation.creation_finished.connect(_on_creation_finished)

func _on_creation_finished() -> void:
	Transitions.pending = true
	Transitions.direct = true
	Transitions.direct_tile = Vector2i(5, 5)
	Transitions.facing = "east"
	get_tree().change_scene_to_file("res://scenes/maps/safari_entrance.tscn")
