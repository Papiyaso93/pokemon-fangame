extends CanvasLayer

signal chosen(species: String)

@onready var prompt: Label = $Root/Center/Content/Prompt
@onready var buttons_box: VBoxContainer = $Root/Center/Content/Buttons

func setup(species_list: Array[String]) -> void:
	prompt.text = "Lequel choisis-tu comme partenaire ?" if not species_list.is_empty() \
		else "Tu n'as rien attrapé cette fois-ci..."
	for species in species_list:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 46)
		btn.text = species
		btn.pressed.connect(func(): chosen.emit(species))
		buttons_box.add_child(btn)
