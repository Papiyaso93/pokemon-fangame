extends CanvasLayer

signal choice_made(result: String)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

# Marges pour caler la fenêtre juste au-dessus de la boîte de dialogue
# (offset_top=-168 dans dialogue_box.tscn), même bord droit qu'elle (24px).
const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0

@onready var window: PanelContainer = $Root/Window

func _ready() -> void:
	# Caché tant que _place_window() n'a pas calculé sa position définitive —
	# sinon la fenêtre apparaît une frame en haut à gauche (position par
	# défaut) avant de "sauter" à sa place, un flash bref mais visible.
	window.visible = false
	var first_button: Button = null
	for btn in window.get_node("Buttons").get_children():
		if btn is Button:
			# Icône transparente par défaut (même taille que la flèche) pour que
			# la place soit toujours réservée : la fenêtre ne doit pas changer
			# de largeur quand la flèche apparaît/disparaît au survol.
			btn.icon = BlankTexture
			# Le survol souris déplace le focus clavier au lieu de gérer sa propre
			# flèche : sinon 2 flèches peuvent s'afficher à la fois (une au
			# clavier, une à la souris) si elles ne pointent pas le même bouton.
			btn.mouse_entered.connect(func(): btn.grab_focus())
			btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
			btn.focus_exited.connect(func(): btn.icon = BlankTexture)
			if first_button == null:
				first_button = btn
	await get_tree().process_frame
	_place_window()
	window.visible = true
	# Focus par défaut sur la première option (voir yes_no_choice.gd).
	if first_button:
		first_button.grab_focus()

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

func _on_competiteur_pressed() -> void:
	choice_made.emit("competiteur")

func _on_chercheur_pressed() -> void:
	choice_made.emit("chercheur")

func _on_repeat_pressed() -> void:
	choice_made.emit("repeat")
