class_name BattleEngine
extends RefCounted
## Moteur de resolution de tour, pur (pas de dependance a l'UI).
## resolve_turn() est deterministe a part les jets aleatoires (degats, crit, precision).
## Les messages de log utilisent les noms francais (especes/attaques/statuts/meteo)
## via GameData.fr_* ; les slugs anglais restent la cle interne partout ailleurs.

## Regles recentes (Gen6+) : stage 0/1/2/3+ -> 1/24, 1/8, 1/2, toujours.
const CRIT_STAGE_CHANCES := [1.0 / 24.0, 1.0 / 8.0, 1.0 / 2.0, 1.0]
const CRIT_MULTIPLIER := 1.5
const STAB_MULTIPLIER := 1.5

const HAZARD_MAX_LAYERS := {"stealth-rock": 1, "spikes": 3, "toxic-spikes": 2, "sticky-web": 1}
const SPIKES_DAMAGE_FRACTION := [0.0, 1.0 / 8.0, 1.0 / 6.0, 1.0 / 4.0]

## Le lanceur se blesse (1/2 PV max) s'il rate son coup (jamais code jusqu'ici).
const CRASH_ON_MISS_MOVES := ["high-jump-kick", "jump-kick"]

## Pieges partiels (Ligotage/Étreinte/Sinistrosion/Entrave/Siphon...) : la
## cible ne peut plus switcher et subit 1/8 PV max en fin de tour pendant
## 4-5 tours, tant que le poseur reste sur le terrain (jamais code jusqu'ici :
## ces moves ne faisaient qu'un degat ponctuel, sans aucun effet de piege).
const PARTIAL_TRAP_MOVES := ["wrap", "bind", "fire-spin", "clamp", "whirlpool", "sand-tomb", "infestation", "magma-storm"]


## Cote de terrain ("a"/"b") d'un Pokemon, pour les metadonnees d'animation
## attachees aux logs (l'UI n'a pas d'autre moyen fiable de savoir qui, du
## joueur ou du CPU, doit jouer l'effet).
static func _side_of(state: BattleState, mon: BattlePokemon) -> String:
	return "a" if state.team_a.active() == mon else "b"


## A appeler une seule fois juste apres avoir construit les deux equipes,
## pour declencher les effets d'entree (Intimidation, meteo posee par talent...)
## des tout premiers Pokemon envoyes.
static func start_battle(state: BattleState) -> void:
	state.add_log("%s envoie %s !" % [state.team_a.trainer_name, GameData.fr_species(state.team_a.active().species_name)])
	state.add_log("%s envoie %s !" % [state.team_b.trainer_name, GameData.fr_species(state.team_b.active().species_name)])
	_trigger_switch_in_by_speed(state)
	state.check_end()


## Declenche les effets d'entree des deux actifs dans l'ordre de vitesse : le
## plus lent en dernier, donc "gagnant" en cas de conflit (ex: meteo posee par
## deux talents differents la meme entree -- le plus lent l'emporte, comme
## Politoed plus lent que Feunard qui remplace son Soleil par de la Pluie).
static func _trigger_switch_in_by_speed(state: BattleState) -> void:
	var mon_a := state.team_a.active()
	var mon_b := state.team_b.active()
	if get_speed(mon_a, state.weather) >= get_speed(mon_b, state.weather):
		AbilityEngine.on_switch_in(state, state.team_a, mon_a)
		AbilityEngine.on_switch_in(state, state.team_b, mon_b)
	else:
		AbilityEngine.on_switch_in(state, state.team_b, mon_b)
		AbilityEngine.on_switch_in(state, state.team_a, mon_a)


static func resolve_turn(state: BattleState, action_a: BattleAction, action_b: BattleAction) -> void:
	state.turn_number += 1

	# Abri/Detection ne protege que pour CE tour.
	state.team_a.active().is_protected = false
	state.team_b.active().is_protected = false

	# L'apeurement (flinch) ne bloque que l'action de CE tour.
	state.team_a.active().is_flinched = false
	state.team_b.active().is_flinched = false

	# Poursuite intercepte un switch adverse : frappe (puissance doublee) le
	# Pokemon AVANT qu'il ne quitte le terrain, sinon l'attaque manquerait
	# completement sa cible deja partie une fois le switch resolu.
	var pursuit_used_a := _apply_pursuit_interception(state, state.team_a, action_a, state.team_b, action_b)
	if state.is_over:
		return
	var pursuit_used_b := _apply_pursuit_interception(state, state.team_b, action_b, state.team_a, action_a)
	if state.is_over:
		return

	# 1) Les switchs sont resolus avant toute attaque, dans l'ordre de vitesse
	# des sortants si les deux camps switchent le meme tour (meme regle que
	# start_battle : le plus lent entre en dernier).
	if action_a.kind == BattleAction.Kind.SWITCH and action_b.kind == BattleAction.Kind.SWITCH \
			and get_speed(state.team_a.active(), state.weather) < get_speed(state.team_b.active(), state.weather):
		_apply_if_switch(state, state.team_b, action_b)
		_apply_if_switch(state, state.team_a, action_a)
	else:
		_apply_if_switch(state, state.team_a, action_a)
		_apply_if_switch(state, state.team_b, action_b)

	# 2) Ordre des attaques : priorite du move, puis vitesse, puis alea.
	var order := _order_actions(state, action_a, action_b)

	for i in range(order.size()):
		var entry: Dictionary = order[i]
		var attacker_team: BattleTeam = entry["team"]
		var action: BattleAction = entry["action"]

		if action.kind != BattleAction.Kind.MOVE:
			continue
		if (attacker_team == state.team_a and pursuit_used_a) or (attacker_team == state.team_b and pursuit_used_b):
			continue  # deja executee en interception de switch plus haut
		var attacker := attacker_team.active()
		if attacker.is_fainted():
			continue

		var defender_team := state.other_team(attacker_team)
		_execute_move(state, attacker_team, attacker, defender_team, action.move_name, i == order.size() - 1)
		state.check_end()
		if state.is_over:
			return

	# 3) Fin de tour : meteo puis degats de statut.
	_apply_weather_end_of_turn(state)
	_apply_end_of_turn_status(state, state.team_a)
	_apply_end_of_turn_status(state, state.team_b)
	AbilityEngine.end_of_turn(state, state.team_a.active())
	AbilityEngine.end_of_turn(state, state.team_b.active())
	ItemEngine.end_of_turn(state, state.team_a.active())
	ItemEngine.end_of_turn(state, state.team_b.active())
	_decrement_taunt(state.team_a.active())
	_decrement_taunt(state.team_b.active())
	state.check_end()


