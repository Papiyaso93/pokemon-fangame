extends CanvasLayer

# Petite fenêtre de choix Oui/Non générique, même style que class_choice.gd
# (réutilisable pour toute future question fermée, pas juste Anselme).

signal chosen(result: bool)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

# Mêmes marges que class_choice.gd/partner_choice.gd (calée au-dessus de la
# boîte de dialogue, offset_top=-168 dans dialogue_box.tscn).
const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0

# Index du bouton (0 = Oui, 1 = Non) qui reçoit le focus par défaut. À régler
# par l'appelant juste après instantiate(), AVANT add_child() (donc avant que
# _ready() ne tourne) — utile pour les confirmations destructrices (quitter
# sans sauvegarder, etc.) où on ne veut surtout pas qu'un appui rapide et
# habituel sur la touche d'action valide "Oui" par réflexe.
var default_focus_index := 0

@onready var window: PanelContainer = $Root/Window

func _ready() -> void:
	window.visible = false
	var buttons: Array[Button] = []
	for btn in window.get_node("Buttons").get_children():
		if btn is Button:
			btn.icon = BlankTexture
			# Le survol souris déplace le focus clavier au lieu de gérer sa propre
			# flèche : sinon on peut se retrouver avec 2 flèches affichées à la
			# fois (une au clavier, une à la souris) si les deux ne pointent pas
			# le même bouton (vécu, cf. Gus).
			btn.mouse_entered.connect(func(): btn.grab_focus())
			btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
			btn.focus_exited.connect(func(): btn.icon = BlankTexture)
			buttons.append(btn)
	await get_tree().process_frame
	_place_window()
	window.visible = true
	# Focus par défaut : jouable au clavier direct (flèches pour changer,
	# touche d'action pour valider) sans passer par la souris (demandé par
	# Gus, cf. mêmes fenêtres de choix dans tout le jeu).
	if default_focus_index < buttons.size():
		buttons[default_focus_index].grab_focus()

func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport().get_visible_rect().size
	window.position = Vector2(
		viewport_size.x - MARGIN_RIGHT - min_size.x,
		viewport_size.y - MARGIN_BOTTOM - min_size.y,
	)

func _on_yes_pressed() -> void:
	chosen.emit(true)

func _on_no_pressed() -> void:
	chosen.emit(false)
