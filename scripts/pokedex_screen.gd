extends CanvasLayer

signal closed

# Pokédex (test, cf. HANDOFF.md) — v1 volontairement simple : liste triée par
# n° de Dex national + fiche détail (sprite, catégorie, taille/poids,
# description). Pas de cri, pas de page Zone, pas de recherche par catégorie/
# tri alternatif pour l'instant (décision de Gus, on construit d'abord la
# base). Accessible depuis le Sac (test), poche Objets Clés — pas encore un
# vrai objet possédé, juste une entrée fixe en attendant de définir à quel
# moment le joueur l'obtient réellement.

const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const ArrowTexture := preload("res://assets/ui/choice_arrow.png")

@onready var stats_label: Label = $Root/Center/Window/VBox/StatsLabel
@onready var list_page: Control = $Root/Center/Window/VBox/ListPage
@onready var rows_box: VBoxContainer = $Root/Center/Window/VBox/ListPage/Scroll/Buttons
@onready var detail_page: Control = $Root/Center/Window/VBox/DetailPage
@onready var detail_sprite: TextureRect = $Root/Center/Window/VBox/DetailPage/HBox/Sprite
@onready var detail_title: Label = $Root/Center/Window/VBox/DetailPage/HBox/Info/Title
@onready var detail_category: Label = $Root/Center/Window/VBox/DetailPage/HBox/Info/Category
@onready var detail_size: Label = $Root/Center/Window/VBox/DetailPage/HBox/Info/Size
@onready var detail_description: Label = $Root/Center/Window/VBox/DetailPage/Description
@onready var hint: Label = $Root/Center/Window/VBox/Hint

var sorted_keys: Array[String] = []

func _ready() -> void:
	for key in SpeciesData.SPECIES:
		sorted_keys.append(key)
	sorted_keys.sort_custom(func(a, b): return SpeciesData.SPECIES[a]["dex_number"] < SpeciesData.SPECIES[b]["dex_number"])
	_build_list()
	_update_stats()
	detail_page.visible = false
	list_page.visible = true
	hint.text = "Échap : revenir"

func _update_stats() -> void:
	stats_label.text = "Vu : %d   Capturé : %d   /   %d" % [
		PlayerData.pokedex_seen.size(), PlayerData.pokedex_caught.size(), sorted_keys.size(),
	]

func _build_list() -> void:
	for key in sorted_keys:
		var sp: Dictionary = SpeciesData.SPECIES[key]
		var seen: bool = key in PlayerData.pokedex_seen
		var caught: bool = key in PlayerData.pokedex_caught
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 0)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = false
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if seen:
			var suffix := "" if caught else " (vu)"
			btn.text = "N°%03d — %s%s" % [sp["dex_number"], sp["name"], suffix]
		else:
			btn.text = "N°%03d — ???" % sp["dex_number"]
			btn.disabled = true
			btn.modulate.a = 0.5
		if seen:
			btn.icon = BlankTexture
			btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
			btn.mouse_exited.connect(func(): btn.icon = BlankTexture)
			btn.pressed.connect(_show_detail.bind(key))
		rows_box.add_child(btn)

func _show_detail(key: String) -> void:
	var sp: Dictionary = SpeciesData.SPECIES[key]
	detail_sprite.texture = load("res://assets/pokemon/%s/front.png" % key)
	detail_title.text = "N°%03d %s" % [sp["dex_number"], sp["name"]]
	detail_category.text = "Pokémon %s" % sp["category"]
	detail_size.text = "%.1f m   /   %.1f kg" % [sp["height_dm"] / 10.0, sp["weight_hg"] / 10.0]
	detail_description.text = sp["description"]
	list_page.visible = false
	detail_page.visible = true
	hint.text = "Échap : liste"

func _close_detail() -> void:
	detail_page.visible = false
	list_page.visible = true
	hint.text = "Échap : revenir"

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if detail_page.visible:
		_close_detail()
	else:
		closed.emit()
		queue_free()
