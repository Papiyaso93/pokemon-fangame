extends CanvasLayer

# Écran de sélection de slot, partagé entre "Nouvelle partie", "Charger une
# partie" et "Sauvegarder" (voir FLOW.md, section 2). Le mode change juste
# quels slots sont cliquables : vides seulement en mode "new", remplis
# seulement en mode "load", tous en mode "save" (le joueur choisit
# délibérément d'écraser un slot existant ou d'en remplir un nouveau). Le
# bouton supprimer est disponible dans tous les modes sur un slot rempli.

signal back_pressed
signal new_game_chosen(slot: int)
signal slot_chosen(slot: int)   # mode "save" : le joueur a choisi où sauvegarder

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")

var mode := "load"   # "new" / "load" / "save", à définir AVANT d'ajouter ce nœud à l'arbre

@onready var rows: VBoxContainer = $Root/Center/Window/Margin/Content/Rows
@onready var title_label: Label = $Root/Center/Window/Margin/Content/Title
@onready var back_button: Button = $Root/Center/Window/Margin/Content/Back

func _ready() -> void:
	match mode:
		"new": title_label.text = "Nouvelle partie"
		"save": title_label.text = "Sauvegarder"
		_: title_label.text = "Charger une partie"
	# "Revenir" est le seul bouton de cet écran avec un texte centré (pas
	# aligné à gauche comme les lignes de slots) — plusieurs tentatives pour
	# rapprocher la flèche du texte centré (icon_alignment=CENTER : flèche
	# invisible ; structure Icon/Label/Spacer façon title_screen.gd : flèche
	# toujours ancrée au bord gauche du bouton) sans résultat propre. Laissé
	# tel quel (flèche à gauche, comme les autres boutons) à la demande de Gus
	# plutôt que de continuer à bricoler.
	_setup_arrow(back_button)
	_refresh()

# Même flèche de sélection que les autres menus de choix (class_choice,
# pause_menu...) — icône réservée par défaut (transparente) pour que la
# largeur du bouton ne change pas au survol. La place de l'icône est toujours
# réservée (interactive ou non) pour que le texte démarre au même endroit sur
# toutes les lignes ; seule une ligne cliquable affiche vraiment la flèche au
# survol (sinon ça donnerait l'impression qu'on peut cliquer dessus).
func _setup_arrow(btn: Button, interactive := true) -> void:
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.expand_icon = false
	btn.icon = BlankTexture
	if interactive:
		btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
		btn.mouse_exited.connect(func(): btn.icon = BlankTexture)

func _refresh() -> void:
	for child in rows.get_children():
		child.queue_free()
	for n in range(SaveManager.SLOT_COUNT):
		rows.add_child(_build_row(n))

func _build_row(n: int) -> Control:
	var summary := SaveManager.slot_summary(n)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var slot_button := Button.new()
	slot_button.custom_minimum_size = Vector2(340, 0)
	slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if summary.empty:
		slot_button.text = "Emplacement %d - Vide" % (n + 1)
		slot_button.disabled = mode == "load"
		if mode == "new":
			slot_button.pressed.connect(func(): _on_slot_chosen(n))
		elif mode == "save":
			slot_button.pressed.connect(func(): slot_chosen.emit(n))
	else:
		var playtime := SaveManager.format_playtime(summary.play_seconds)
		slot_button.text = "%s - %s - %s" % [summary.player_name, summary.map_name, playtime]
		slot_button.disabled = mode == "new"
		if mode == "load":
			slot_button.pressed.connect(func():
				SaveManager.load_from_slot(n)
				# Cet écran est ajouté à la racine du Viewport, pas à la scène
				# courante (piège CanvasLayer imbriqué, voir HANDOFF.md) — il
				# ne serait donc pas libéré automatiquement par le
				# change_scene_to_file déclenché dans load_from_slot(), et
				# resterait affiché par-dessus la partie chargée.
				queue_free()
			)
		elif mode == "save":
			slot_button.pressed.connect(func(): slot_chosen.emit(n))

	# Pas de flèche AU SURVOL sur un slot non cliquable (désactivé) — trompeur
	# sinon, aucun autre bouton désactivé du jeu n'affiche cette affordance —
	# mais la place reste réservée pour garder le texte aligné entre les lignes.
	_setup_arrow(slot_button, not slot_button.disabled)
	row.add_child(slot_button)

	if not summary.empty:
		var delete_button := Button.new()
		delete_button.text = "Supprimer"
		_setup_arrow(delete_button)
		delete_button.pressed.connect(func():
			SaveManager.delete_slot(n)
			_refresh()
		)
		row.add_child(delete_button)

	return row

func _on_slot_chosen(n: int) -> void:
	new_game_chosen.emit(n)

func _on_back_pressed() -> void:
	back_pressed.emit()
