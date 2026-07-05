class_name AbilityEngine
extends RefCounted
## Moteur de talents : point d'entree unique pour tous les effets d'abilities.
## L'ability portee par un BattlePokemon est libre (mon.ability) : rien n'empeche
## d'assigner un talent hors de son pool "canonique" pour du homebrew d'equilibrage
## (ex: donner Sable Stream a Onix). Cette V1 couvre les talents presents sur le
## roster actuel + quelques classiques (Levitate, Flash Fire, Water/Volt Absorb)
## utiles pour du homebrew futur. Pas les ~300 talents du jeu complet : chaque
## nouveau talent s'ajoute ici, dans les memes points d'accroche, sans rien casser.

const WEATHER_SETTERS := {
	"drizzle": "rain",
	"drought": "sun",
	"sand-stream": "sandstorm",
	"snow-warning": "hail",
}

const SPEED_WEATHER_ABILITIES := {
	"swift-swim": "rain",
	"chlorophyll": "sun",
	"sand-rush": "sandstorm",
	"slush-rush": "hail",
}

const STARTER_BOOST := {
	"overgrow": "grass", "blaze": "fire", "torrent": "water", "swarm": "bug",
}

const WEATHER_CHIP_IMMUNE_ABILITIES := ["overcoat", "magic-guard"]

## Tous les talents avec un effet reel en combat dans cette V1 (pour peupler les
## menus du team builder). Assignable a n'importe quel Pokemon, homebrew inclus.
const ALL_IMPLEMENTED_ABILITIES := [
	"intimidate", "drizzle", "drought", "sand-stream", "snow-warning",
	"swift-swim", "chlorophyll", "sand-rush", "slush-rush",
	"overgrow", "blaze", "torrent", "swarm",
	"guts", "reckless", "analytic", "sniper", "moxie", "anger-point",
	"vital-spirit", "insomnia", "shed-skin", "regenerator",
	"levitate", "water-absorb", "volt-absorb", "flash-fire", "lightning-rod",
	"solid-rock", "filter", "sturdy", "overcoat", "magic-guard", "ice-body",
	"thick-fat", "immunity", "limber", "water-veil", "magma-armor",
	"huge-power", "pure-power", "speed-boost", "multiscale",
	"inner-focus", "damp", "rock-head", "keen-eye", "hyper-cutter",
	"clear-body", "white-smoke", "shell-armor", "battle-armor", "hustle",
	"rain-dish", "oblivious", "own-tempo", "scrappy", "unnerve",
	"synchronize", "sand-veil", "snow-cloak", "technician", "adaptability",
	"stench", "serene-grace",
]

