class_name BattleEngineDuo
extends RefCounted

# Moteur de combat duo (2v2, 4 dresseurs distincts — voir la conversation de
# conception, zone 4 Parc Safari) : le joueur et un allié (IA) affrontent 2
# dresseurs adverses, chacun avec sa propre équipe/son propre BattleSide.
# Même esprit que battle_engine.gd (resolve_turn() pur, retourne une liste
# ORDONNÉE d'évènements consommée par l'écran) mais généralisé à 4 côtés
# plutôt que 2, avec ciblage manuel (chaque attaque vise un côté précis, pas
# implicitement "l'unique adversaire" comme en 1v1).
#
# sides[] : taille 4, index fixe pour tout le combat :
#   0 = joueur, 1 = allié (IA), 2 = ennemi 1 (IA), 3 = ennemi 2 (IA)
# sides[i].team : 0 pour 0/1 (camp allié), 1 pour 2/3 (camp adverse).
#
# Types d'évènements retournés (dict avec "type") — même schéma que
# battle_engine.gd sauf "is_player": bool remplacé par "side"/"target_side":
# int (index dans sides[]), puisqu'il y a 4 côtés et pas 2 :
# - {"type": "switch", "side": int, "pokemon": String}
# - {"type": "move_used", "side": int, "pokemon": String, "move": String, "move_key": String, "target_side": int}
# - {"type": "message", "text": String}
# - {"type": "hp_changed", "side": int, "amount": int, "current_hp": int, "max_hp": int, "residual": bool}
# - {"type": "status", "status": "burned", "side": int, "pokemon": String}
# - {"type": "pokemon_fainted", "side": int, "pokemon": String}
# - {"type": "weather_changed", "weather": String}
# - {"type": "battle_ended", "result": "win"/"lose"}

var sides: Array[BattleSide] = []
var weather := "NONE"   # "NONE" / "RAIN"
var weather_turns_remaining := 0

func _init(p_sides: Array[BattleSide]) -> void:
	sides = p_sides

func opposing_indices(side_index: int) -> Array[int]:
	var t: int = sides[side_index].team
	var out: Array[int] = []
	for j in range(sides.size()):
		if sides[j].team != t:
			out.append(j)
	return out

func allied_indices(side_index: int) -> Array[int]:
	var t: int = sides[side_index].team
	var out: Array[int] = []
	for j in range(sides.size()):
		if j != side_index and sides[j].team == t:
			out.append(j)
	return out

func _team_alive(team_id: int) -> bool:
	for s in sides:
		if s.team == team_id and s.has_alive():
			return true
	return false

