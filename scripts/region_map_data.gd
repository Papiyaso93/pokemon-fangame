class_name RegionMapData
extends RefCounted

# Positions extraites des vraies données FRLG (kanto-pipeline/pokefirered/
# src/data/region_map/region_map_layout_kanto.h, grille MAPSEC_* 22x15) —
# converties de (row, col) vers Vector2i(col, row) pour un usage direct comme
# fraction de position (col/GRID_COLS, row/GRID_ROWS) sur assets/ui/region_map.png.
# Plusieurs cartes godot peuvent partager la même position (ex. les 4
# sous-zones + bâtiments de la Zone Safari, qui n'ont qu'un seul repère dans
# le vrai jeu).

const GRID_COLS := 22
const GRID_ROWS := 15

const POSITIONS := {
	"pallet_town": Vector2i(4, 11),
	"viridian_city": Vector2i(4, 8),
	"pewter_city": Vector2i(4, 4),
	"cerulean_city": Vector2i(14, 3),
	"vermilion_city": Vector2i(14, 9),
	"celadon_city": Vector2i(11, 6),
	"fuchsia_city": Vector2i(12, 12),
	"saffron_city": Vector2i(14, 6),
	"saffron_city_connection": Vector2i(14, 6),
	"cinnabar_island": Vector2i(4, 14),
	"lavender_town": Vector2i(18, 6),
	"indigo_plateau_exterior": Vector2i(2, 3),
	"viridian_forest": Vector2i(4, 6),

	"route1": Vector2i(4, 9),
	"route2": Vector2i(4, 6),
	"route3": Vector2i(6, 4),
	"route4": Vector2i(11, 3),
	"route5": Vector2i(14, 4),
	"route6": Vector2i(14, 7),
	"route7": Vector2i(12, 6),
	"route8": Vector2i(16, 6),
	"route9": Vector2i(16, 3),
	"route10": Vector2i(18, 4),
	"route11": Vector2i(16, 9),
	"route12": Vector2i(18, 9),
	"route13": Vector2i(16, 11),
	"route14": Vector2i(15, 11),
	"route15": Vector2i(13, 12),
	"route16": Vector2i(8, 6),
	"route17": Vector2i(7, 9),
	"route18": Vector2i(9, 12),
	"route19": Vector2i(12, 13),
	"route20": Vector2i(8, 14),
	"route21_north": Vector2i(4, 12),
	"route21_south": Vector2i(4, 13),
	"route22": Vector2i(2, 8),
	"route23": Vector2i(2, 5),
	"route24": Vector2i(14, 1),
	"route25": Vector2i(15, 1),

	"safari_zone_center": Vector2i(12, 12),
	"safari_zone_east": Vector2i(12, 12),
	"safari_zone_north": Vector2i(12, 12),
	"safari_zone_west": Vector2i(12, 12),
	"safari_office": Vector2i(12, 12),
	"safari_entrance": Vector2i(12, 12),

	"cave_mtmoon": Vector2i(9, 3),
	"cave_rocktunnel": Vector2i(18, 3),
	"cave_diglett": Vector2i(4, 5),
	"cave_seafoam": Vector2i(8, 14),
	"cave_victoryroad": Vector2i(2, 4),
}