## Descriptions FR courtes, partagees par l'editeur de donnees et les apercus
## de Pokemon en combat/selection.
const ABILITY_DESCRIPTIONS_FR := {
	"intimidate": "Baisse l'Attaque de l'adversaire d'un cran a l'entree.",
	"drizzle": "Declenche la Pluie a l'entree.",
	"drought": "Declenche le Soleil ardent a l'entree.",
	"sand-stream": "Declenche une Tempete de sable a l'entree.",
	"snow-warning": "Declenche la Grele a l'entree.",
	"swift-swim": "Vitesse doublee sous la pluie.",
	"chlorophyll": "Vitesse doublee sous le soleil.",
	"sand-rush": "Vitesse doublee sous la tempete de sable.",
	"slush-rush": "Vitesse doublee sous la grele.",
	"overgrow": "Attaques Plante boostees (x1.5) sous 1/3 PV.",
	"blaze": "Attaques Feu boostees (x1.5) sous 1/3 PV.",
	"torrent": "Attaques Eau boostees (x1.5) sous 1/3 PV.",
	"swarm": "Attaques Insecte boostees (x1.5) sous 1/3 PV.",
	"guts": "Attaques physiques boostees si statue (et brulure n'affaiblit pas l'Attaque).",
	"reckless": "Attaques a recul boostees (x1.2).",
	"analytic": "Degats boostes (x1.3) si ce Pokemon agit en dernier.",
	"sniper": "Degats des coups critiques boostes (x1.5 supplementaire).",
	"moxie": "Attaque +1 apres avoir mis KO un adversaire.",
	"anger-point": "Attaque au maximum apres avoir subi un coup critique.",
	"vital-spirit": "Immunise contre le sommeil.",
	"insomnia": "Immunise contre le sommeil.",
	"shed-skin": "Chance de guerir d'un statut chaque fin de tour.",
	"regenerator": "Recupere 1/3 des PV max en quittant le terrain (switch volontaire).",
	"levitate": "Immunise contre les attaques Sol.",
	"water-absorb": "Immunise contre les attaques Eau, qui soignent 1/4 des PV max a la place.",
	"volt-absorb": "Immunise contre les attaques Electrik, qui soignent 1/4 des PV max a la place.",
	"flash-fire": "Immunise contre les attaques Feu, qui boostent les attaques Feu (x1.5) a la place.",
	"lightning-rod": "Immunise contre les attaques Electrik, qui boostent l'Attaque Speciale (+1) a la place.",
	"solid-rock": "Reduit de 25% les degats des attaques super efficaces.",
	"filter": "Reduit de 25% les degats des attaques super efficaces.",
	"sturdy": "Survit a 1 PV a une attaque qui l'aurait KO en un coup depuis les PV max.",
	"overcoat": "Immunise contre les degats de meteo (Tempete de sable/Grele).",
	"magic-guard": "Immunise contre les degats de meteo (Tempete de sable/Grele).",
	"ice-body": "Se soigne au lieu de subir des degats sous la Grele.",
	"thick-fat": "Reduit de 50% les degats des attaques Feu et Glace.",
	"immunity": "Immunise contre le poison.",
	"limber": "Immunise contre la paralysie.",
	"water-veil": "Immunise contre la brulure.",
	"magma-armor": "Immunise contre le gel.",
	"huge-power": "Double la stat d'Attaque.",
	"pure-power": "Double la stat d'Attaque.",
	"speed-boost": "Vitesse +1 a chaque fin de tour.",
	"multiscale": "Reduit de 50% les degats subis a PV pleins.",
	"inner-focus": "Immunise contre l'apeurement (flinch).",
	"damp": "Empeche Explosion/Deflagration (les deux camps) tant qu'il est sur le terrain.",
	"rock-head": "Immunise contre le contrecoup des attaques a recul.",
	"keen-eye": "Immunise contre la baisse de Precision infligee par l'adversaire.",
	"hyper-cutter": "Immunise contre la baisse d'Attaque infligee par l'adversaire.",
	"clear-body": "Immunise contre toute baisse de statistique infligee par l'adversaire.",
	"white-smoke": "Immunise contre toute baisse de statistique infligee par l'adversaire.",
	"shell-armor": "Les coups critiques sont impossibles contre ce Pokemon.",
	"battle-armor": "Les coups critiques sont impossibles contre ce Pokemon.",
	"hustle": "Attaque +50%, mais Precision -20% sur les attaques physiques.",
	"rain-dish": "Recupere 1/16 des PV max chaque tour sous la Pluie.",
	"oblivious": "Immunise contre la Provocation et contre l'Intimidation.",
	"own-tempo": "Immunise contre l'Intimidation.",
	"scrappy": "Immunise contre l'Intimidation.",
	"unnerve": "Empeche l'adversaire de manger sa baie tant qu'il est sur le terrain.",
	"synchronize": "Renvoie le poison/la brulure/la paralysie infliges a l'auteur de l'attaque.",
	"sand-veil": "Esquive amelioree (-20% precision adverse) sous la Tempete de sable.",
	"snow-cloak": "Esquive amelioree (-20% precision adverse) sous la Grele.",
	"technician": "Boost (x1.5) les attaques de 60 de puissance ou moins.",
	"adaptability": "Le bonus STAB passe de x1.5 a x2.",
	"stench": "10% de chances d'apeurer la cible a chaque attaque sans effet d'apeurement deja prevu.",
	"serene-grace": "Double la chance de declenchement des effets secondaires.",
}


## Declenche a l'entree sur le terrain (envoi initial ou remplacement).
static func on_switch_in(state: BattleState, team: BattleTeam, mon: BattlePokemon) -> void:
	if mon.is_fainted():
		return

	if mon.ability == "intimidate":
		var opp := state.other_team(team).active()
		if not opp.is_fainted():
			if blocks_intimidate(opp):
				state.add_log("%s est protege(e) de l'Intimidation par son talent !" % GameData.fr_species(opp.species_name))
			else:
				var before: int = opp.stat_stages["attack"]
				opp.stat_stages["attack"] = clampi(before - 1, -6, 6)
				state.add_log("%s intimide %s ! Son Attaque baisse." % [GameData.fr_species(mon.species_name), GameData.fr_species(opp.species_name)])

	if WEATHER_SETTERS.has(mon.ability):
		_set_weather(state, WEATHER_SETTERS[mon.ability], mon)


static func _set_weather(state: BattleState, weather: String, setter: BattlePokemon) -> void:
	if state.weather == weather:
		return
	state.weather = weather
	# Bug confirme : la meteo posee par un talent restait active indefiniment
	# (jamais decrementee) au lieu de durer 5 tours comme dans les jeux
	# recents (Gen6+), meme duree que la meteo posee par une attaque -- seuls
	# les Roches (Chaude/Humide/Lisse/Glace) l'etendent a 8 tours.
	state.weather_turns_left = 5 + ItemEngine.weather_duration_bonus(setter, weather)
	state.add_log("%s declenche : %s !" % [GameData.fr_species(setter.species_name), GameData.fr_weather(weather)])


