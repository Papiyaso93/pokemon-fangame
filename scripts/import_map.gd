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
	# safari_zone_center/east/north/west : ces 4 cartes portent aussi
	# metadata/grass_zone et metadata/water_zone (id de sous-zone d'herbe/plan
	# d'eau, voir scripts/safari_encounters.gd, tables de rencontre par
	# sous-zone) — recalculées automatiquement ci-dessous à chaque passage
	# (voir _compute_tile_zones()), pas besoin d'y penser en relançant ce script.
	"safari_zone_center", "safari_zone_east", "safari_zone_north", "safari_zone_west",
	"saffron_city", "saffron_city_connection", "vermilion_city", "viridian_city",
	"viridian_forest",
	"cave_diglett", "cave_mtmoon", "cave_rocktunnel", "cave_seafoam", "cave_victoryroad",
	"safari_office",
	# "safari_entrance" retiré DEFINITIVEMENT : contient des PNJ + un script de
	# verrouillage ajoutés à la main (setup_safari_entrance_npcs.gd,
	# setup_safari_entrance_gate.gd). Ne JAMAIS le remettre dans cette liste
	# sans avoir prévu de relancer les deux scripts juste après.
	#
	# "safari_rest_house_center/east/north/west" retirés le 13/07/2026 : PNJ
	# Camille/Yohan ajoutés à la main dedans (voir npc_camille_zone1/2.gd,
	# npc_yohan_zone3/4.gd), perdus une première fois en régénérant sans faire
	# attention. Si un changement de terrain est vraiment nécessaire, il faut
	# régénérer le JSON (build_godot.py), patcher le .tscn à la main pour n'y
	# reporter QUE le changement de terrain/warps, puis revérifier que les PNJ
	# sont toujours là — jamais via ce script tant qu'ils sont dedans.
	#
	# "safari_secret_house" retiré le 13/07/2026, même raison : PNJ Anselme
	# ajouté à la main dedans (voir npc_anselme_park.gd, beat 3b).
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
	var water: Array = data.get("water", [])
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
	root.set_meta("water", water)
	root.set_meta("grass_zone", _compute_tile_zones(grass, W, H))
	root.set_meta("water_zone", _compute_tile_zones(water, W, H))
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

	# Verrou de progression du Parc Safari (voir acte1-parc-safari.md) : zone
	# suivante bloquée tant qu'on n'a pas parlé au PNJ de la zone précédente.
	# Attaché ici (pas juste posé à la main dans les .tscn) pour survivre à
	# une régénération — un premier oubli l'avait fait disparaître le
	# 13/07/2026.
	const SAFARI_ZONE_NAMES := [
		"safari_zone_center", "safari_zone_east", "safari_zone_north", "safari_zone_west",
	]
	if name in SAFARI_ZONE_NAMES:
		root.set_script(load("res://scripts/safari_zone_gate.gd"))

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

# Sous-groupes de tuiles plus petits que ça (buissons/mares décoratifs isolés)
# fusionnent dans le groupe voisin le plus proche au lieu de former leur propre
# zone de rencontre — voir _compute_tile_zones().
const SMALL_ZONE_THRESHOLD := 10

# Segmente un tableau de booléens (grass/water) en zones connexes (4-voisins),
# fusionne les groupes plus petits que SMALL_ZONE_THRESHOLD dans le plus proche
# des "grands" groupes, et renvoie un tableau parallèle id de zone (1..N, 0 =
# hors de ce tableau) — les zones sont numérotées par taille décroissante
# (H1/E1 = la plus grande), pour rester cohérent avec acte1-parc-safari.md et
# scripts/safari_encounters.gd (tables de rencontre par sous-zone, clé
# "<carte>:<id_zone>"). Sans effet sur les cartes hors Parc Safari (grass/water
# vides → tableau de zéros).
func _compute_tile_zones(flags: Array, w: int, h: int) -> Array:
	var zone_of_tile := []
	zone_of_tile.resize(flags.size())
	zone_of_tile.fill(0)
	if flags.is_empty():
		return zone_of_tile

	var visited := []
	visited.resize(flags.size())
	visited.fill(false)
	var clusters: Array = []
	for start in range(flags.size()):
		if not flags[start] or visited[start]:
			continue
		var queue: Array = [start]
		visited[start] = true
		var tiles: Array = []
		while not queue.is_empty():
			var idx: int = queue.pop_front()
			tiles.append(idx)
			var x := idx % w
			var y := idx / w
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					var nidx := ny * w + nx
					if flags[nidx] and not visited[nidx]:
						visited[nidx] = true
						queue.append(nidx)
		clusters.append(tiles)

	# Tri par taille décroissante ; à taille égale, par plus petit index de
	# tuile (= ordre de découverte) — déterministe, pour ne pas dépendre de la
	# stabilité de sort_custom() et toujours retomber sur la même numérotation
	# d'une régénération à l'autre.
	clusters.sort_custom(func(a, b):
		if a.size() != b.size():
			return a.size() > b.size()
		return a[0] < b[0]
	)

	var big: Array = []
	var small: Array = []
	for c in clusters:
		if c.size() >= SMALL_ZONE_THRESHOLD:
			big.append(c)
		else:
			small.append(c)

	for zid in range(big.size()):
		for idx in big[zid]:
			zone_of_tile[idx] = zid + 1

	for s in small:
		var best_zid := -1
		var best_dist := -1
		for zid in range(big.size()):
			var d: int = _min_tile_distance(s, big[zid], w)
			if best_dist == -1 or d < best_dist:
				best_dist = d
				best_zid = zid
		if best_zid >= 0:
			for idx in s:
				zone_of_tile[idx] = best_zid + 1

	return zone_of_tile

func _min_tile_distance(tiles_a: Array, tiles_b: Array, w: int) -> int:
	var best := -1
	for a in tiles_a:
		var ax := a % w
		var ay := a / w
		for b in tiles_b:
			var bx := b % w
			var by := b / w
			var d: int = abs(ax - bx) + abs(ay - by)
			if best == -1 or d < best:
				best = d
	return best