static func _decrement_taunt(mon: BattlePokemon) -> void:
	if mon.taunt_turns_left > 0:
		mon.taunt_turns_left -= 1


## Poursuite : si l'attaquant choisit Poursuite et que l'adversaire choisit de
## switcher CE tour, Poursuite frappe (puissance doublee) le Pokemon avant
## qu'il ne quitte le terrain, au lieu de le manquer completement une fois le
## switch resolu. Renvoie true si l'interception a eu lieu (le tour normal de
## l'attaquant est alors deja consomme, a ne pas rejouer dans la boucle principale).
static func _apply_pursuit_interception(state: BattleState, attacker_team: BattleTeam, attacker_action: BattleAction, defender_team: BattleTeam, defender_action: BattleAction) -> bool:
	if attacker_action.kind != BattleAction.Kind.MOVE or attacker_action.move_name != "pursuit":
		return false
	if defender_action.kind != BattleAction.Kind.SWITCH:
		return false

	var attacker := attacker_team.active()
	if attacker.is_fainted() or not _can_act(state, attacker_team, attacker):
		return false
	var defender := defender_team.active()
	if defender.is_fainted():
		return false

	attacker_team.reveal_move(attacker.species_name, "pursuit")
	attacker.pp_left["pursuit"] = max(0, attacker.pp_left.get("pursuit", 0) - 1)
	state.add_log("%s utilise Poursuite !" % GameData.fr_species(attacker.species_name))

	var move: Dictionary = GameData.get_move("pursuit")
	if not _accuracy_check(attacker, defender, move, state.weather):
		state.add_log("%s echoue !" % GameData.fr_species(attacker.species_name))
		return true

	var boosted_move := move.duplicate(true)
	boosted_move["power"] = int(move["power"]) * 2
	_deal_damage(state, attacker, defender, boosted_move, state.weather, false)
	if defender.is_fainted():
		AbilityEngine.on_ko_scored(state, attacker)
	state.check_end()
	return true


static func _apply_if_switch(state: BattleState, team: BattleTeam, action: BattleAction) -> void:
	if action.kind != BattleAction.Kind.SWITCH:
		return
	var old_mon := team.active()
	if old_mon.partial_trap_turns_left > 0:
		state.add_log("%s est piege(e) et ne peut pas s'echapper !" % GameData.fr_species(old_mon.species_name))
		return
	var old_name := old_mon.species_name
	old_mon.reset_on_switch_out()
	AbilityEngine.on_switch_out(old_mon)
	team.switch_active(action.switch_index)
	state.add_log("%s rappelle %s et envoie %s !" % [team.trainer_name, GameData.fr_species(old_name), GameData.fr_species(team.active().species_name)])
	_on_enter_field(state, team, team.active())


## Verifie si le camp doit choisir un remplacant force (KO en cours de tour).
## Vrai apres un KO, mais aussi apres un move "pivot" (Change Eclair/Demi-Tour)
## qui a touche sans mettre KO le lanceur -- il doit alors choisir un
## remplacant lui aussi, sans que l'adversaire ne rejoue gratuitement.
static func needs_switch(team: BattleTeam) -> bool:
	if team.pivot_pending:
		return true
	return team.active().is_fainted() and not team.is_defeated()


## Remplacement force (KO ou pivot) : hors structure normale du tour (pas d'attaque adverse "gratuite").
static func apply_forced_switch(state: BattleState, team: BattleTeam, index: int) -> void:
	team.pivot_pending = false
	var old_mon := team.active()
	old_mon.reset_on_switch_out()
	AbilityEngine.on_switch_out(old_mon)
	team.switch_active(index)
	state.add_log("%s envoie %s !" % [team.trainer_name, GameData.fr_species(team.active().species_name)])
	_on_enter_field(state, team, team.active())
	state.check_end()


## Regroupe tout ce qui se declenche a l'entree sur le terrain : hazards puis talents.
static func _on_enter_field(state: BattleState, team: BattleTeam, mon: BattlePokemon) -> void:
	_apply_hazard_damage_on_entry(state, team, mon)
	if not mon.is_fainted():
		AbilityEngine.on_switch_in(state, team, mon)


static func _apply_hazard_damage_on_entry(state: BattleState, team: BattleTeam, mon: BattlePokemon) -> void:
	if mon.is_fainted():
		return
	if ItemEngine.blocks_hazards(mon) or AbilityEngine.blocks_indirect_damage(mon):
		return

	var sr_layers: int = team.hazards.get("stealth-rock", 0)
	if sr_layers > 0:
		var eff := GameData.type_effectiveness("rock", mon.types)
		var dmg: int = max(1, int(mon.max_hp * 0.125 * eff))
		var lost := mon.apply_damage(dmg)
		state.add_log("%s inflige %d degats a %s !" % [GameData.fr_move("stealth-rock"), lost, GameData.fr_species(mon.species_name)])
		if mon.is_fainted():
			return

	if not AbilityEngine.is_grounded(mon):
		return  # Spikes/Toxic Spikes n'affectent pas les Pokemon "en vol" (Vol ou Levitation)

	var spikes_layers: int = team.hazards.get("spikes", 0)
	if spikes_layers > 0:
		var dmg: int = max(1, int(mon.max_hp * SPIKES_DAMAGE_FRACTION[spikes_layers]))
		var lost := mon.apply_damage(dmg)
		state.add_log("Les pics infligent %d degats a %s !" % [lost, GameData.fr_species(mon.species_name)])
		if mon.is_fainted():
			return

	var tspikes_layers: int = team.hazards.get("toxic-spikes", 0)
	if tspikes_layers > 0 and mon.status == "":
		if mon.types.has("poison"):
			team.hazards["toxic-spikes"] = 0
			state.add_log("%s absorbe les pics toxiques !" % GameData.fr_species(mon.species_name))
		else:
			var ailment := "toxic" if tspikes_layers >= 2 else "poison"
			_inflict_status(state, mon, ailment)

	if team.hazards.get("sticky-web", 0) > 0 and not mon.is_fainted():
		mon.stat_stages["speed"] = clampi(mon.stat_stages["speed"] - 1, -6, 6)
		state.add_log("%s est ralenti par la Toile Gluante !" % GameData.fr_species(mon.species_name))


