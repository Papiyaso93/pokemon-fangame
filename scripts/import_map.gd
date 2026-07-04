@tool
extends EditorScript

# Assemble une scène Godot à partir des artefacts du pipeline (res://generated/).
# Produit scenes/maps/<name>_auto.tscn : TileSet + calques Below/Above + Collision + Player.

const NAME := "pallet_town"
const TILE := 16

func _run() -> void:
	var base := "res://generated/%s" % NAME
	var f := FileAccess.open(base + ".json", FileAccess.READ)
	if f == null:
		push_error("JSON introuvable : %s.json — as-tu rafraîchi le FileSystem ?" % base)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())

	var tex_below := load(base + "_below.png") as Texture2D
	var tex_above := load(base + "_above.png") as Texture2D
	if tex_below == null or tex_above == null:
		push_error("Atlas PNG non importés. Rafraîchis le FileSystem de Godot puis relance.")
		return

	var W: int = data["width"]
	var H: int = data["height"]
	var cols: int = data["atlas_cols"]
	var tiles: Array = data["tiles"]
	var above_flags: Array = data["above"]
	var cells: Array = data["cells"]
	var collision: Array = data["collision"]

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

	# source collision : 1 tuile rouge translucide avec polygone plein
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
	var h := TILE / 2.0
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))

	# ── Scène ──
	var root := Node2D.new()
	root.name = "Node2D"

	var below := TileMapLayer.new(); below.name = "Below"; below.tile_set = ts
	var above := TileMapLayer.new(); above.name = "Above"; above.tile_set = ts
	var coll := TileMapLayer.new(); coll.name = "Collision"; coll.tile_set = ts
	coll.visible = false   # collision invisible par défaut (physique inchangée) ; réaffiche pour debug

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
	player.position = Vector2(11 * TILE, 13 * TILE)   # spawn central approximatif
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:   # borne la caméra aux limites de la map (pas de fond noir hors-map)
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = W * TILE
		cam.limit_bottom = H * TILE

	# ordre de dessin : Below, Player, Above, (Collision au-dessus pour debug)
	root.add_child(below)
	root.add_child(player)
	root.add_child(above)
	root.add_child(coll)
	for c in [below, player, above, coll]:
		c.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var out := "res://scenes/maps/%s.tscn" % NAME
	var err := ResourceSaver.save(packed, out)
	if err != OK:
		push_error("Échec sauvegarde scène : %d" % err)
		return
	print("Scène générée : %s (%dx%d, %d cases)" % [out, W, H, cells.size()])
	print("Ouvre-la dans Godot. Le calque 'Collision' (rouge) est visible pour debug.")
