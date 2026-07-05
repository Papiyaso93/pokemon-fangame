extends CanvasLayer

signal chosen(species: String)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")

@onready var prompt: Label = $Root/Center/Window/Content/Prompt
@onready var buttons_box: VBoxContainer = $Root/Center/Window/Content/Buttons

func setup(species_list: Array[String]) -> void:
	prompt.text = "Lequel choisis-tu comme partenaire ?" if not species_list.is_empty() \
		else "Tu n'as rien attrapé cette fois-ci..."
	for species in species_list:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 0)
		btn.text = species
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
		btn.mouse_exited.connect(func(): btn.icon = null)
		btn.pressed.connect(func(): chosen.emit(species))
		buttons_box.add_child(btn)
