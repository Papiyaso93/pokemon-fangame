extends Node

# Autoload : moteur de sauvegarde/chargement. 3 slots, un fichier JSON par
# slot dans user://saves/. Ne connaît que ce qui existe réellement dans le
# jeu aujourd'hui (PlayerData, SafariState, position/carte du joueur, temps
# de jeu) — pas d'équipe/inventaire/quêtes, ces systèmes n'existent pas encore
# (voir FLOW.md, section 6).

const SLOT_COUNT := 3
const SAVE_DIR := "user://saves/"

var current_slot := -1   # slot actif de la partie en cours ; -1 = aucune partie chargée
var play_seconds := 0.0

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _process(delta: float) -> void:
	if current_slot >= 0:
		play_seconds += delta

func slot_path(n: int) -> String:
	return SAVE_DIR + "slot_%d.json" % n

func has_save(n: int) -> bool:
	return FileAccess.file_exists(slot_path(n))

# Premier slot libre, ou -1 si les SLOT_COUNT slots sont tous remplis.
func first_empty_slot() -> int:
	for n in range(SLOT_COUNT):
		if not has_save(n):
			return n
	return -1

# Résumé léger pour l'écran de slots, sans affecter l'état courant du jeu.
func slot_summary(n: int) -> Dictionary:
	if not has_save(n):
		return {"empty": true}
	var data := _read_slot(n)
	if data.is_empty():
		return {"empty": true}
	return {
		"empty": false,
		"player_name": String(data.get("player_name", "")),
		"map_name": MapNames.get_french_name(String(data.get("map_name", ""))),
		"play_seconds": float(data.get("play_seconds", 0.0)),
	}

func _read_slot(n: int) -> Dictionary:
	var f := FileAccess.open(slot_path(n), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func format_playtime(seconds: float) -> String:
	var total_minutes := int(seconds) / 60
	return "%d:%02d" % [total_minutes / 60, total_minutes % 60]

# Capture l'état courant (PlayerData, SafariState, position/carte du joueur
# via la zone effective sous ses pieds — fonctionne aussi en plein monde
# seamless, pas juste sur la scène chargée) et l'écrit dans le slot `n`.
func save_to_slot(n: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var tile := Vector2i(roundi(player.position.x / player.TILE_SIZE), roundi(player.position.y / player.TILE_SIZE))
	var res: Array = player._zone_and_local_tile(tile)
	var zone = res[0]
	var local_tile: Vector2i = res[1]
	var map_name: String = zone.name if zone != null else player.origin_map_name

	var data := {
		"player_name": PlayerData.player_name,
		"gender": PlayerData.gender,
		"appearance": PlayerData.appearance,
		"orientation_given": PlayerData.orientation_given,
		"chosen_class": PlayerData.chosen_class,
		"intro_complete": PlayerData.intro_complete,
		"starter_species": PlayerData.starter_species,
		"pokedex_seen": PlayerData.pokedex_seen,
		"pokedex_caught": PlayerData.pokedex_caught,
		"map_name": map_name,
		"tile_x": local_tile.x,
		"tile_y": local_tile.y,
		"facing": player.facing,
		"safari_active": SafariState.active,
		"safari_balls": SafariState.balls,
		"safari_caught": SafariState.caught,
		"play_seconds": play_seconds,
	}
	var f := FileAccess.open(slot_path(n), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	current_slot = n

# Restaure PlayerData/SafariState/temps de jeu, puis déclenche le changement
# de scène via le même mécanisme que les warps (Transitions.direct) —
# player.gd n'a besoin d'aucune connaissance du système de sauvegarde.
func load_from_slot(n: int) -> void:
	var data := _read_slot(n)
	if data.is_empty():
		return

	PlayerData.player_name = String(data.get("player_name", "Red"))
	PlayerData.gender = String(data.get("gender", "male"))
	PlayerData.appearance = String(data.get("appearance", "red_normal"))
	PlayerData.orientation_given = bool(data.get("orientation_given", false))
	PlayerData.chosen_class = String(data.get("chosen_class", ""))
	PlayerData.intro_complete = bool(data.get("intro_complete", false))
	PlayerData.starter_species = String(data.get("starter_species", ""))
	var seen: Array[String] = []
	for s in data.get("pokedex_seen", []):
		seen.append(String(s))
	PlayerData.pokedex_seen = seen
	var caught_dex: Array[String] = []
	for s in data.get("pokedex_caught", []):
		caught_dex.append(String(s))
	PlayerData.pokedex_caught = caught_dex

	SafariState.active = bool(data.get("safari_active", false))
	SafariState.balls = int(data.get("safari_balls", SafariState.STARTING_BALLS))
	var caught: Array[String] = []
	for s in data.get("safari_caught", []):
		caught.append(String(s))
	SafariState.caught = caught

	play_seconds = float(data.get("play_seconds", 0.0))
	current_slot = n

	Transitions.pending = true
	Transitions.direct = true
	Transitions.direct_tile = Vector2i(int(data.get("tile_x", 0)), int(data.get("tile_y", 0)))
	Transitions.facing = String(data.get("facing", "south"))
	get_tree().change_scene_to_file("res://scenes/maps/%s.tscn" % String(data.get("map_name", "pallet_town")))

func delete_slot(n: int) -> void:
	if has_save(n):
		DirAccess.remove_absolute(slot_path(n))
