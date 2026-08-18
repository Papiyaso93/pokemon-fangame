class_name TrainerData
extends RefCounted

# Table de dresseurs scriptés pour les combats dresseur — juste Yohan pour ce
# lot (zone 3), pas un portage de trainers.h/trainer_parties.h du vrai jeu.
# Format par entrée : "name", "party" (liste de {"species", "level", "moves"}).
# Voir la conversation de conception (plan lexical-giggling-cocoa.md) pour le
# détail des choix d'espèces/niveaux/movesets, chacun vérifié par simulation.

const TRAINERS := {
	"YOHAN_ZONE3": {
		"name": "Yohan",
		"party": [
			{"species": "primeape", "level": 26, "moves": ["KARATE_CHOP"]},
			{"species": "parasect", "level": 30, "moves": ["SCRATCH"]},
			{"species": "wartortle", "level": 30, "moves": ["WATER_GUN", "RAPID_SPIN"]},
		],
	},
}

# Équipe prêtée par Yohan au joueur pour ce combat (éphémère, pas persistée
# dans PlayerData — voir npc_yohan_zone3.gd).
const PLAYER_LOAN_TEAM := [
	{"species": "poliwhirl", "level": 30, "moves": ["WATER_GUN", "RAIN_DANCE"]},
	{"species": "charmeleon", "level": 30, "moves": ["SCRATCH", "EMBER"]},
	{"species": "ivysaur", "level": 30, "moves": ["VINE_WHIP", "RAZOR_LEAF"]},
]

# Données PROVISOIRES pour "Tester un combat duo" (title_screen.gd) — voir
# la conversation de conception : la zone 4 du Parc Safari introduira le
# rival et l'allié du joueur via un vrai combat duo (2 dresseurs alliés dont
# le joueur, contre 2 dresseurs adverses), mais leurs noms/équipes réels ne
# sont pas encore décidés. Pokémon/sprites de dresseur choisis au hasard
# parmi l'existant pour ce banc d'essai (confirmé par Gus) — à remplacer
# quand la zone 4 sera vraiment construite, ne pas considérer "Rival" comme
# le nom définitif du futur rival.
const DUO_TEST := {
	"ally_name": "Allié",
	# Chemin res:// complet vers un sprite de DOS (l'allié se tient du même
	# côté que le joueur, il doit être vu de dos comme lui) — PAS une clé
	# composée avec assets/characters/custom/battle/ comme les 2 ennemis
	# ci-dessous (portraits de face). Voir battle_intro_duo.gd::_build_ui().
	"ally_sprite_key": "res://assets/characters/rs_may_back.png",
	"ally_party": [
		{"species": "meowth", "level": 29, "moves": ["TACKLE", "SCRATCH"]},
	],
	"enemy1_name": "Rival",
	"enemy1_sprite_key": "zoro",
	"enemy1_party": [
		{"species": "vulpix", "level": 28, "moves": ["EMBER"]},
	],
	"enemy2_name": "Dresseur 2",
	"enemy2_sprite_key": "brock",
	"enemy2_party": [
		{"species": "psyduck", "level": 28, "moves": ["WATER_GUN"]},
	],
}

# Tire le sexe de chaque Pokémon d'une équipe UNE SEULE fois (voir
# BattlePokemon.roll_gender()) et le fixe dans une copie des entrées — à
# appeler une fois au lancement du combat, puis à donner cette même Array
# (pas TRAINERS/PLAYER_LOAN_TEAM directement) à la fois à battle_intro.gd et
# à trainer_battle.gd, pour qu'ils affichent tous les deux le même sexe pour
# le même Pokémon. Copie (duplicate) : ne modifie jamais les const d'origine,
# qui doivent rester rejouables identiques d'un combat à l'autre.
static func roll_genders(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		var copy: Dictionary = (e as Dictionary).duplicate()
		copy["gender"] = BattlePokemon.roll_gender(String(copy["species"]))
		out.append(copy)
	return out
