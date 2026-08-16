class_name BattleEngine
extends RefCounted

# Boucle de combat pure (pas un Node visuel) : `resolve_turn()` prend
# l'action du joueur et de l'IA, résout tout ce qui doit se passer ce tour
# (switch, attaques dans l'ordre priority/vitesse, dégâts, brûlure, météo,
# K.O., fin de combat) et retourne une liste ORDONNÉE d'évènements que
# l'écran (trainer_battle.gd) consomme un par un pour l'affichage/le rythme
# (au lieu de vrais signaux Godot : plus simple à consommer dans une boucle
# async `for event in engine.resolve_turn(...): await ui.handle_event(event)`,
# et plus facile à retester en dehors de l'UI — voir la simulation
# d'équilibrage qui réutilise ce même moteur).
#
# Types d'évènements retournés (dict avec "type") :
# - {"type": "switch", "is_player": bool, "pokemon": String}
# - {"type": "move_used", "is_player": bool, "pokemon": String, "move": String}
# - {"type": "message", "text": String}  (esquive, etc.)
# - {"type": "hp_changed", "is_player": bool, "amount": int, "current_hp": int, "max_hp": int, "residual": bool}
# - {"type": "status", "status": "burned", "is_player": bool, "pokemon": String}
# - {"type": "pokemon_fainted", "is_player": bool, "pokemon": String}
# - {"type": "weather_changed", "weather": String}
# - {"type": "battle_ended", "result": "win"/"lose"}
#
# Seuls 2 effets de capacité au-delà du pur dégât sont gérés (voir la
# conversation de conception) : Danse Pluie (météo) et la brûlure de
# Flammèche — tout le reste est volontairement hors scope.

var player_side: BattleSide
var enemy_side: BattleSide
var weather := "NONE"   # "NONE" / "RAIN"
var weather_turns_remaining := 0

func _init(p_player_side: BattleSide, p_enemy_side: BattleSide) -> void:
	player_side = p_player_side
	enemy_side = p_enemy_side