static func _order_actions(state: BattleState, action_a: BattleAction, action_b: BattleAction) -> Array:
	var prio_a := _action_priority(action_a)
	var prio_b := _action_priority(action_b)

	var first_a: bool
	if prio_a != prio_b:
		first_a = prio_a > prio_b
	else:
		var speed_a := get_speed(state.team_a.active(), state.weather)
		var speed_b := get_speed(state.team_b.active(), state.weather)
		if speed_a == speed_b:
			first_a = randf() < 0.5
		else:
			first_a = speed_a > speed_b

	var first := {"team": state.team_a, "action": action_a}
	var second := {"team": state.team_b, "action": action_b}
	if not first_a:
		var tmp := first
		first = second
		second = tmp
	return [first, second]


## Vitesse effective incluant les abus de meteo (Chlorophylle, Nage Rapide...).
static func get_speed(mon: BattlePokemon, weather: String) -> int:
	var base_speed := mon.effective_stat("speed")
	return int(floor(base_speed * AbilityEngine.speed_multiplier(mon, weather) * ItemEngine.speed_multiplier(mon)))


static func _action_priority(action: BattleAction) -> int:
	if action.kind != BattleAction.Kind.MOVE:
		return 6  # les switchs n'entrent pas dans ce classement (deja resolus), valeur haute par securite
	var move := GameData.get_move(action.move_name)
	return move.get("priority", 0)


