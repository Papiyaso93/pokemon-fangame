extends CanvasLayer

# Fenêtre de choix seule (les options, rien d'autre) — la question elle-même
# s'affiche dans une boîte de dialogue classique tenue ouverte par l'appelant
# (voir safari_entrance_gate.gd), fidèle au même principe que class_choice.gd.

signal chosen(species: String)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

# Marges pour caler la fenêtre juste au-dessus de la boîte de dialogue
# (offset_top=-168 dans dialogue_box.tscn), même bord droit qu'elle (24px).
const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0

@onready var window: PanelContainer = $Root/Window
@onready var buttons_box: VBoxContainer = $Root/Window/Buttons

func _ready() -> void:
	# Caché tant que _place_window() n'a pas calculé sa position définitive —
	# sinon la fenêtre apparaît une frame en haut à gauche (position par
	# défaut) avant de "sauter" à sa place, un flash bref mais visible.
	window.visible = false

func setup(species_list: Array[String]) -> void:
	for species in species_list:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 0)
		btn.text = species
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = false
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = BlankTexture
		btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
		btn.mouse_exited.connect(func(): btn.icon = BlankTexture)
		btn.pressed.connect(func(): chosen.emit(species))
		buttons_box.add_child(btn)
	await get_tree().process_frame
	_place_window()
	window.visible = true

# Taille la fenêtre à son contenu (PanelContainer ne le fait pas tout seul
# hors d'un Container parent) et la cale en haut à droite de la boîte de
# dialogue plutôt qu'au centre de l'écran.
func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport().get_visible_rect().size
	window.position = Vector2(
		viewport_size.x - MARGIN_RIGHT - min_size.x,
		viewport_size.y - MARGIN_BOTTOM - min_size.y,
	)
