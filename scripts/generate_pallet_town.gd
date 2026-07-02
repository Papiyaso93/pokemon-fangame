@tool
extends EditorScript

const GRASS = Vector2i(1, 1)
const TREE  = Vector2i(5, 0)
const PATH  = Vector2i(0, 3)
const WATER = Vector2i(6, 0)

const MAP = [
	"TTTTTTTTTTTTTTTTTTTT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGGBBBBGGGGBBBBBBGGT",
	"TGGBBBBGGGGBBBBBBGGT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGGGGGBBBBBBBBBBGGGT",
	"TGGGGGBBBBBBBBBBGGGT",
	"TGGGGGBBBBBBBBBBGGGT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGWWWGGGGGGGGGGGGGT",
	"TGWWWGGGGGGGGGGGGGT",
	"TGWWWGGGGGGGGGGGGGT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGGGGGGGGGGGGGGGGGGT",
	"TGGGGGGGPPPGGGGGGGGT",
	"TTTTTTTTPPPTTTTTTTTT",
]

const TILE_TYPES = {
	"G": GRASS, "T": TREE, "P": PATH, "W": WATER, "B": GRASS,
}

func _run() -> void:
	var scene = get_scene()
	var tilemap = scene.get_node("TileMap")
	if not tilemap:
		push_error("TileMap introuvable dans la scene !")
		return
	tilemap.clear()
	for row in range(MAP.size()):
		for col in range(MAP[row].length()):
			var c = MAP[row][col]
			tilemap.set_cell(0, Vector2i(col, row), 0, TILE_TYPES.get(c, GRASS))
	print("Bourg Palette genere !")