static func _execute_move(state: BattleState, attacker_team: BattleTeam, attacker: BattlePokemon, defender_team: BattleTeam, move_name: String, is_last_to_move: bool) -> void:
	# Lance-Soleil/Lame Solaire : le tour de charge est deja passe, on force la
	# liberation du VRAI move charge quel que soit ce qui a ete choisi entre
	# temps (bug absent jusqu'ici : ces moves frappaient toujours instantanement).
	var is_releasing_charge := false
	if attacker.charging_move != "":
		move_name = attacker.charging_move
		attacker.charging_move = ""
		is_releasing_charge = true

	var move := GameData.get_move(move_name)
	if move.is_empty():
		push_error("BattleEngine: move inconnu '%s'" % move_name)
		return

	attacker_team.reveal_move(attacker.species_name, move_name)
	if not is_releasing_charge:
		attacker.pp_left[move_name] = max(0, attacker.pp_left.get(move_name, 0) - 1)

	if not _can_act(state, attacker_team, attacker):
		return

	state.add_log("%s utilise %s !" % [GameData.fr_species(attacker.species_name), GameData.fr_move(move_name)])

	if attacker.taunt_turns_left > 0 and move.get("damage_class", "") == "status":
		state.add_log("%s est provoque(e) et ne peut pas utiliser d'attaque de statut !" % GameData.fr_species(attacker.species_name))
		return

	# Premiere moitie d'un move a charge (Lance-Soleil...) : pas d'effet ce
	# tour-ci sauf si la meteo permet un tir instantane.
	if not is_releasing_charge and RoleTagger.CHARGE_MOVES.has(move_name) and state.weather != RoleTagger.CHARGE_MOVES[move_name]:
		attacker.charging_move = move_name
		state.add_log("%s %s !" % [GameData.fr_species(attacker.species_name), RoleTagger.CHARGE_MOVE_MESSAGES.get(move_name, "se prepare")])
		return

	if RoleTagger.RECHARGE_MOVES.has(move_name):
		attacker.must_recharge = true

	# Le taux de succes d'Abri/Detection diminue en cas d'usage consecutif ;
	# tout autre move remet le compteur a zero (regle des jeux principaux).
	if RoleTagger.PROTECT_MOVES.has(move_name):
		_attempt_protect(state, attacker)
		return
	attacker.protect_streak = 0

	var defender := defender_team.active()

	if not _accuracy_check(attacker, defender, move, state.weather):
		state.add_log("%s echoue !" % GameData.fr_species(attacker.species_name))
		if CRASH_ON_MISS_MOVES.has(move_name) and not attacker.is_fainted():
			var crash_dmg: int = max(1, int(attacker.max_hp / 2))
			var crash_lost := attacker.apply_damage(crash_dmg)
			state.add_log("%s se blesse en ratant son attaque ! (-%d PV)" % [GameData.fr_species(attacker.species_name), crash_lost])
		return

	if HAZARD_MAX_LAYERS.has(move_name):
		_set_hazard(state, defender_team, move_name)
		return

	if RoleTagger.WEATHER_MOVES.has(move_name):
		_set_weather_from_move(state, RoleTagger.WEATHER_MOVES[move_name], attacker)
		return

	var targets_opponent: bool = String(move.get("target", "")) not in ["user", "user-and-allies"]
	if targets_opponent and defender.is_protected:
		state.add_log("%s se protege !" % GameData.fr_species(defender.species_name))
		return

	if RoleTagger.HP_EQUALIZE_MOVES.has(move_name):
		_execute_hp_equalize(state, attacker, defender, move)
		return

	if move_name == "taunt":
		if AbilityEngine.blocks_taunt(defender):
			state.add_log("%s est protege(e) de la Provocation par son talent !" % GameData.fr_species(defender.species_name))
			return
		defender.taunt_turns_left = 4
		state.add_log("%s est provoque(e) !" % GameData.fr_species(defender.species_name))
		return

	# Malediction (Curse) : effet totalement different selon le type du lanceur,
	# jamais code dans les donnees (stat_changes vide cote PokeAPI). Spectre :
	# paie la moitie de ses PV max pour infliger 1/4 PV max par tour a la
	# cible. Autre type : s'auto-baisse en Vitesse mais gagne Attaque/Defense.
	if move_name == "curse":
		if attacker.types.has("ghost"):
			attacker.apply_damage(int(attacker.max_hp / 2))
			defender.cursed = true
			state.add_log("%s se sacrifie pour maudire %s !" % [GameData.fr_species(attacker.species_name), GameData.fr_species(defender.species_name)])
		else:
			_apply_stat_change(state, attacker, "speed", -1)
			_apply_stat_change(state, attacker, "attack", 1)
			_apply_stat_change(state, attacker, "defense", 1)
		return

	# Puissance (Focus Energy) : +2 crans de critique, jamais code dans les
	# donnees (crit_rate_stage du move decrit le ratio propre au move, pas un
	# effet de statut applique au lanceur).
	if move_name == "focus-energy":
		attacker.focus_energy_active = true
		state.add_log("%s se concentre intensement !" % GameData.fr_species(attacker.species_name))
		return

	# Repos : cas particulier non couvert par le champ generique "healing"
	# (PokeAPI le laisse a 0 car ce n'est pas un soin en %) -- soigne a fond,
	# guerit tout statut existant et endort le lanceur 2 tours.
	if move_name == "rest":
		attacker.heal(attacker.max_hp)
		attacker.toxic_counter = 0
		attacker.status = "sleep"
		attacker.sleep_turns_left = 2
		state.add_log("%s se met a dormir et recupere tous ses PV !" % GameData.fr_species(attacker.species_name))
		return

	# Clonage (Substitute) : jamais implemente jusqu'ici (le move ne faisait
	# rien). Coute 1/4 des PV max (necessite plus que ca pour ne pas s'evanouir
	# en le posant) ; le clone absorbe les degats/effets a la place du vrai
	# Pokemon jusqu'a ce qu'il tombe a 0.
	if move_name == "substitute":
		if attacker.substitute_hp > 0:
			state.add_log("%s a deja un clone !" % GameData.fr_species(attacker.species_name))
			return
		var cost: int = max(1, int(attacker.max_hp / 4))
		if attacker.current_hp <= cost:
			state.add_log("%s n'a pas assez de PV pour se cloner !" % GameData.fr_species(attacker.species_name))
			return
		attacker.apply_damage(cost)
		attacker.substitute_hp = cost
		state.add_log("%s cree un clone !" % GameData.fr_species(attacker.species_name))
		return

	if RoleTagger.SELF_KO_MOVES.has(move_name):
		if AbilityEngine.blocks_explosion_family(attacker) or AbilityEngine.blocks_explosion_family(defender):
			state.add_log("Ca n'a aucun effet a cause de Moiteur !")
			return
		if move.get("power"):
			_deal_damage(state, attacker, defender, move, state.weather, is_last_to_move)
			if defender.is_fainted():
				AbilityEngine.on_ko_scored(state, attacker)
		if not attacker.is_fainted():
			attacker.apply_damage(attacker.current_hp)
			state.add_log("%s s'evanouit !" % GameData.fr_species(attacker.species_name))
		return

	# Les attaques a degats fixes (Frappe Atlas...) ont power=null dans les
	# donnees (leur degat ne depend pas de la puissance) mais infligent bien
	# des degats : il faut les traiter meme sans "power".
	var deals_damage: bool = move.get("power") != null or RoleTagger.FIXED_LEVEL_DAMAGE_MOVES.has(move_name) or RoleTagger.FIXED_VALUE_DAMAGE_MOVES.has(move_name)
	if deals_damage:
		_deal_damage(state, attacker, defender, move, state.weather, is_last_to_move)
		if defender.is_fainted():
			AbilityEngine.on_ko_scored(state, attacker)

	# Tour Rapide retire les pieges du cote du lanceur, en plus de ses degats
	# normaux (deja infliges juste au-dessus).
	if move_name == "rapid-spin" and not attacker_team.hazards.is_empty():
		attacker_team.hazards.clear()
		state.add_log("%s se degage des pieges grace a Tour Rapide !" % GameData.fr_species(attacker.species_name))

	_apply_secondary_effects(state, attacker, defender, move)

	# Piege partiel (Ligotage/Etreinte/Sinistrosion...) : jamais implemente
	# jusqu'ici (degats ponctuels sans aucun effet de piege). La cible ne peut
	# plus switcher et subit des degats fixes en fin de tour pendant 4-5 tours,
	# tant que le poseur reste sur le terrain. Ne se rafraichit pas si deja actif.
	if PARTIAL_TRAP_MOVES.has(move_name) and not defender.is_fainted() and defender.partial_trap_turns_left <= 0:
		if GameData.type_effectiveness(move.get("type", "normal"), defender.types) > 0.0:
			defender.partial_trap_turns_left = randi_range(4, 5)
			defender.partial_trap_damage = max(1, int(defender.max_hp / 8))
			defender.partial_trap_source = attacker
			state.add_log("%s ne peut plus s'echapper !" % GameData.fr_species(defender.species_name))

	# Change Eclair/Demi-Tour : le lanceur se replie juste apres avoir frappe,
	# a condition d'etre toujours en vie et d'avoir un remplacant (jamais
	# implemente jusqu'ici : les degats etaient infliges mais aucun switch ne
	# se declenchait).
	if RoleTagger.PIVOT_MOVES.has(move_name) and not attacker.is_fainted() and attacker_team.alive_members().size() > 1:
		attacker_team.pivot_pending = true


static func _attempt_protect(state: BattleState, mon: BattlePokemon) -> void:
	var success_chance := pow(1.0 / 3.0, mon.protect_streak)
	if randf() < success_chance:
		mon.is_protected = true
		mon.protect_streak += 1
		state.add_log("%s se protege !" % GameData.fr_species(mon.species_name))
	else:
		mon.protect_streak = 0
		state.add_log("%s echoue !" % GameData.fr_species(mon.species_name))


static func _set_hazard(state: BattleState, defender_team: BattleTeam, move_name: String) -> void:
	var max_layers: int = HAZARD_MAX_LAYERS[move_name]
	var current: int = defender_team.hazards.get(move_name, 0)
	if current >= max_layers:
		state.add_log("Ca n'a aucun effet, le piege est deja au maximum.")
	else:
		defender_team.hazards[move_name] = current + 1
		state.add_log("Des pieges (%s) apparaissent du cote de %s !" % [GameData.fr_move(move_name), defender_team.trainer_name])


static func _set_weather_from_move(state: BattleState, weather: String, setter: BattlePokemon) -> void:
	state.weather = weather
	state.weather_turns_left = 5 + ItemEngine.weather_duration_bonus(setter, weather)
	state.add_log("%s change la meteo : %s !" % [GameData.fr_species(setter.species_name), GameData.fr_weather(weather)])


