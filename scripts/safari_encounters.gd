class_name SafariEncounters
extends RefCounted

# Tables de rencontre du Parc Safari, une par zone d'herbe/plan d'eau (voir
# acte1-parc-safari.md et scripts/import_map.gd::grass_zone/water_zone pour
# savoir quelle zone est laquelle sur le terrain). Poids fidèles à la structure
# du vrai jeu (pret src/data/wild_encounters.json) : terre = 20/20/10/10/10/10/
# 5/5/4/4/1/1 (queue rareté), Surf = 60/30/5/4/1, Canne = 40/40/15/4/1 (on n'a
# qu'une seule canne pour l'instant, pas de distinction Vieille/Bonne/Super).
# Générées le 14/07/2026 à partir du tableau de rareté validé avec Gus — ne pas
# hésiter à ajuster à la main si les tests en jeu révèlent un déséquilibre.

# clé = "<nom_carte>:<id_zone>" (id_zone = grass_zone/water_zone de la tuile,
# voir player.gd::_grass_zone_at()/_water_zone_at()). Valeur = liste de
# {species, weight} — pick_species() fait un tirage pondéré dessus.
const LAND := {
	"safari_zone_center:1": [
		{"species": "weedle", "weight": 20},  # Aspicot
		{"species": "caterpie", "weight": 20},  # Chenipan
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "abra", "weight": 10},  # Abra
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "venonat", "weight": 5},  # Mimitoss
		{"species": "paras", "weight": 5},  # Paras
		{"species": "hitmonchan", "weight": 4},  # Tygnon
		{"species": "hitmonlee", "weight": 4},  # Kicklee
		{"species": "scyther", "weight": 1},  # Insécateur
		{"species": "pinsir", "weight": 1},  # Scarabrute
	],
	"safari_zone_center:2": [
		{"species": "pidgey", "weight": 20},  # Roucool
		{"species": "rattata", "weight": 20},  # Rattata
		{"species": "nidoran_f", "weight": 10},  # Nidoran♀
		{"species": "abra", "weight": 10},  # Abra
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "drowzee", "weight": 5},  # Soporifik
		{"species": "slowpoke", "weight": 5},  # Ramoloss
		{"species": "exeggcute", "weight": 4},  # Noeunoeuf
		{"species": "jynx", "weight": 4},  # Lippoutou
		{"species": "mr_mime", "weight": 1},  # M. Mime
		{"species": "eevee", "weight": 1},  # Évoli
	],
	"safari_zone_center:3": [
		{"species": "oddish", "weight": 20},  # Mystherbe
		{"species": "bellsprout", "weight": 20},  # Chétiflor
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "abra", "weight": 10},  # Abra
		{"species": "grimer", "weight": 5},  # Tadmorv
		{"species": "koffing", "weight": 5},  # Smogo
		{"species": "tangela", "weight": 4},  # Saquedeneu
		{"species": "lickitung", "weight": 4},  # Excelangue
		{"species": "bulbasaur", "weight": 1},  # Bulbizarre
		{"species": "porygon", "weight": 1},  # Porygon
	],
	"safari_zone_center:4": [
		{"species": "meowth", "weight": 20},  # Miaouss
		{"species": "spearow", "weight": 20},  # Piafabec
		{"species": "nidoran_f", "weight": 10},  # Nidoran♀
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "abra", "weight": 10},  # Abra
		{"species": "magnemite", "weight": 5},  # Magnéti
		{"species": "machop", "weight": 5},  # Machoc
		{"species": "electabuzz", "weight": 4},  # Élektek
		{"species": "pikachu", "weight": 4},  # Pikachu
		{"species": "kangaskhan", "weight": 1},  # Kangourex
		{"species": "ditto", "weight": 1},  # Métamorph
	],
	"safari_zone_center:5": [
		{"species": "rattata", "weight": 20},  # Rattata
		{"species": "pidgey", "weight": 20},  # Roucool
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "nidoran_f", "weight": 10},  # Nidoran♀
		{"species": "seel", "weight": 5},  # Otaria
		{"species": "slowpoke", "weight": 5},  # Ramoloss
		{"species": "hitmonlee", "weight": 4},  # Kicklee
		{"species": "tangela", "weight": 4},  # Saquedeneu
		{"species": "squirtle", "weight": 1},  # Carapuce
		{"species": "eevee", "weight": 1},  # Évoli
	],
	"safari_zone_east:1": [
		{"species": "sandshrew", "weight": 20},  # Sabelette
		{"species": "geodude", "weight": 20},  # Racaillou
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "abra", "weight": 10},  # Abra
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "machop", "weight": 5},  # Machoc
		{"species": "doduo", "weight": 5},  # Doduo
		{"species": "rhyhorn", "weight": 4},  # Rhinocorne
		{"species": "lickitung", "weight": 4},  # Excelangue
		{"species": "onix", "weight": 1},  # Onix
		{"species": "tauros", "weight": 1},  # Tauros
	],
	"safari_zone_east:2": [
		{"species": "spearow", "weight": 20},  # Piafabec
		{"species": "pidgey", "weight": 20},  # Roucool
		{"species": "nidoran_f", "weight": 10},  # Nidoran♀
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "abra", "weight": 10},  # Abra
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "farfetchd", "weight": 5},  # Canarticho
		{"species": "voltorb", "weight": 5},  # Voltorbe
		{"species": "exeggcute", "weight": 4},  # Noeunoeuf
		{"species": "electabuzz", "weight": 4},  # Élektek
		{"species": "scyther", "weight": 1},  # Insécateur
		{"species": "pinsir", "weight": 1},  # Scarabrute
	],
	"safari_zone_east:3": [
		{"species": "weedle", "weight": 20},  # Aspicot
		{"species": "bellsprout", "weight": 20},  # Chétiflor
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "abra", "weight": 10},  # Abra
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "grimer", "weight": 5},  # Tadmorv
		{"species": "koffing", "weight": 5},  # Smogo
		{"species": "tangela", "weight": 4},  # Saquedeneu
		{"species": "jynx", "weight": 4},  # Lippoutou
		{"species": "bulbasaur", "weight": 1},  # Bulbizarre
		{"species": "ditto", "weight": 1},  # Métamorph
	],
	"safari_zone_east:4": [
		{"species": "meowth", "weight": 20},  # Miaouss
		{"species": "rattata", "weight": 20},  # Rattata
		{"species": "nidoran_f", "weight": 10},  # Nidoran♀
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "abra", "weight": 10},  # Abra
		{"species": "magnemite", "weight": 5},  # Magnéti
		{"species": "clefairy", "weight": 5},  # Mélofée
		{"species": "hitmonlee", "weight": 4},  # Kicklee
		{"species": "pikachu", "weight": 4},  # Pikachu
		{"species": "kangaskhan", "weight": 1},  # Kangourex
		{"species": "eevee", "weight": 1},  # Évoli
	],
	"safari_zone_east:5": [
		{"species": "pidgey", "weight": 20},  # Roucool
		{"species": "caterpie", "weight": 20},  # Chenipan
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "nidoran_f", "weight": 10},  # Nidoran♀
		{"species": "seel", "weight": 5},  # Otaria
		{"species": "slowpoke", "weight": 5},  # Ramoloss
		{"species": "hitmonchan", "weight": 4},  # Tygnon
		{"species": "lickitung", "weight": 4},  # Excelangue
		{"species": "squirtle", "weight": 1},  # Carapuce
		{"species": "porygon", "weight": 1},  # Porygon
	],
	"safari_zone_north:1": [
		{"species": "caterpie", "weight": 20},  # Chenipan
		{"species": "oddish", "weight": 20},  # Mystherbe
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "abra", "weight": 10},  # Abra
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "paras", "weight": 5},  # Paras
		{"species": "venonat", "weight": 5},  # Mimitoss
		{"species": "tangela", "weight": 4},  # Saquedeneu
		{"species": "lickitung", "weight": 4},  # Excelangue
		{"species": "bulbasaur", "weight": 1},  # Bulbizarre
		{"species": "scyther", "weight": 1},  # Insécateur
	],
	"safari_zone_north:2": [
		{"species": "sandshrew", "weight": 20},  # Sabelette
		{"species": "vulpix", "weight": 5},  # Goupix
		{"species": "nidoran_f", "weight": 10},  # Nidoran♀
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "abra", "weight": 10},  # Abra
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "growlithe", "weight": 5},  # Caninos
		{"species": "cubone", "weight": 5},  # Osselait
		{"species": "rhyhorn", "weight": 4},  # Rhinocorne
		{"species": "magmar", "weight": 4},  # Magmar
		{"species": "charmander", "weight": 1},  # Salamèche
		{"species": "onix", "weight": 1},  # Onix
	],
	"safari_zone_north:3": [
		{"species": "weedle", "weight": 20},  # Aspicot
		{"species": "meowth", "weight": 20},  # Miaouss
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "abra", "weight": 10},  # Abra
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "grimer", "weight": 5},  # Tadmorv
		{"species": "koffing", "weight": 5},  # Smogo
		{"species": "jynx", "weight": 4},  # Lippoutou
		{"species": "hitmonchan", "weight": 4},  # Tygnon
		{"species": "mr_mime", "weight": 1},  # M. Mime
		{"species": "ditto", "weight": 1},  # Métamorph
	],
	"safari_zone_north:4": [
		{"species": "pidgey", "weight": 20},  # Roucool
		{"species": "rattata", "weight": 20},  # Rattata
		{"species": "nidoran_f", "weight": 10},  # Nidoran♀
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "abra", "weight": 10},  # Abra
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "slowpoke", "weight": 5},  # Ramoloss
		{"species": "seel", "weight": 5},  # Otaria
		{"species": "exeggcute", "weight": 4},  # Noeunoeuf
		{"species": "hitmonlee", "weight": 4},  # Kicklee
		{"species": "squirtle", "weight": 1},  # Carapuce
		{"species": "eevee", "weight": 1},  # Évoli
	],
	"safari_zone_north:5": [
		{"species": "spearow", "weight": 20},  # Piafabec
		{"species": "bellsprout", "weight": 20},  # Chétiflor
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "abra", "weight": 10},  # Abra
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "psyduck", "weight": 5},  # Psykokwak
		{"species": "voltorb", "weight": 5},  # Voltorbe
		{"species": "electabuzz", "weight": 4},  # Élektek
		{"species": "pikachu", "weight": 4},  # Pikachu
		{"species": "tauros", "weight": 1},  # Tauros
		{"species": "porygon", "weight": 1},  # Porygon
	],
	"safari_zone_west:1": [
		{"species": "ekans", "weight": 20},  # Abo
		{"species": "zubat", "weight": 20},  # Nosferapti
		{"species": "diglett", "weight": 20},  # Taupiqueur
		{"species": "nidoran_m", "weight": 10},  # Nidoran♂
		{"species": "krabby", "weight": 10},  # Krabby
		{"species": "abra", "weight": 10},  # Abra
		{"species": "poliwag", "weight": 10},  # Ptitard
		{"species": "mankey", "weight": 5},  # Férosinge
		{"species": "ponyta", "weight": 5},  # Ponyta
		{"species": "shellder", "weight": 5},  # Kokiyas
		{"species": "jigglypuff", "weight": 5},  # Rondoudou
		{"species": "hitmonlee", "weight": 4},  # Kicklee
		{"species": "lickitung", "weight": 4},  # Excelangue
		{"species": "chansey", "weight": 1},  # Leveinard
		{"species": "snorlax", "weight": 1},  # Ronflex
		{"species": "gastly", "weight": 5},  # Fantominus
	],
}

