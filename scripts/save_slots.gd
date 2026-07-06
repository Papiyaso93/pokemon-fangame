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

var mode := "load"   # "new" / "load" / "save", à définir AVANT d'ajouter ce nœud à l'arbre

@onready var rows: VBoxContainer = $Root/Center/Window/Margin/Content/Rows
@onready var title_label: Label = $Root/Center/Window/Margin/Content/Title

func _ready() -> void:
	match mode:
		"new": title_label.text = "Nouvelle partie"
		"save": title_label.text = "Sauvegarder"
		_: title_label.text = "Charger une partie"
	_refresh()

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
		slot_button.text = "Emplacement %d — Vide" % (n + 1)
		slot_button.disabled = mode == "load"
		if mode == "new":
			slot_button.pressed.connect(func(): _on_slot_chosen(n))
		elif mode == "save":
			slot_button.pressed.connect(func(): slot_chosen.emit(n))
	else:
		var playtime := SaveManager.format_playtime(summary.play_seconds)
		slot_button.text = "%s — %s — %s" % [summary.player_name, summary.map_name, playtime]
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
	row.add_child(slot_button)

	if not summary.empty:
		var delete_button := Button.new()
		delete_button.text = "Supprimer"
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
