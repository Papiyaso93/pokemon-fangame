extends Node2D

const CharacterCreationScene := preload("res://scenes/ui/character_creation.tscn")

@onready var dialogue: CanvasLayer = $DialogueBox

func _ready() -> void:
	dialogue.finished.connect(_on_intro_dialogue_finished)
	var lines: Array[String] = [
		"Excusez-moi...",
		"Excusez-moi !",
		"Vous devez remplir ce formulaire avant de passer à la suite.",
	]
	dialogue.say(lines)

func _on_intro_dialogue_finished() -> void:
	var creation := CharacterCreationScene.instantiate()
	add_child(creation)
	creation.creation_finished.connect(_on_creation_finished)

func _on_creation_finished() -> void:
	print("Création terminée : %s, %s, apparence=%s" % [
		PlayerData.player_name, PlayerData.gender, PlayerData.appearance])