static func _can_act(state: BattleState, team: BattleTeam, mon: BattlePokemon) -> bool:
	if mon.is_flinched:
		mon.is_flinched = false
		state.add_log("%s a peur et n'ose pas attaquer !" % GameData.fr_species(mon.species_name))
		return false

	if mon.must_recharge:
		mon.must_recharge = false
		state.add_log("%s doit recuperer et ne peut pas attaquer !" % GameData.fr_species(mon.species_name))
		return false

	match mon.status:
		"paralysis":
			if randf() < 0.25:
				state.add_log("%s est paralyse et ne peut pas attaquer !" % GameData.fr_species(mon.species_name))
				return false
		"sleep":
			if mon.sleep_turns_left > 0:
				mon.sleep_turns_left -= 1
				state.add_log("%s dort profondement." % GameData.fr_species(mon.species_name))
				return false
			mon.status = ""
		"freeze":
			if randf() < 0.2:
				mon.status = ""
				state.add_log("%s degele !" % GameData.fr_species(mon.species_name))
			else:
				state.add_log("%s est gele et ne peut pas attaquer !" % GameData.fr_species(mon.species_name))
				return false
	return true


## Formule officielle des stages de precision/esquive (echelle -6..+6 en
## ratios de 3, differente des stages classiques qui utilisent des ratios de 2).
static func _accuracy_stage_multiplier(stage: int) -> float:
	stage = clampi(stage, -6, 6)
	if stage >= 0:
		return (3.0 + stage) / 3.0
	return 3.0 / (3.0 - stage)


static func _accuracy_check(attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary, weather: String = "") -> bool:
	var accuracy = move.get("accuracy")
	if accuracy == null:
		return true
	var combined_stage: int = clampi(attacker.stat_stages.get("accuracy", 0) - defender.stat_stages.get("evasion", 0), -6, 6)
	var final_accuracy: float = float(accuracy) * _accuracy_stage_multiplier(combined_stage)
	final_accuracy *= AbilityEngine.evasion_accuracy_multiplier(defender, weather)
	if attacker.ability == "hustle" and GameData.is_physical(move):
		final_accuracy *= 0.8
	return randf() * 100.0 <= final_accuracy


static func _weather_damage_multiplier(move_type: String, weather: String) -> float:
	match weather:
		"rain":
			if move_type == "water":
				return 1.5
			if move_type == "fire":
				return 0.5
		"sun":
			if move_type == "fire":
				return 1.5
			if move_type == "water":
				return 0.5
	return 1.0


## Fonction centrale de calcul de degats, partagee par le moteur ET par l'IA
## (BattleAI l'utilise pour ses estimations, afin que l'evaluation reste
## coherente avec ce qui se passera reellement en combat).
static func compute_damage(attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary, force_crit: bool = false, random_roll: float = -1.0, weather: String = "", is_last_to_move: bool = false) -> Dictionary:
	var move_type: String = move["type"]
	var type_eff := GameData.type_effectiveness(move_type, defender.types)

	var immunity := AbilityEngine.damage_taken_modifier(defender, move_type, type_eff)
	if immunity["immune"]:
		return {
			"damage": 0, "type_eff": type_eff, "is_crit": false,
			"absorbed": true, "heal_instead": immunity["heal_instead"], "recoil": 0,
		}

	var move_name: String = move.get("name", "")
	if type_eff == 0.0 and (RoleTagger.FIXED_LEVEL_DAMAGE_MOVES.has(move_name) or RoleTagger.FIXED_VALUE_DAMAGE_MOVES.has(move_name)):
		return {"damage": 0, "type_eff": 0.0, "is_crit": false, "absorbed": false, "heal_instead": false, "recoil": 0}
	if RoleTagger.FIXED_LEVEL_DAMAGE_MOVES.has(move_name):
		return {"damage": attacker.level, "type_eff": type_eff, "is_crit": false, "absorbed": false, "heal_instead": false, "recoil": 0}
	if RoleTagger.FIXED_VALUE_DAMAGE_MOVES.has(move_name):
		return {"damage": RoleTagger.FIXED_VALUE_DAMAGE_MOVES[move_name], "type_eff": type_eff, "is_crit": false, "absorbed": false, "heal_instead": false, "recoil": 0}

	var is_physical := GameData.is_physical(move)
	var atk_stat := attacker.effective_stat("attack" if is_physical else "special_attack")
	var def_stat := defender.effective_stat("defense" if is_physical else "special_defense")

	# Stages de critique (regles recentes) : le champ crit_rate_stage du move
	# (Tranche, Coud'Krab...) et l'objet tenu (Lentille Point/Griffe Rasoir)
	# s'additionnent, jamais utilises jusqu'ici malgre la donnee deja presente.
	var crit_stage: int = int(move.get("crit_rate_stage", 0)) + ItemEngine.crit_stage_bonus(attacker) + (2 if attacker.focus_energy_active else 0)
	var crit_chance: float = CRIT_STAGE_CHANCES[clampi(crit_stage, 0, CRIT_STAGE_CHANCES.size() - 1)]
	var is_crit := (force_crit or randf() < crit_chance) and not AbilityEngine.blocks_crit(defender)
	var level_factor := (2.0 * attacker.level / 5.0) + 2.0
	var power := float(move["power"])
	var base: float = floor(floor(level_factor * power * atk_stat / def_stat) / 50.0) + 2.0

	var stab := (2.0 if AbilityEngine.uses_adaptability_stab(attacker) else STAB_MULTIPLIER) if attacker.types.has(move_type) else 1.0
	var crit_mult := CRIT_MULTIPLIER if is_crit else 1.0
	crit_mult *= AbilityEngine.crit_damage_multiplier(attacker, is_crit)
	var roll := random_roll if random_roll >= 0.0 else randf_range(0.85, 1.0)
	var weather_mult := _weather_damage_multiplier(move_type, weather)
	var ability_mult := AbilityEngine.damage_dealt_multiplier(attacker, move, is_last_to_move)
	var item_mult := ItemEngine.damage_dealt_multiplier(attacker, move, type_eff) * ItemEngine.damage_taken_multiplier(defender, is_physical)
	var defense_mult: float = immunity["multiplier"]

	var damage := int(floor(base * stab * type_eff * crit_mult * roll * weather_mult * ability_mult * item_mult * defense_mult))
	damage = max(0, damage)

	var recoil := 0
	var drain: float = move.get("drain", 0)
	if drain < 0.0 and damage > 0:
		recoil = max(1, int(ceil(damage * (-drain) / 100.0)))

	return {
		"damage": damage, "type_eff": type_eff, "is_crit": is_crit,
		"absorbed": false, "heal_instead": false, "recoil": recoil,
	}