## Declenche quand un Pokemon quitte le terrain (switch volontaire, pas un KO).
static func on_switch_out(mon: BattlePokemon) -> void:
	if mon.ability == "regenerator" and not mon.is_fainted():
		mon.heal(int(mon.max_hp / 3))


## Declenche sur l'attaquant quand son coup vient de mettre KO le defenseur.
static func on_ko_scored(state: BattleState, mon: BattlePokemon) -> void:
	if mon.ability == "moxie":
		mon.stat_stages["attack"] = clampi(mon.stat_stages["attack"] + 1, -6, 6)
		state.add_log("%s gagne en assurance ! (Attaque +1)" % GameData.fr_species(mon.species_name))


## Declenche sur le defenseur quand il vient de subir un coup critique.
static func on_crit_received(mon: BattlePokemon) -> void:
	if mon.ability == "anger-point":
		mon.stat_stages["attack"] = 6


## Immunites de statut liees au talent (a ne pas confondre avec les immunites
## de type, gerees a part dans BattleEngine._is_status_type_immune).
static func prevents_status(mon: BattlePokemon, ailment: String) -> bool:
	match ailment:
		"sleep":
			return mon.ability == "vital-spirit" or mon.ability == "insomnia"
		"poison", "toxic":
			return mon.ability == "immunity"
		"paralysis":
			return mon.ability == "limber"
		"burn":
			return mon.ability == "water-veil"
		"freeze":
			return mon.ability == "magma-armor"
	return false


## Chance de guerir un statut en fin de tour (Mue), et Vitesse +1 (Vivacite).
static func end_of_turn(state: BattleState, mon: BattlePokemon) -> void:
	if mon.is_fainted():
		return
	if mon.ability == "shed-skin" and mon.status != "" and randf() < 0.33:
		state.add_log("%s se debarrasse de son statut grace a Mue !" % GameData.fr_species(mon.species_name))
		mon.status = ""
		mon.toxic_counter = 0
	if mon.ability == "speed-boost":
		mon.stat_stages["speed"] = clampi(mon.stat_stages["speed"] + 1, -6, 6)
		state.add_log("%s gagne en Vitesse grace a Vivacite !" % GameData.fr_species(mon.species_name))
	if mon.ability == "rain-dish" and state.weather == "rain" and mon.hp_percent() < 1.0:
		mon.heal(max(1, int(mon.max_hp / 16)))
		state.add_log("%s recupere un peu de PV grace a Sève Cure !" % GameData.fr_species(mon.species_name))


static func speed_multiplier(mon: BattlePokemon, weather: String) -> float:
	if weather != "" and SPEED_WEATHER_ABILITIES.get(mon.ability, "") == weather:
		return 2.0
	return 1.0


## Multiplicateur de degats infliges (cote attaquant).
static func damage_dealt_multiplier(attacker: BattlePokemon, move: Dictionary, is_last_to_move: bool) -> float:
	var mult := 1.0

	if STARTER_BOOST.get(attacker.ability, "") == move["type"] and attacker.hp_percent() <= (1.0 / 3.0):
		mult *= 1.5

	if attacker.ability == "guts" and attacker.status != "" and GameData.is_physical(move):
		mult *= 1.5

	if attacker.ability == "reckless" and float(move.get("drain", 0)) < 0.0:
		mult *= 1.2

	if attacker.ability == "analytic" and is_last_to_move:
		mult *= 1.3

	if attacker.ability == "flash-fire" and attacker.flash_fire_active and move["type"] == "fire":
		mult *= 1.5

	if (attacker.ability == "huge-power" or attacker.ability == "pure-power") and GameData.is_physical(move):
		mult *= 2.0

	if attacker.ability == "hustle" and GameData.is_physical(move):
		mult *= 1.5

	var power: float = move.get("power", 0) if move.get("power") != null else 0.0
	if attacker.ability == "technician" and power > 0.0 and power <= 60.0:
		mult *= 1.5

	return mult


static func crit_damage_multiplier(attacker: BattlePokemon, is_crit: bool) -> float:
	if is_crit and attacker.ability == "sniper":
		return 1.5
	return 1.0