const SURF := {
	"safari_zone_center:1": [
		{"species": "psyduck", "weight": 60},  # Psykokwak
		{"species": "seel", "weight": 30},  # Otaria
		{"species": "slowpoke", "weight": 5},  # Ramoloss
		{"species": "tentacool", "weight": 4},  # Tentacool
		{"species": "lapras", "weight": 1},  # Lokhlass
	],
	"safari_zone_east:1": [
		{"species": "psyduck", "weight": 60},  # Psykokwak
		{"species": "slowpoke", "weight": 30},  # Ramoloss
		{"species": "seel", "weight": 5},  # Otaria
		{"species": "tentacool", "weight": 4},  # Tentacool
		{"species": "lapras", "weight": 1},  # Lokhlass
	],
	"safari_zone_north:1": [
		{"species": "psyduck", "weight": 60},  # Psykokwak
		{"species": "seel", "weight": 30},  # Otaria
		{"species": "slowpoke", "weight": 5},  # Ramoloss
		{"species": "tentacool", "weight": 4},  # Tentacool
		{"species": "lapras", "weight": 1},  # Lokhlass
	],
	"safari_zone_north:2": [
		{"species": "psyduck", "weight": 60},  # Psykokwak
		{"species": "slowpoke", "weight": 30},  # Ramoloss
		{"species": "krabby", "weight": 5},  # Krabby
		{"species": "seel", "weight": 4},  # Otaria
		{"species": "horsea", "weight": 1},  # Hypotrempe
	],
	"safari_zone_north:3": [
		{"species": "horsea", "weight": 60},  # Hypotrempe
		{"species": "staryu", "weight": 30},  # Stari
		{"species": "krabby", "weight": 5},  # Krabby
		{"species": "seel", "weight": 4},  # Otaria
		{"species": "lapras", "weight": 1},  # Lokhlass
	],
	"safari_zone_west:1": [
		{"species": "psyduck", "weight": 60},  # Psykokwak
		{"species": "seel", "weight": 30},  # Otaria
		{"species": "slowpoke", "weight": 5},  # Ramoloss
		{"species": "tentacool", "weight": 4},  # Tentacool
		{"species": "lapras", "weight": 1},  # Lokhlass
	],
}