static func _deal_damage(state: BattleState, attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary, weather: String, is_last_to_move: bool) -> void:
	var result := compute_damage(attacker, defender, move, false, -1.0, weather, is_last_to_move)

	if result["absorbed"]:
		_handle_absorb(state, defender, move["type"], result["heal_instead"])
		return

	# Clonage (Substitute) absorbe les degats a la place du vrai Pokemon (bug
	# confirme : le move ne faisait rien du tout auparavant).
	if defender.substitute_hp > 0:
		_deal_damage_to_substitute(state, attacker, defender, move, result)
		return

	var damage: int = result["damage"]

	if AbilityEngine.is_ohko_survivor(defender, damage):
		damage = defender.current_hp - 1
		state.add_log("%s tient bon grace a Fermete !" % GameData.fr_species(defender.species_name))
	elif ItemEngine.is_ohko_survivor(defender, damage):
		damage = defender.current_hp - 1
		defender.item_consumed = true
		state.add_log("%s tient bon grace a sa Focus Sash !" % GameData.fr_species(defender.species_name))

	# apply_damage() renvoie les PV REELLEMENT perdus (plafonnes a ce qu'il
	# restait) : un coup qui "acheverait" une cible avec moins de PV que les
	# degats bruts calcules ne doit pas afficher/baser ses a-cotes (drain,
	# Coque Placage) sur ce total theorique surestime (bug confirme : "perd
	# 458 PV" affiche sur un Pokemon qui n'avait plus qu'une fraction de ca).
	var damage_lost := defender.apply_damage(damage)
	ItemEngine.check_sitrus_berry(state, defender)

	if result["type_eff"] > 1.0:
		state.add_log("C'est super efficace !")
	elif result["type_eff"] < 1.0 and result["type_eff"] > 0.0:
		state.add_log("Ce n'est pas tres efficace...")
	elif result["type_eff"] == 0.0:
		state.add_log("Ca n'affecte pas %s..." % GameData.fr_species(defender.species_name))
	if result["is_crit"]:
		state.add_log("Coup critique !")
		AbilityEngine.on_crit_received(defender)

	var hit_category := "physical" if GameData.is_physical(move) else "special"
	state.add_log("%s perd %d PV." % [GameData.fr_species(defender.species_name), damage_lost], {
		"anim": "hit", "anim_category": hit_category, "anim_move_type": move.get("type", "normal"),
		"anim_target": _side_of(state, defender),
	})

	if result["recoil"] > 0 and not attacker.is_fainted() and not AbilityEngine.prevents_recoil(attacker):
		var recoil_lost := attacker.apply_damage(result["recoil"])
		state.add_log("%s subit le contrecoup ! (-%d PV)" % [GameData.fr_species(attacker.species_name), recoil_lost])

	if move.get("drain", 0) > 0 and damage_lost > 0:
		var healed := int(ceil(damage_lost * move["drain"] / 100.0 * ItemEngine.drain_heal_multiplier(attacker)))
		attacker.heal(healed)
		state.add_log("%s recupere %d PV." % [GameData.fr_species(attacker.species_name), healed])

	ItemEngine.post_attack_recoil(state, attacker, damage_lost)
	ItemEngine.post_attack_heal(state, attacker, damage_lost)


## Le clone (Substitute) prend les degats a la place du vrai Pokemon : pas de
## Fermete/Focus Sash (rien ne touche le vrai corps), pas de coup critique
## "recu" par le Pokemon reel, mais le contrecoup/drain s'appliquent quand
## meme normalement au lanceur.
static func _deal_damage_to_substitute(state: BattleState, attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary, result: Dictionary) -> void:
	var damage: int = result["damage"]
	var sub_damage: int = min(damage, defender.substitute_hp)
	defender.substitute_hp -= sub_damage

	if result["type_eff"] > 1.0:
		state.add_log("C'est super efficace !")
	elif result["type_eff"] < 1.0 and result["type_eff"] > 0.0:
		state.add_log("Ce n'est pas tres efficace...")
	elif result["type_eff"] == 0.0:
		state.add_log("Ca n'affecte pas %s..." % GameData.fr_species(defender.species_name))

	state.add_log("Le clone de %s absorbe le coup !" % GameData.fr_species(defender.species_name))
	if defender.substitute_hp <= 0:
		defender.substitute_hp = 0
		state.add_log("Le clone de %s a disparu !" % GameData.fr_species(defender.species_name))

	if result["recoil"] > 0 and not attacker.is_fainted() and not AbilityEngine.prevents_recoil(attacker):
		var recoil_lost := attacker.apply_damage(result["recoil"])
		state.add_log("%s subit le contrecoup ! (-%d PV)" % [GameData.fr_species(attacker.species_name), recoil_lost])

	if move.get("drain", 0) > 0 and sub_damage > 0:
		var healed := int(ceil(sub_damage * move["drain"] / 100.0 * ItemEngine.drain_heal_multiplier(attacker)))
		attacker.heal(healed)
		state.add_log("%s recupere %d PV." % [GameData.fr_species(attacker.species_name), healed])

	ItemEngine.post_attack_recoil(state, attacker, sub_damage)
	ItemEngine.post_attack_heal(state, attacker, sub_damage)


## Effort/Endeavor : ramene les PV de la cible a ceux du lanceur. Echoue si le
## lanceur a plus ou autant de PV que la cible (rien a "egaliser"), ou si la
## cible est immunisee au type de l'attaque (Spectre est immunise au Normal).
## Coeur de la strategie FEAR (Focus Sash + Endeavor + Quick Attack).
static func _execute_hp_equalize(state: BattleState, attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary) -> void:
	var move_type: String = move.get("type", "normal")
	if GameData.type_effectiveness(move_type, defender.types) == 0.0:
		state.add_log("Ca n'affecte pas %s..." % GameData.fr_species(defender.species_name))
		return
	if attacker.current_hp >= defender.current_hp:
		state.add_log("%s echoue !" % GameData.fr_species(attacker.species_name))
		return

	var damage := defender.current_hp - attacker.current_hp
	defender.apply_damage(damage)
	state.add_log("%s ramene %s a ses PV !" % [GameData.fr_species(attacker.species_name), GameData.fr_species(defender.species_name)], {
		"anim": "hit", "anim_category": "physical", "anim_move_type": move_type,
		"anim_target": _side_of(state, defender),
	})
	if defender.is_fainted():
		AbilityEngine.on_ko_scored(state, attacker)


