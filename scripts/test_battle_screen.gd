extends CanvasLayer

# Écran de combat "test" (voir écran-titre > Tester > Tester des sprites) :
# affiche juste le(s) portrait(s) de combat d'un ou plusieurs dresseurs en
# grand, côte à côte, aucune mécanique réelle derrière — sert seulement à
# juger/comparer le rendu visuel de sprites 64x64 façon front_pic.

signal finished

# Un seul dresseur : mets juste sa clé ici. Plusieurs à comparer : sépare-les
# par des virgules (voir npc_test_sprite.gd::test_battle_trainer).
@export var trainer_key := ""

@onready var portraits_row: HBoxContainer = $Root/Center/VBox/PortraitsRow

const PORTRAIT_SIZE := Vector2(192, 192)

func _ready() -> void:
	for key in trainer_key.split(",", false):
		key = key.strip_edges()
		var path := "res://assets/characters/custom/battle/%s.png" % key
		if not ResourceLoader.exists(path):
			continue
		var vbox := VBoxContainer.new()
		var portrait := TextureRect.new()
		portrait.texture = load(path)
		portrait.custom_minimum_size = PORTRAIT_SIZE
		portrait.texture_filter = 1   # nearest, cf. encounter.tscn/dialogue_box.tscn
		portrait.expand_mode = 1
		portrait.stretch_mode = 5
		vbox.add_child(portrait)
		var label := Label.new()
		label.text = key
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
		portraits_row.add_child(vbox)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finished.emit()
