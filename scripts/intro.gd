extends Node2D

const CharacterCreationScene := preload("res://scenes/ui/character_creation.tscn")

@onready var dialogue: CanvasLayer = $DialogueBox

func _ready() -> void:
	dialogue.finished.connect(_on_intro_dialogue_finished)
	var lines: Array[String] = [
		"Bienvenue à Kanto !",
		"Tu n'es pas la première personne à débarquer ici les mains vides et pleine d'espoir. Et tu seras loin d'être la dernière.",
		"Mais avant de rêver, on fait les choses dans l'ordre : dis-moi qui tu es.",
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
	# Même fondu que tous les warps du jeu (ScreenFade) — sans ça, le passage de
	# l'écran noir à la carte était un cut sec (signalé par Gus). Le fondu
	# retour se déclenche déjà tout seul côté player.gd (fin de _load_world()).
	await ScreenFade.fade_out()
	get_tree().change_scene_to_file("res://scenes/maps/safari_entrance.tscn")