static func _handle_absorb(state: BattleState, defender: BattlePokemon, move_type: String, heal_instead: bool) -> void:
	state.add_log("%s absorbe l'attaque grace a son talent !" % GameData.fr_species(defender.species_name))
	if heal_instead:
		var heal := int(defender.max_hp / 4)
		defender.heal(heal)
		state.add_log("%s recupere %d PV !" % [GameData.fr_species(defender.species_name), heal])
	elif defender.ability == "flash-fire" and move_type == "fire":
		defender.flash_fire_active = true
		state.add_log("%s s'embrase ! Ses attaques Feu sont boostees." % GameData.fr_species(defender.species_name))
	elif defender.ability == "lightning-rod" and move_type == "electric":
		defender.stat_stages["special_attack"] = clampi(defender.stat_stages["special_attack"] + 1, -6, 6)
		state.add_log("%s absorbe l'electricite ! Attaque Speciale +1." % GameData.fr_species(defender.species_name))


## Quelques attaques a tres fort degat baissent une stat du LANCEUR en
## contrepartie, alors que leur champ "target" (PokeAPI) decrit la cible des
## DEGATS, pas celle du malus -- sans cette liste, le malus s'appliquait par
## erreur a l'adversaire (bug confirme sur Draco-Souffle/Draco Meteor).
const SELF_DEBUFF_MOVES := ["draco-meteor", "overheat", "leaf-storm", "psycho-boost", "superpower", "close-combat", "v-create"]


static func _apply_secondary_effects(state: BattleState, attacker: BattlePokemon, defender: BattlePokemon, move: Dictionary) -> void:
	var target_self: bool = String(move.get("target", "")) in ["user", "user-and-allies"] or SELF_DEBUFF_MOVES.has(move.get("name", ""))
	var target: BattlePokemon = attacker if target_self else defender
	# Serenite (Serene Grace) double la chance de TOUS les effets secondaires
	# (statut, changement de stat, apeurement) de son porteur.
	var chance_mult: float = AbilityEngine.secondary_effect_chance_multiplier(attacker)

	# Clonage (Substitute) bloque tous les effets secondaires HOSTILES (statut,
	# baisse de stat, apeurement) tant qu'il est en place -- ne bloque jamais
	# les propres effets du lanceur sur lui-meme (Danse Lames sur soi...).
	# Simplification assumee : si CE coup casse le clone, l'effet secondaire
	# de ce meme coup reste bloque (regle des jeux), mais un clone deja a 0
	# PV avant ce coup ne bloque plus rien, comme attendu.
	var blocked_by_substitute: bool = not target_self and defender.substitute_hp > 0

	# Changements de stats (buff/debuff)
	var stat_changes: Array = move.get("stat_changes", [])
	if not stat_changes.is_empty() and not blocked_by_substitute:
		var chance: int = move.get("stat_chance", 0)
		if chance == 0 or randf() * 100.0 <= float(chance) * chance_mult:
			for sc: Dictionary in stat_changes:
				# Les talents comme Corps Sain/Regard Vif ne bloquent que les
				# baisses infligees par l'ADVERSAIRE, jamais l'auto-malus des
				# propres attaques du Pokemon (Surchauffe, Draco-Meteore...).
				if int(sc["change"]) < 0 and not target_self and AbilityEngine.blocks_stat_drop(target, sc["stat"]):
					state.add_log("%s est protege(e) contre la baisse de stat par son talent !" % GameData.fr_species(target.species_name))
					continue
				_apply_stat_change(state, target, sc["stat"], sc["change"])

	# Statut inflige (poison, paralysie, sommeil...)
	var ailment: String = move.get("ailment", "none")
	# PokeAPI classe Toxic dans la categorie generique "poison" (son API ne
	# distingue pas poison normal / grave), mais c'est bien le poison grave a
	# degats croissants qu'il faut appliquer ici.
	if move.get("name", "") == "toxic":
		ailment = "toxic"
	if ailment != "none" and ailment != "unknown" and not blocked_by_substitute:
		var chance: int = move.get("ailment_chance", 0)
		var will_apply := chance == 0 or randf() * 100.0 <= float(chance) * chance_mult
		if will_apply:
			_inflict_status(state, defender, ailment, move.get("name", ""))
			# Synchro (Synchronize) renvoie poison/brulure/paralysie a l'auteur
			# de l'attaque (jamais sommeil/gel, conformement aux jeux officiels).
			if defender.status == ailment and defender.ability == "synchronize" and ailment in ["poison", "toxic", "paralysis", "burn"] and not attacker.is_fainted():
				_inflict_status(state, attacker, ailment)

	# Apeurement (flinch) : chance propre au move, ou 10% via le talent
	# Puanteur (Stench) si le move n'en a normalement aucune.
	var flinch_chance: int = AbilityEngine.stench_flinch_chance(attacker, int(move.get("flinch_chance", 0)))
	if flinch_chance > 0 and not defender.is_fainted() and not AbilityEngine.prevents_flinch(defender) and not blocked_by_substitute:
		if randf() * 100.0 <= float(flinch_chance) * chance_mult:
			defender.is_flinched = true
			state.add_log("%s a maintenant peur !" % GameData.fr_species(defender.species_name))

	# Soin en % des PV max (Repos-Sur, Sieste Auree, Damage-Sur, Synthese...).
	# Repos (Rest) a son propre cas particulier gere plus haut (soin total +
	# sommeil), donc son champ "healing" vaut 0 dans les donnees et ne
	# declenche jamais cette branche.
	var healing_pct: int = move.get("healing", 0)
	if healing_pct > 0 and not target.is_fainted():
		var heal_amount: int = int(ceil(target.max_hp * healing_pct / 100.0))
		target.heal(heal_amount)
		state.add_log("%s recupere des PV !" % GameData.fr_species(target.species_name))


