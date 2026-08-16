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