const FISH := {
	"safari_zone_center:1": [
		{"species": "magikarp", "weight": 40},  # Magicarpe
		{"species": "goldeen", "weight": 40},  # Poissirène
		{"species": "krabby", "weight": 15},  # Krabby
		{"species": "staryu", "weight": 4},  # Stari
		{"species": "dratini", "weight": 1},  # Minidraco
	],
	"safari_zone_east:1": [
		{"species": "magikarp", "weight": 40},  # Magicarpe
		{"species": "goldeen", "weight": 40},  # Poissirène
		{"species": "horsea", "weight": 15},  # Hypotrempe
		{"species": "staryu", "weight": 4},  # Stari
		{"species": "dratini", "weight": 1},  # Minidraco
	],
	"safari_zone_north:1": [
		{"species": "magikarp", "weight": 40},  # Magicarpe
		{"species": "goldeen", "weight": 40},  # Poissirène
		{"species": "krabby", "weight": 15},  # Krabby
		{"species": "staryu", "weight": 4},  # Stari
		{"species": "dratini", "weight": 1},  # Minidraco
	],
	"safari_zone_north:2": [
		{"species": "magikarp", "weight": 40},  # Magicarpe
		{"species": "goldeen", "weight": 40},  # Poissirène
		{"species": "poliwag", "weight": 15},  # Ptitard
		{"species": "krabby", "weight": 4},  # Krabby
		{"species": "staryu", "weight": 1},  # Stari
	],
	"safari_zone_north:3": [
		{"species": "goldeen", "weight": 40},  # Poissirène
		{"species": "horsea", "weight": 40},  # Hypotrempe
		{"species": "staryu", "weight": 15},  # Stari
		{"species": "dratini", "weight": 4},  # Minidraco
		{"species": "lapras", "weight": 1},  # Lokhlass
	],
	"safari_zone_west:1": [
		{"species": "magikarp", "weight": 40},  # Magicarpe
		{"species": "goldeen", "weight": 40},  # Poissirène
		{"species": "krabby", "weight": 15},  # Krabby
		{"species": "staryu", "weight": 4},  # Stari
		{"species": "dratini", "weight": 1},  # Minidraco
	],
}

# Tirage pondéré fidèle à ChooseWildMonIndex_* (pret src/wild_encounter.c) :
# somme des poids, tirage dans cette plage, on retourne le premier dont la
# borne cumulée dépasse le tirage. Marche quelle que soit la somme des poids
# (pas besoin que ça fasse exactement 100, voir la zone Ouest qui en a plus).
static func pick_species(table: Array) -> String:
	var total := 0
	for entry in table:
		total += int(entry["weight"])
	var roll := randi() % total
	var cumulative := 0
	for entry in table:
		cumulative += int(entry["weight"])
		if roll < cumulative:
			return String(entry["species"])
	return String(table[-1]["species"])
