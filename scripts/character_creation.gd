extends Node

# Orchestrateur pur : ne possède aucun visuel propre, enchaîne 3 étapes
# (nom -> genre -> apparence), chacune avec une question posée dans une
# boîte de dialogue classique (tenue ouverte, comme partout ailleurs dans le
# jeu) suivie d'une fenêtre dédiée pour la réponse. Le fond noir vient de
# intro.tscn (déjà présent, cette scène est ajoutée par-dessus).

signal creation_finished

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const NameEntryScene := preload("res://scenes/ui/name_entry.tscn")
const GenderChoiceScene := preload("res://scenes/ui/gender_choice.tscn")
const AppearanceChoiceScene := preload("res://scenes/ui/appearance_choice.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await _ask_name()
	await _ask_gender()
	await _ask_appearance()
	creation_finished.emit()

func _ask_name() -> void:
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	var question: Array[String] = ["Quel est ton nom ? (%d caractères max)" % PlayerData.NAME_MAX_LENGTH]
	dialogue.say(question)
	await dialogue.page_typed
	dialogue.active = false

	var entry := NameEntryScene.instantiate()
	get_tree().current_scene.add_child(entry)
	var chosen_name: String = await entry.confirmed
	entry.queue_free()
	dialogue.queue_free()
	PlayerData.player_name = chosen_name

func _ask_gender() -> void:
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	var question: Array[String] = ["Es-tu un garçon ou une fille ?"]
	dialogue.say(question)
	await dialogue.page_typed
	dialogue.active = false

	var choice := GenderChoiceScene.instantiate()
	get_tree().current_scene.add_child(choice)
	var gender: String = await choice.chosen
	choice.queue_free()
	dialogue.queue_free()
	PlayerData.gender = gender

func _ask_appearance() -> void:
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	var question: Array[String] = ["Choisis ton apparence."]
	dialogue.say(question)
	await dialogue.page_typed
	dialogue.active = false

	var choice := AppearanceChoiceScene.instantiate()
	get_tree().current_scene.add_child(choice)
	choice.setup(PlayerData.APPEARANCES[PlayerData.gender])
	var index: int = await choice.chosen
	choice.queue_free()
	dialogue.queue_free()
	PlayerData.appearance = PlayerData.APPEARANCES[PlayerData.gender][index]