# actions[i] correspond à sides[i] :
#   {"kind": "attack", "move_key": String, "target": int}  (target = index dans sides[])
#   {"kind": "switch", "index": int}
func resolve_turn(actions: Array[Dictionary]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	# Switches résolus en premier, gratuits, dans l'ordre des indices.
	for i in range(sides.size()):
		if String(actions[i]["kind"]) == "switch":
			_do_switch(i, int(actions[i]["index"]), events)

	# Attaques triées par priority du move, puis par vitesse du Pokémon actif
	# (égalité -> tirage aléatoire) — même critère que battle_engine.gd.
	var attackers: Array = []
	for i in range(sides.size()):
		if String(actions[i]["kind"]) == "attack":
			attackers.append({"index": i, "action": actions[i]})
	attackers.sort_custom(_compare_attackers)

	for a in attackers:
		var i: int = int(a["index"])
		var attacker_side: BattleSide = sides[i]
		var attacker: BattlePokemon = attacker_side.active()
		if attacker.is_fainted():
			continue

		var move_key: String = String(a["action"]["move_key"])
		var target_idx: int = int(a["action"]["target"])
		if sides[target_idx].active().is_fainted():
			# La cible visée est morte plus tôt ce tour (contrairement au 1v1,
			# il n'y a pas qu'une seule case adverse possible) : redirige vers
			# le premier adversaire encore vivant plutôt que de gâcher le tour.
			target_idx = -1
			for candidate in opposing_indices(i):
				if not sides[candidate].active().is_fainted():
					target_idx = candidate
					break
			if target_idx == -1:
				continue   # plus aucun adversaire vivant, rien à viser

		_resolve_attack(i, target_idx, move_key, events)

		# Dégâts résiduels de brûlure, à la fin du tour de ce Pokémon précis
		# (même règle que battle_engine.gd).
		if attacker.burned and not attacker.is_fainted():
			var residual: int = maxi(1, attacker.max_hp / 16)
			attacker.take_damage(residual)
			events.append({
				"type": "hp_changed", "side": i, "amount": residual,
				"current_hp": attacker.current_hp, "max_hp": attacker.max_hp, "residual": true,
			})
			if attacker.is_fainted():
				events.append({"type": "pokemon_fainted", "side": i, "pokemon": attacker.display_name})

		if not _team_alive(0) or not _team_alive(1):
			break

	_tick_weather(events)

	if not _team_alive(0):
		events.append({"type": "battle_ended", "result": "lose"})
	elif not _team_alive(1):
		events.append({"type": "battle_ended", "result": "win"})

	return events

func _compare_attackers(x: Dictionary, y: Dictionary) -> bool:
	var px: int = int(MoveData.MOVES[String(x["action"]["move_key"])]["priority"])
	var py: int = int(MoveData.MOVES[String(y["action"]["move_key"])]["priority"])
	if px != py:
		return px > py
	var sx: int = sides[int(x["index"])].active().speed
	var sy: int = sides[int(y["index"])].active().speed
	if sx != sy:
		return sx > sy
	return randf() < 0.5

func _do_switch(side_index: int, index: int, events: Array[Dictionary]) -> void:
	sides[side_index].active_index = index
	events.append({"type": "switch", "side": side_index, "pokemon": sides[side_index].active().display_name})

func _resolve_attack(side_index: int, target_index: int, move_key: String, events: Array[Dictionary]) -> void:
	var attacker_side: BattleSide = sides[side_index]
	var target_side: BattleSide = sides[target_index]
	var attacker: BattlePokemon = attacker_side.active()
	var defender: BattlePokemon = target_side.active()
	if defender.is_fainted():
		return
	var move: Dictionary = MoveData.MOVES[move_key]
	for mv in attacker.moves:
		if String(mv["key"]) == move_key:
			mv["pp_current"] = maxi(0, int(mv["pp_current"]) - 1)
			break
	events.append({
		"type": "move_used", "side": side_index,
		"pokemon": attacker.display_name, "move": String(move["name"]),
		"move_key": move_key, "target_side": target_index,
	})

	if String(move["effect"]) == "EFFECT_RAIN_DANCE":
		weather = "RAIN"
		weather_turns_remaining = 5
		events.append({"type": "weather_changed", "weather": weather})
		return

	if randf() * 100.0 >= float(move["accuracy"]):
		events.append({"type": "message", "text": "%s évite l'attaque." % defender.display_name})
		return

	var result: Dictionary = BattleMath.compute_damage(attacker, defender, move, weather)
	var dmg: int = int(result["damage"])
	defender.take_damage(dmg)
	# Les PV descendent d'abord, les messages d'efficacité/critique ensuite
	# (même ordre que battle_engine.gd, voir Gus).
	events.append({
		"type": "hp_changed", "side": target_index, "amount": dmg,
		"current_hp": defender.current_hp, "max_hp": defender.max_hp, "residual": false,
	})
	if bool(result["crit"]):
		events.append({"type": "message", "text": "Coup critique !"})
	var type_eff: float = float(result["type_eff"])
	if type_eff > 1.0:
		events.append({"type": "message", "text": "C'est super efficace !"})
	elif type_eff < 1.0 and type_eff > 0.0:
		events.append({"type": "message", "text": "Ce n'est pas très efficace..."})

	if String(move["effect"]) == "EFFECT_BURN_HIT" and not defender.burned:
		if randf() * 100.0 < float(move["secondary_effect_chance"]) and not ("FIRE" in defender.types):
			defender.burned = true
			events.append({"type": "status", "status": "burned", "side": target_index, "pokemon": defender.display_name})

	if defender.is_fainted():
		events.append({"type": "pokemon_fainted", "side": target_index, "pokemon": defender.display_name})

func _tick_weather(events: Array[Dictionary]) -> void:
	if weather_turns_remaining <= 0:
		return
	weather_turns_remaining -= 1
	if weather_turns_remaining == 0:
		weather = "NONE"
		events.append({"type": "weather_changed", "weather": weather})

# IA à un seul style (même heuristique que battle_engine.gd::choose_ai_action,
# dégât moyen attendu sans aléa/crit), généralisée pour choisir aussi la
# meilleure cible parmi les adversaires vivants plutôt qu'une cible fixe.
# Utilisée pour l'allié (index 1) ET les 2 ennemis (index 2, 3).
func choose_ai_action(side_index: int) -> Dictionary:
	var attacker: BattlePokemon = sides[side_index].active()
	var best_key := ""
	var best_target := -1
	var best_expected := -1.0
	for target_idx in opposing_indices(side_index):
		var defender: BattlePokemon = sides[target_idx].active()
		if defender.is_fainted():
			continue
		for mv in attacker.moves:
			var key: String = String(mv["key"])
			var move: Dictionary = MoveData.MOVES[key]
			if String(move["effect"]) == "EFFECT_RAIN_DANCE":
				continue   # même garde-fou générique que battle_engine.gd
			var category: String = String(move["category"])
			var atk_stat: int = attacker.sp_attack if category == "SPECIAL" else attacker.attack
			var def_stat: int = defender.sp_defense if category == "SPECIAL" else defender.defense
			var base: float = ((2.0 * attacker.level / 5.0 + 2.0) * float(move["power"]) * float(atk_stat) / float(def_stat)) / 50.0 + 2.0
			var stab: float = 1.5 if String(move["type"]) in attacker.types else 1.0
			var type_eff: float = TypeChart.effectiveness(String(move["type"]), defender.types)
			var weather_mult: float = BattleMath.weather_multiplier(String(move["type"]), weather)
			var expected: float = base * stab * type_eff * weather_mult
			if expected > best_expected:
				best_expected = expected
				best_key = key
				best_target = target_idx
	return {"kind": "attack", "move_key": best_key, "target": best_target}

# Switch automatique côté IA (allié ou ennemi) après K.O. de son Pokémon
# actif (prochain vivant, ordre de la liste) — le switch du joueur (index 0)
# au K.O. passe par un vrai menu, piloté par duo_battle.gd, pas cette fonction
# (même partage des responsabilités que battle_engine.gd/trainer_battle.gd).
func auto_switch_if_fainted(side_index: int) -> void:
	if sides[side_index].active().is_fainted():
		var idx := sides[side_index].next_alive_index()
		if idx >= 0:
			sides[side_index].active_index = idx
