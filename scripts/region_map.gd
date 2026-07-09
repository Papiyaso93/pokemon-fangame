extends CanvasLayer

signal closed

# Carte de Kanto (test) — v1 simple : image statique + une icône par lieu
# (ville/route/grotte, comme la vraie carte du jeu) + un marqueur clignotant
# sur la position actuelle du joueur. Pas de curseur déplaçable (cf.
# discussion avec Gus, on part sur la version simple d'abord). Toute la
# carte est visible dès le départ (fidèle au vrai jeu, pas de brouillard de
# guerre).

# Icône bleue du vrai jeu (pas générée) : cadrée sur le 2e des 2 cadres
# 8x16 empilés du fichier pret (le 1er est un état "non visité" non utilisé
# ici, cf. HANDOFF.md). Utilisée pour les grottes/forêts/îles — PAS les
# routes, qui n'ont aucun repère dans le vrai jeu (confirmé par Gus).
const DungeonIcon := preload("res://assets/ui/region_map_dungeon_icon.png")
# Vraie icône du jeu (pas générée) : petit portrait du joueur, distinct des
# ronds de ville pour ne plus les confondre (signalé par Gus).
const CurrentMarker := preload("res://assets/ui/region_map_player_icon.png")

const DUNGEON_SIZE := Vector2(20, 20)
const PLAYER_SIZE := Vector2(24, 24)

@onready var map_wrap: Control = $Root/Center/Window/VBox/MapWrap
@onready var location_label: Label = $Root/Center/Window/VBox/LocationLabel

func _ready() -> void:
	_place_location_icons()

	var player := get_tree().get_first_node_in_group("player")
	var map_name := String(player.current_map_name) if player else ""
	var pos: Vector2i = RegionMapData.POSITIONS.get(map_name, Vector2i(-1, -1))
	if pos.x >= 0:
		var marker := TextureRect.new()
		marker.texture = CurrentMarker
		marker.custom_minimum_size = PLAYER_SIZE
		marker.expand_mode = 1
		marker.stretch_mode = 0
		map_wrap.add_child(marker)
		_anchor_at(marker, pos, PLAYER_SIZE)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(marker, "modulate:a", 0.2, 0.5)
		tw.tween_property(marker, "modulate:a", 1.0, 0.5)
		location_label.text = MapNames.get_french_name(map_name)
	else:
		location_label.text = "Position inconnue"

# Une icône par position UNIQUE (plusieurs cartes godot peuvent partager la
# même position, ex. les 4 sous-zones de la Zone Safari) — sans ça on
# empilerait des icônes identiques les unes sur les autres pour rien.
# Seuls les donjons (grottes/forêt/îles, cf. _icon_for) reçoivent une icône :
# les villes ont déjà leur point rouge cuit dans le tilemap décodé
# (assets/ui/region_map.png généré par build_region_map.py) et les routes
# n'ont aucun repère dans le vrai jeu (confirmé par Gus) — en ajouter un
# créait soit un doublon désaligné (villes), soit un repère qui n'existe pas
# côté FRLG (routes, on en avait 31 au lieu des 11 vrais repères "donjon").
# **`seen` n'est marqué qu'après un icône réellement dessiné** : un donjon
# peut partager sa case avec une ville (ex. Grotte Cerulean = Doria), qui
# elle ne dessine rien — si on marquait `seen` pour la ville en premier, le
# donjon suivant à la même position serait sauté à tort.
func _place_location_icons() -> void:
	var seen: Dictionary = {}
	for map_name in RegionMapData.POSITIONS:
		var texture := _icon_for(map_name)
		if texture == null:
			continue
		var pos: Vector2i = RegionMapData.POSITIONS[map_name]
		if seen.has(pos):
			continue
		seen[pos] = true
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = DUNGEON_SIZE
		icon.expand_mode = 1
		icon.stretch_mode = 0
		map_wrap.add_child(icon)
		_anchor_at(icon, pos, DUNGEON_SIZE)

func _icon_for(map_name: String) -> Texture2D:
	if map_name.begins_with("cave_") or map_name.begins_with("safari_") \
			or map_name == "viridian_forest" or map_name == "pokemon_mansion" \
			or map_name == "pokemon_tower" or map_name == "power_plant":
		return DungeonIcon
	return null  # ville/route : pas d'icône ajoutée (cf. commentaire ci-dessus)

func _anchor_at(node: Control, pos: Vector2i, size: Vector2) -> void:
	var frac_x := (float(pos.x) + 0.5) / RegionMapData.GRID_COLS
	var frac_y := (float(pos.y) + 0.5) / RegionMapData.GRID_ROWS
	node.anchor_left = frac_x
	node.anchor_right = frac_x
	node.anchor_top = frac_y
	node.anchor_bottom = frac_y
	node.offset_left = -size.x / 2.0
	node.offset_right = size.x / 2.0
	node.offset_top = -size.y / 2.0
	node.offset_bottom = size.y / 2.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