## Reaction du defenseur a un coup entrant. "immune" court-circuite tout calcul de degats.
static func damage_taken_modifier(defender: BattlePokemon, move_type: String, type_eff: float) -> Dictionary:
	match defender.ability:
		"levitate":
			if move_type == "ground":
				return {"immune": true, "heal_instead": false, "multiplier": 1.0}
		"water-absorb":
			if move_type == "water":
				return {"immune": true, "heal_instead": true, "multiplier": 1.0}
		"volt-absorb":
			if move_type == "electric":
				return {"immune": true, "heal_instead": true, "multiplier": 1.0}
		"flash-fire":
			if move_type == "fire":
				return {"immune": true, "heal_instead": false, "multiplier": 1.0}
		"lightning-rod":
			if move_type == "electric":
				return {"immune": true, "heal_instead": false, "multiplier": 1.0}
		"solid-rock", "filter":
			if type_eff > 1.0:
				return {"immune": false, "heal_instead": false, "multiplier": 0.75}
		"thick-fat":
			if move_type == "fire" or move_type == "ice":
				return {"immune": false, "heal_instead": false, "multiplier": 0.5}
		"multiscale":
			if defender.hp_percent() >= 1.0:
				return {"immune": false, "heal_instead": false, "multiplier": 0.5}
	return {"immune": false, "heal_instead": false, "multiplier": 1.0}


static func is_grounded(mon: BattlePokemon) -> bool:
	if mon.ability == "levitate":
		return false
	return not mon.types.has("flying")


static func is_immune_to_weather_chip(mon: BattlePokemon) -> bool:
	return WEATHER_CHIP_IMMUNE_ABILITIES.has(mon.ability)


## Garde Magique (Magic Guard) : bloque TOUS les degats indirects (statut,
## pieges a l'entree, Malediction, contrecoup du Screugneugnu...), pas
## seulement la meteo (bug confirme : Garde Magique ne bloquait que le chip
## de meteo comme Manteau Neige, alors qu'il doit bloquer bien plus).
static func blocks_indirect_damage(mon: BattlePokemon) -> bool:
	return mon.ability == "magic-guard"


static func is_ohko_survivor(mon: BattlePokemon, would_be_damage: int) -> bool:
	return mon.ability == "sturdy" and mon.current_hp == mon.max_hp and would_be_damage >= mon.current_hp


static func blocks_crit(mon: BattlePokemon) -> bool:
	return mon.ability == "shell-armor" or mon.ability == "battle-armor"


static func uses_adaptability_stab(mon: BattlePokemon) -> bool:
	return mon.ability == "adaptability"


static func prevents_flinch(mon: BattlePokemon) -> bool:
	return mon.ability == "inner-focus"


## Chance d'apeurement supplementaire apportee par le talent Odeur Nauseabonde
## (10% sur toute attaque qui n'a normalement aucune chance d'apeurement).
static func stench_flinch_chance(mon: BattlePokemon, base_chance: int) -> int:
	if mon.ability == "stench" and base_chance == 0:
		return 10
	return base_chance


## Persevereance double la chance de declenchement de tout effet secondaire
## (statut, changement de stat, apeurement).
static func secondary_effect_chance_multiplier(mon: BattlePokemon) -> float:
	return 2.0 if mon.ability == "serene-grace" else 1.0


static func blocks_explosion_family(mon: BattlePokemon) -> bool:
	return mon.ability == "damp"


static func prevents_recoil(mon: BattlePokemon) -> bool:
	return mon.ability == "rock-head"


## Talents qui bloquent une baisse de statistique infligee par l'ADVERSAIRE
## (jamais les baisses auto-infligees par ses propres attaques).
static func blocks_stat_drop(mon: BattlePokemon, stat_key: String) -> bool:
	match mon.ability:
		"clear-body", "white-smoke":
			return true
		"keen-eye":
			return stat_key == "accuracy"
		"hyper-cutter":
			return stat_key == "attack"
	return false


## Depuis la 8G, Benet/Sang-Froid/Farceur bloquent aussi specifiquement
## l'Intimidation, en plus des talents qui bloquent toute baisse de stat.
static func blocks_intimidate(mon: BattlePokemon) -> bool:
	if blocks_stat_drop(mon, "attack"):
		return true
	return mon.ability in ["oblivious", "own-tempo", "scrappy"]


static func blocks_taunt(mon: BattlePokemon) -> bool:
	return mon.ability == "oblivious"


## Empeche l'adversaire de manger sa baie tant que ce Pokemon (Odorat, Unnerve)
## est sur le terrain.
static func blocks_opponent_berry(opponent_active: BattlePokemon) -> bool:
	return opponent_active != null and opponent_active.ability == "unnerve"


## Esquive amelioree de 20% sous la meteo correspondante (Regard Vif/Cape Neige).
static func evasion_accuracy_multiplier(defender: BattlePokemon, weather: String) -> float:
	if weather == "sandstorm" and defender.ability == "sand-veil":
		return 0.8
	if weather == "hail" and defender.ability == "snow-cloak":
		return 0.8
	return 1.0
