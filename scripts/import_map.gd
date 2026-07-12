@tool
extends EditorScript

# Assemble les scènes Godot depuis les artefacts du pipeline (res://generated/).
# Une scène par map : TileSet + calques Below/Above/Collision + Player,
# et en métadonnées de la racine : taille de map + connexions (pour les transitions).

const TILE := 16
const MAPS := [
	"celadon_city", "cerulean_city", "cinnabar_island", "fuchsia_city",
	"indigo_plateau_exterior", "lavender_town", "pallet_town", "pewter_city",
	"route1", "route10", "route11", "route12", "route13", "route14", "route15",
	"route16", "route17", "route18", "route19", "route2", "route20",
	"route21_north", "route21_south", "route22", "route23", "route24", "route25",
	"route3", "route4", "route5", "route6", "route7", "route8", "route9",
	"safari_zone_center", "safari_zone_east", "safari_zone_north", "safari_zone_west",
	"saffron_city", "saffron_city_connection", "vermilion_city", "viridian_city",
	"viridian_forest",
	"cave_diglett", "cave_mtmoon", "cave_rocktunnel", "cave_seafoam", "cave_victoryroad",
	"safari_office",
	"safari_rest_house_center", "safari_rest_house_east", "safari_rest_house_north",
	"safari_rest_house_west", "safari_secret_house",
	# "safari_entrance" retiré DEFINITIVEMENT : contient des PNJ + un script de
	# verrouillage ajoutés à la main (setup_safari_entrance_npcs.gd,
	# setup_safari_entrance_gate.gd). Ne JAMAIS le remettre dans cette liste
	# sans avoir prévu de relancer les deux scripts juste après.
]

func _run() -> void:
	for name in MAPS:
		_build(name)

func _build(name: String) -> void:
	var base := "res://generated/%s" % name
	var f := FileAccess.open(base + ".json", FileAccess.READ)
	if f == null:
		push_error("JSON introuvable : %s.json — rafraîchis le FileSystem ?" % base)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())

	var tex_below := load(base + "_below.png") as Texture2D
	var tex_above := load(base + "_above.png") as Texture2D
	if tex_below == null or tex_above == null:
		push_error("Atlas PNG non importés (%s). Rafraîchis le FileSystem." % name)
		return

	var W: int = data["width"]
	var H: int = data["height"]
	var cols: int = data["atlas_cols"]
	var tiles: Array = data["tiles"]
	var above_flags: Array = data["above"]
	var cells: Array = data["cells"]
	var ledges: Array = data.get("ledges", [])
	var grass: Array = data.get("grass", [])
	var collision: Array = data["collision"]
	var connections: Array = data.get("connections", [])
	var warps: Array = data.get("warps", [])
	var show_map_name: bool = data.get("show_map_name", true)
	var elevation: Array = data.get("elevation", [])

	# ── TileSet ──
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src_below := TileSetAtlasSource.new()
	src_below.texture = tex_below
	src_below.texture_region_size = Vector2i(TILE, TILE)
	var src_above := TileSetAtlasSource.new()
	src_above.texture = tex_above
	src_above.texture_region_size = Vector2i(TILE, TILE)
	for k in range(tiles.size()):
		var coord := Vector2i(k % cols, k / cols)
		src_below.create_tile(coord)
		if above_flags[k]:
			src_above.create_tile(coord)

	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 0.35))
	var src_coll := TileSetAtlasSource.new()
	src_coll.texture = ImageTexture.create_from_image(img)
	src_coll.texture_region_size = Vector2i(TILE, TILE)
	src_coll.create_tile(Vector2i(0, 0))

	var id_below := ts.add_source(src_below)
	var id_above := ts.add_source(src_above)
	var id_coll := ts.add_source(src_coll)
	ts.add_physics_layer()
	var td := src_coll.get_tile_data(Vector2i(0, 0), 0)
	td.add_collision_polygon(0)
	var hh := TILE / 2.0
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-hh, -hh), Vector2(hh, -hh), Vector2(hh, hh), Vector2(-hh, hh)]))

	# ── Scène ──
	var root := Node2D.new()
	root.name = "Map"
	root.set_meta("map_size", Vector2i(W, H))
	root.set_meta("connections", connections)
	root.set_meta("ledges", ledges)
	root.set_meta("grass", grass)
	root.set_meta("warps", warps)
	root.set_meta("show_map_name", show_map_name)
	root.set_meta("elevation", elevation)

	# Tri par position Y activé sur la racine : le joueur et les PNJ (ajoutés à
	# la main, voir scripts/npc.gd) se dessinent alors dans le bon ordre l'un
	# par rapport à l'autre selon qui est le plus au sud à l'écran, au lieu de
	# suivre l'ordre fixe d'ajout dans la scène. "Above" garde un z_index
	# supérieur pour continuer à toujours passer devant (cimes d'arbres,
	# rebords de falaise...), peu importe le tri Y.
	root.y_sort_enabled = true

	var below := TileMapLayer.new(); below.name = "Below"; below.tile_set = ts
	var above := TileMapLayer.new(); above.name = "Above"; above.tile_set = ts; above.z_index = 1
	var coll := TileMapLayer.new(); coll.name = "Collision"; coll.tile_set = ts
	coll.visible = false

	for i in range(cells.size()):
		var pos := Vector2i(i % W, i / W)
		var k: int = cells[i]
		var coord := Vector2i(k % cols, k / cols)
		below.set_cell(pos, id_below, coord)
		if above_flags[k]:
			above.set_cell(pos, id_above, coord)
		if collision[i] == 1:
			coll.set_cell(pos, id_coll, Vector2i(0, 0))

	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	var spawn := _find_spawn(collision, W, H)
	player.position = Vector2(spawn) * TILE
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = W * TILE
		cam.limit_bottom = H * TILE

	root.add_child(below)
	root.add_child(player)
	root.add_child(above)
	root.add_child(coll)
	for c in [below, player, above, coll]:
		c.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var out := "res://scenes/maps/%s.tscn" % name
	var err := ResourceSaver.save(packed, out)
	if err != OK:
		push_error("Échec sauvegarde %s : %d" % [name, err])
		return
	print("Scène : %s (%dx%d, %d connexions)" % [out, W, H, connections.size()])

# Case libre proche du centre-bas (spawn par défaut si chargement direct).
func _find_spawn(collision: Array, W: int, H: int) -> Vector2i:
	for y in range(H - 2, 0, -1):
		for dx in [0, 1, -1, 2, -2]:
			var x: int = W / 2 + dx
			if x >= 0 and x < W and collision[y * W + x] == 0:
				return Vector2i(x, y)
	return Vector2i(W / 2, H / 2)
