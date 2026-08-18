class_name BattleMath
extends RefCounted

# Fonctions pures partagées entre battle_engine.gd (1v1) et
# battle_engine_duo.gd (2v2, voir la conversation de conception combat duo
# zone 4) — extraites pour que la formule de dégâts ne diverge pas entre les
# 2 moteurs. Aucun changement de comportement lors de l'extraction : reprend
# _compute_damage()/_weather_multiplier() de battle_engine.gd telles quelles,
# `weather` passé en paramètre au lieu d'être lu sur `self`.

# Formule Gen 3 : ((2*Level/5+2) * Power * Atk/Def / 50 + 2) * STAB * Efficacité
# * Météo * Critique(x2, 1/16) * Aléa(0.85-1.0). Retourne aussi type_eff/crit
# (pas seulement les dégâts) : les appelants s'en servent pour les messages
# "Coup critique !"/"C'est super efficace !".
static func compute_damage(attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary, weather: String) -> Dictionary:
	var power: int = int(move["power"])
	var category: String = String(move["category"])
	var atk_stat: int = attacker.sp_attack if category == "SPECIAL" else attacker.attack
	var def_stat: int = defender.sp_defense if category == "SPECIAL" else defender.defense
	# Brûlure : dégâts physiques infligés divisés par 2 (pas les spéciaux).
	if attacker.burned and category == "PHYSICAL":
		atk_stat = atk_stat / 2

	var base: float = ((2.0 * attacker.level / 5.0 + 2.0) * float(power) * float(atk_stat) / float(def_stat)) / 50.0 + 2.0
	var stab: float = 1.5 if String(move["type"]) in attacker.types else 1.0
	var type_eff: float = TypeChart.effectiveness(String(move["type"]), defender.types)
	var weather_mult: float = weather_multiplier(String(move["type"]), weather)
	var is_crit: bool = randf() < (1.0 / 16.0)
	var crit: float = 2.0 if is_crit else 1.0
	var rand_factor: float = randf_range(0.85, 1.0)

	var dmg := maxi(1, int(base * stab * type_eff * weather_mult * crit * rand_factor))
	return {"damage": dmg, "type_eff": type_eff, "crit": is_crit}

static func weather_multiplier(move_type: String, weather: String) -> float:
	if weather == "RAIN":
		if move_type == "WATER":
			return 1.5
		if move_type == "FIRE":
			return 0.5
	return 1.0