static func _apply_stat_change(state: BattleState, mon: BattlePokemon, stat_key: String, change: int) -> void:
	var mapped := stat_key.replace("special-attack", "special_attack").replace("special-defense", "special_defense")
	if not mon.stat_stages.has(mapped):
		return
	var before: int = mon.stat_stages[mapped]
	mon.stat_stages[mapped] = clampi(before + change, -6, 6)
	var verb := "augmente" if change > 0 else "baisse"
	state.add_log("%s : %s %s !" % [GameData.fr_species(mon.species_name), GameData.fr_stat(mapped), verb], {
		"anim": "stat_up" if change > 0 else "stat_down", "anim_stat": mapped, "anim_target": _side_of(state, mon),
	})


const POWDER_MOVES := ["sleep-powder", "poison-powder", "stun-spore", "spore", "cotton-spore"]


## Immunites de statut liees au type (regles modernes) : Poison/Acier ne
## peuvent pas etre empoisonnes, Feu ne peut pas etre brule, Electrik ne peut
## pas etre paralyse, Glace ne peut pas etre gele, Plante est immunise aux
## moves a base de poudre (mais pas a Hypnose/Sommeil qui ne sont pas des poudres).
static func _is_status_type_immune(mon: BattlePokemon, ailment: String, move_name: String) -> bool:
	match ailment:
		"poison", "toxic":
			return mon.types.has("poison") or mon.types.has("steel")
		"burn":
			return mon.types.has("fire")
		"paralysis":
			return mon.types.has("electric")
		"freeze":
			return mon.types.has("ice")
		"sleep":
			return POWDER_MOVES.has(move_name) and mon.types.has("grass")
	return false


static func _inflict_status(state: BattleState, mon: BattlePokemon, ailment: String, move_name: String = "") -> void:
	if mon.status != "":
		return
	if _is_status_type_immune(mon, ailment, move_name):
		# Message explicite (et non le generique "Ca n'a aucun effet...") : ce
		# n'est pas le COUP qui rate, seulement l'effet de statut secondaire
		# qui est bloque -- confusion possible sinon quand ce message apparait
		# juste apres une ligne de degats bien infliges (bug de clarte confirme).
		state.add_log("%s est immunise contre %s par son type !" % [GameData.fr_species(mon.species_name), GameData.fr_status(ailment)])
		return
	if AbilityEngine.prevents_status(mon, ailment):
		state.add_log("%s est protege de ce statut par son talent !" % GameData.fr_species(mon.species_name))
		return
	if ailment == "confusion":
		return  # non gere en v1
	mon.status = ailment
	if ailment == "sleep":
		mon.sleep_turns_left = randi_range(1, 3)
	if ailment == "toxic":
		mon.toxic_counter = 0
	state.add_log("%s est affecte par : %s !" % [GameData.fr_species(mon.species_name), GameData.fr_status(ailment)], {
		"anim": "status", "anim_status": ailment, "anim_target": _side_of(state, mon),
	})
	ItemEngine.check_lum_berry(state, mon)


static func _apply_end_of_turn_status(state: BattleState, team: BattleTeam) -> void:
	var mon := team.active()
	if mon.is_fainted():
		return
	if AbilityEngine.blocks_indirect_damage(mon):
		return
	match mon.status:
		"burn":
			var dmg: int = max(1, int(mon.max_hp / 16))
			var lost := mon.apply_damage(dmg)
			state.add_log("%s souffre de sa brulure ! (-%d PV)" % [GameData.fr_species(mon.species_name), lost])
		"poison":
			var dmg: int = max(1, int(mon.max_hp / 8))
			var lost := mon.apply_damage(dmg)
			state.add_log("%s souffre du poison ! (-%d PV)" % [GameData.fr_species(mon.species_name), lost])
		"toxic":
			mon.toxic_counter += 1
			var dmg: int = max(1, int(mon.max_hp * mon.toxic_counter / 16))
			var lost := mon.apply_damage(dmg)
			state.add_log("%s souffre gravement du poison ! (-%d PV)" % [GameData.fr_species(mon.species_name), lost])

	if mon.cursed and not mon.is_fainted():
		var curse_dmg: int = max(1, int(mon.max_hp / 4))
		var curse_lost := mon.apply_damage(curse_dmg)
		state.add_log("%s souffre de la Malediction ! (-%d PV)" % [GameData.fr_species(mon.species_name), curse_lost])

	if mon.partial_trap_turns_left > 0 and not mon.is_fainted():
		# Le piege partiel se leve immediatement si le poseur a quitte le
		# terrain entre-temps (switch ou KO), comme dans les jeux officiels.
		if mon.partial_trap_source == null or mon.partial_trap_source != state.other_team(team).active():
			mon.partial_trap_turns_left = 0
			mon.partial_trap_source = null
		else:
			mon.partial_trap_turns_left -= 1
			var trap_lost := mon.apply_damage(mon.partial_trap_damage)
			state.add_log("%s est blesse(e) par le piege ! (-%d PV)" % [GameData.fr_species(mon.species_name), trap_lost])
			if mon.partial_trap_turns_left <= 0:
				state.add_log("%s est libere(e) du piege !" % GameData.fr_species(mon.species_name))
				mon.partial_trap_source = null


static func _apply_weather_end_of_turn(state: BattleState) -> void:
	if state.weather == "sandstorm":
		_apply_weather_chip(state, state.team_a, ["rock", "ground", "steel"])
		_apply_weather_chip(state, state.team_b, ["rock", "ground", "steel"])
	elif state.weather == "hail":
		_apply_weather_chip(state, state.team_a, ["ice"])
		_apply_weather_chip(state, state.team_b, ["ice"])

	if state.weather_turns_left > 0:
		state.weather_turns_left -= 1
		if state.weather_turns_left == 0:
			state.add_log("La meteo redevient normale.")
			state.weather = ""


static func _apply_weather_chip(state: BattleState, team: BattleTeam, immune_types: Array) -> void:
	var mon := team.active()
	if mon.is_fainted():
		return
	for t: String in immune_types:
		if mon.types.has(t):
			return
	if AbilityEngine.is_immune_to_weather_chip(mon):
		return
	if mon.ability == "ice-body" and state.weather == "hail":
		mon.heal(max(1, int(mon.max_hp / 16)))
		state.add_log("%s se soigne grace a Corps Neige sous la grele !" % GameData.fr_species(mon.species_name))
		return
	var dmg: int = max(1, int(mon.max_hp / 16))
	var lost := mon.apply_damage(dmg)
	state.add_log("%s souffre de la meteo ! (-%d PV)" % [GameData.fr_species(mon.species_name), lost])
