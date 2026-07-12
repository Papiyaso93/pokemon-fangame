extends Node

# Noms français officiels des lieux de Kanto (vérifiés, pas improvisés — cf.
# Poképédia/Pokébip), indexés par nom de scène (scripts/import_map.gd::MAPS /
# kanto-pipeline/build_godot.py::MAPS). Utilisé par location_banner.gd.

const NAMES := {
	"pallet_town": "Bourg Palette",
	"viridian_city": "Jadielle",
	"pewter_city": "Argenta",
	"cerulean_city": "Azuria",
	"vermilion_city": "Carmin-sur-Mer",
	"lavender_town": "Lavanville",
	"celadon_city": "Céladopole",
	"fuchsia_city": "Parmanie",
	"saffron_city": "Safrania",
	"saffron_city_connection": "Safrania",
	"cinnabar_island": "Cramois'Île",
	"indigo_plateau_exterior": "Plateau Indigo",
	"viridian_forest": "Forêt de Jade",
	"route1": "Route 1", "route2": "Route 2", "route3": "Route 3",
	"route4": "Route 4", "route5": "Route 5", "route6": "Route 6",
	"route7": "Route 7", "route8": "Route 8", "route9": "Route 9",
	"route10": "Route 10", "route11": "Route 11", "route12": "Route 12",
	"route13": "Route 13", "route14": "Route 14", "route15": "Route 15",
	"route16": "Route 16", "route17": "Route 17", "route18": "Route 18",
	"route19": "Route 19", "route20": "Route 20",
	"route21_north": "Route 21", "route21_south": "Route 21",
	"route22": "Route 22", "route23": "Route 23", "route24": "Route 24",
	"route25": "Route 25",
	"cave_diglett": "Grotte Taupiqueur",
	"cave_mtmoon": "Mont Sélénite",
	"cave_rocktunnel": "Grotte",
	"cave_seafoam": "Îles Écume",
	"cave_victoryroad": "Route Victoire",
	"safari_zone_center": "Parc Safari - Zone 1",
	"safari_zone_east": "Parc Safari - Zone 2",
	"safari_zone_north": "Parc Safari - Zone 3",
	"safari_zone_west": "Parc Safari - Zone 4",
	"safari_office": "Zone Safari",
	"safari_entrance": "Zone Safari",
}

func get_french_name(scene_id: String) -> String:
	return NAMES.get(scene_id, scene_id)