# player_action / enemy_action : {"kind": "attack", "move_key": String}
#                              ou {"kind": "switch", "index": int}
func resolve_turn(player_action: Dictionary, enemy_action: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var actors := [
		{"side": player_side, "other": enemy_side, "action": player_action},
		{"side": enemy_side, "other": player_side, "action": enemy_action},
	]

	# Switches résolus en premier, gratuits.
	for a in actors:
		if String(a["action"]["kind"]) == "switch":
			_do_switch(a["side"], int(a["action"]["index"]), events)

	# Attaques triées par priority du move, puis par vitesse du Pokémon actif
	# (égalité -> tirage aléatoire).
	var attackers: Array = []
	for a in actors:
		if String(a["action"]["kind"]) == "attack":
			attackers.append(a)
	attackers.sort_custom(_compare_attackers)

	for a in attackers:
		var side: BattleSide = a["side"]
		var other: BattleSide = a["other"]
		var attacker: BattlePokemon = side.active()
		if attacker.is_fainted():
			continue
		_resolve_attack(side, other, String(a["action"]["move_key"]), events)

		# Dégâts résiduels de brûlure, à la fin du tour de ce Pokémon précis.
		if attacker.burned and not attacker.is_fainted():
			var residual: int = maxi(1, attacker.max_hp / 16)
			attacker.take_damage(residual)
			events.append({
				"type": "hp_changed", "is_player": side.is_player, "amount": residual,
				"current_hp": attacker.current_hp, "max_hp": attacker.max_hp, "residual": true,
			})
			if attacker.is_fainted():
				events.append({"type": "pokemon_fainted", "is_player": side.is_player, "pokemon": attacker.display_name})

		if not other.has_alive() or not side.has_alive():
			break

	_tick_weather(events)

	if not player_side.has_alive():
		events.append({"type": "battle_ended", "result": "lose"})
	elif not enemy_side.has_alive():
		events.append({"type": "battle_ended", "result": "win"})

	return events

func _compare_attackers(x: Dictionary, y: Dictionary) -> bool:
	var px: int = int(MoveData.MOVES[String(x["action"]["move_key"])]["priority"])
	var py: int = int(MoveData.MOVES[String(y["action"]["move_key"])]["priority"])
	if px != py:
		return px > py
	var sx: int = (x["side"] as BattleSide).active().speed
	var sy: int = (y["side"] as BattleSide).active().speed
	if sx != sy:
		return sx > sy
	return randf() < 0.5

func _do_switch(side: BattleSide, index: int, events: Array[Dictionary]) -> void:
	side.active_index = index
	events.append({"type": "switch", "is_player": side.is_player, "pokemon": side.active().display_name})

func _resolve_attack(side: BattleSide, other: BattleSide, move_key: String, events: Array[Dictionary]) -> void:
	var attacker: BattlePokemon = side.active()
	var defender: BattlePokemon = other.active()
	if defender.is_fainted():
		return
	var move: Dictionary = MoveData.MOVES[move_key]
	for mv in attacker.moves:
		if String(mv["key"]) == move_key:
			mv["pp_current"] = maxi(0, int(mv["pp_current"]) - 1)
			break
	events.append({
		"type": "move_used", "is_player": side.is_player,
		"pokemon": attacker.display_name, "move": String(move["name"]),
	})

	if String(move["effect"]) == "EFFECT_RAIN_DANCE":
		weather = "RAIN"
		weather_turns_remaining = 5
		events.append({"type": "weather_changed", "weather": weather})
		return

	if randf() * 100.0 >= float(move["accuracy"]):
		events.append({"type": "message", "text": "%s évite l'attaque." % defender.display_name})
		return

	var dmg := _compute_damage(attacker, defender, move)
	defender.take_damage(dmg)
	events.append({
		"type": "hp_changed", "is_player": other.is_player, "amount": dmg,
		"current_hp": defender.current_hp, "max_hp": defender.max_hp, "residual": false,
	})

	if String(move["effect"]) == "EFFECT_BURN_HIT" and not defender.burned:
		if randf() * 100.0 < float(move["secondary_effect_chance"]) and not ("FIRE" in defender.types):
			defender.burned = true
			events.append({"type": "status", "status": "burned", "is_player": other.is_player, "pokemon": defender.display_name})

	if defender.is_fainted():
		events.append({"type": "pokemon_fainted", "is_player": other.is_player, "pokemon": defender.display_name})

# Formule Gen 3 : ((2*Level/5+2) * Power * Atk/Def / 50 + 2) * STAB * Efficacité
# * Météo * Critique(x2, 1/16) * Aléa(0.85-1.0).
func _compute_damage(attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary) -> int:
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
	var weather_mult: float = _weather_multiplier(String(move["type"]))
	var crit: float = 2.0 if randf() < (1.0 / 16.0) else 1.0
	var rand_factor: float = randf_range(0.85, 1.0)

	return maxi(1, int(base * stab * type_eff * weather_mult * crit * rand_factor))

func _weather_multiplier(move_type: String) -> float:
	if weather == "RAIN":
		if move_type == "WATER":
			return 1.5
		if move_type == "FIRE":
			return 0.5
	return 1.0

func _tick_weather(events: Array[Dictionary]) -> void:
	if weather_turns_remaining <= 0:
		return
	weather_turns_remaining -= 1
	if weather_turns_remaining == 0:
		weather = "NONE"
		events.append({"type": "weather_changed", "weather": weather})

# IA à un seul style pour ce lot : maximise le dégât moyen attendu (STAB,
# efficacité de type, météo courante), sans l'aléa 0.85-1.0 ni la chance de
# critique — juste assez pour un adversaire crédible, pas la vraie IA du jeu.
func choose_ai_action() -> Dictionary:
	var attacker: BattlePokemon = enemy_side.active()
	var defender: BattlePokemon = player_side.active()
	var best_key := ""
	var best_expected := -1.0
	for mv in attacker.moves:
		var key: String = String(mv["key"])
		var move: Dictionary = MoveData.MOVES[key]
		if String(move["effect"]) == "EFFECT_RAIN_DANCE":
			continue   # aucun Pokémon de Yohan n'en a dans ce combat, garde-fou générique
		var category: String = String(move["category"])
		var atk_stat: int = attacker.sp_attack if category == "SPECIAL" else attacker.attack
		var def_stat: int = defender.sp_defense if category == "SPECIAL" else defender.defense
		var base: float = ((2.0 * attacker.level / 5.0 + 2.0) * float(move["power"]) * float(atk_stat) / float(def_stat)) / 50.0 + 2.0
		var stab: float = 1.5 if String(move["type"]) in attacker.types else 1.0
		var type_eff: float = TypeChart.effectiveness(String(move["type"]), defender.types)
		var weather_mult: float = _weather_multiplier(String(move["type"]))
		var expected: float = base * stab * type_eff * weather_mult
		if expected > best_expected:
			best_expected = expected
			best_key = key
	return {"kind": "attack", "move_key": best_key}

# Switch automatique côté IA après K.O. de son Pokémon actif (prochain
# vivant, ordre de la liste) — côté joueur, le switch au K.O. passe par un
# vrai menu, piloté par trainer_battle.gd, pas cette fonction.
func auto_switch_enemy_if_fainted() -> void:
	if enemy_side.active().is_fainted():
		var idx := enemy_side.next_alive_index()
		if idx >= 0:
			enemy_side.active_index = idx
