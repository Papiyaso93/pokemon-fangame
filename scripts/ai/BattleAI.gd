class_name BattleAI
extends RefCounted
## Choisit l'action du CPU pour un tour. Ne lit JAMAIS l'action reelle de
## l'adversaire : uniquement l'etat visible (Pokemon en jeu, %HP, moves deja
## reveles, equipe restante) pour estimer une distribution de reponses plausibles.

const AVERAGE_ROLL := 0.925  # moyenne du random de degats (0.85 a 1.0)


static func choose_action(state: BattleState, my_team: BattleTeam, profile: AIProfile) -> BattleAction:
	var opp_team := state.other_team(my_team)

	# Remplacement force (mon actif est KO) : on ne connait pas encore le futur
	# entrant, donc on suppose simplement que l'adversaire reste sur son actif.
	var opponent_scenarios: Array
	if my_team.active().is_fainted():
		opponent_scenarios = [{"kind": "stay", "index": opp_team.active_index, "weight": 1.0}]
	else:
		opponent_scenarios = _estimate_opponent_scenarios(my_team.active(), opp_team, state.weather)

	# "Prediction inter-tours" : win condition + obstacles recalcules a partir
	# de l'etat ACTUEL a chaque appel (pas un plan fige) -- si la situation a
	# change depuis le tour precedent (KO, nouvelle menace...), le plan suit.
	var plan := GamePlan.build(my_team, opp_team)

	var candidates := _generate_candidates(my_team)
	var best: BattleAction = null
	var best_score := -INF

	for action: BattleAction in candidates:
		var score := _score_action(state, my_team, opp_team, action, opponent_scenarios, profile, plan)
		if score > best_score:
			best_score = score
			best = action

	return best


## Choisit le Pokemon de tete du CPU par analyse de l'equipe adverse (vitesse,
## types, stats, movepool, degats estimes dans les deux sens) plutot que de
## toujours prendre le slot 0. Le resultat est PROBABILISTE (pas le meilleur
## a coup sur) : les meilleurs candidats ont plus de chances d'etre envoyes,
## mais au moins les 3 meilleurs gardent un minimum de 5% de chances chacun,
## pour eviter un pattern 100% previsible.
static func choose_lead(my_team: BattleTeam, opp_team: BattleTeam, profile: AIProfile) -> int:
	var alive_indices: Array = []
	var fitness: Array = []
	for i in range(my_team.members.size()):
		if my_team.members[i].is_fainted():
			continue
		alive_indices.append(i)
		fitness.append(_lead_fitness(my_team.members[i], opp_team, profile))

	if alive_indices.is_empty():
		return 0
	if alive_indices.size() == 1:
		return alive_indices[0]

	var weights := _softmax_with_floor(fitness, 3, 0.05)
	var roll := randf()
	var cumulative := 0.0
	for i in range(alive_indices.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return alive_indices[i]
	return alive_indices[alive_indices.size() - 1]


## Efficacite estimee d'un Pokemon comme lead face a TOUTE l'equipe adverse
## (pas juste son actif) : degats qu'il inflige en moyenne moins degats subis
## en moyenne, avantage de vitesse, et bonus de plan de jeu (hazards/meteo/sweep).
static func _lead_fitness(mon: BattlePokemon, opp_team: BattleTeam, profile: AIProfile) -> float:
	var opp_alive := opp_team.alive_members()
	if opp_alive.is_empty():
		return 0.0

	var offense := 0.0
	var defense_risk := 0.0
	var faster_count := 0
	for opp_mon: BattlePokemon in opp_alive:
		offense += _worst_case_threat(mon, opp_mon)
		defense_risk += _worst_case_threat(opp_mon, mon)
		if BattleEngine.get_speed(mon, "") > BattleEngine.get_speed(opp_mon, ""):
			faster_count += 1

	var n := float(opp_alive.size())
	var net_matchup := (offense - defense_risk) / n
	var speed_edge := float(faster_count) / n

	var fitness := net_matchup * 40.0 + speed_edge * 15.0

	if mon.role_tags.has("hazard_setter"):
		fitness += 8.0 * profile.hazard_priority

	# Poseur de meteo : si l'adversaire a lui-meme un poseur, la meteo posee en
	# DERNIER l'emporte (cf bug corrige Politoed/Feunard) -- donc ne lead avec
	# le mien QUE s'il est plus lent que le sien (je pose apres, je gagne la
	# course). S'il est plus rapide, je poserais en premier et me ferais
	# ecraser aussitot : mieux vaut garder ce Pokemon pour plus tard. Si
	# l'adversaire n'a pas de poseur visible, aucun risque a le lead direct.
	if mon.role_tags.has("weather_setter"):
		var opp_setter := _find_weather_setter(opp_team)
		if opp_setter == null:
			fitness += 8.0 * profile.weather_priority
		elif BattleEngine.get_speed(mon, "") < BattleEngine.get_speed(opp_setter, ""):
			fitness += 10.0 * profile.weather_priority
		else:
			fitness -= 6.0 * profile.weather_priority

	if mon.role_tags.has("sweeper") and speed_edge > 0.5:
		fitness += 6.0 * profile.setup_priority

	return fitness


## Premier Pokemon vivant de `team` dont le talent pose une meteo (Drizzle,
## Secheresse, Sable Stream, Neige Poudreuse), ou null si aucun.
static func _find_weather_setter(team: BattleTeam) -> BattlePokemon:
	for mon: BattlePokemon in team.alive_members():
		if AbilityEngine.WEATHER_SETTERS.has(mon.ability):
			return mon
	return null


## Transforme des scores bruts en probabilites (softmax), puis force un
## plancher pour les `floor_count` meilleurs candidats (ex: au moins 3
## Pokemon avec >=5% de chances chacun), en reprenant la masse manquante sur
## les autres proportionnellement a leurs poids actuels.
static func _softmax_with_floor(scores: Array, floor_count: int, floor_value: float) -> Array:
	var n := scores.size()
	var max_score: float = scores.max() if n > 0 else 0.0
	var exp_weights: Array = []
	for s: float in scores:
		exp_weights.append(exp((s - max_score) / 20.0))  # temperature = 20
	var total: float = 0.0
	for w: float in exp_weights:
		total += w
	var weights: Array = []
	for w: float in exp_weights:
		weights.append(w / total)

	var floored_n: int = min(floor_count, n)
	if floored_n <= 0:
		return weights

	var order: Array = range(n)
	order.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	var top_indices: Array = order.slice(0, floored_n)

	var floor_total := 0.0
	var to_floor: Array = []
	for idx: int in top_indices:
		if weights[idx] < floor_value:
			to_floor.append(idx)
			floor_total += floor_value

	if to_floor.is_empty():
		return weights

	var remaining_total := 1.0 - floor_total
	var others_total := 0.0
	for i in range(n):
		if not to_floor.has(i):
			others_total += weights[i]

	var result: Array = []
	for i in range(n):
		if to_floor.has(i):
			result.append(floor_value)
		elif others_total > 0.0:
			result.append(weights[i] / others_total * remaining_total)
		else:
			result.append(0.0)
	return result


static func _generate_candidates(team: BattleTeam) -> Array:
	var candidates: Array = []
	var active := team.active()

	# Actif KO : remplacement force, aucune attaque possible ce "sous-tour".
	if active.is_fainted():
		for i in range(team.members.size()):
			if i != team.active_index and not team.members[i].is_fainted():
				candidates.append(BattleAction.switch_to(i))
		return candidates

	for m: String in active.moves:
		if active.pp_left.get(m, 0) > 0:
			candidates.append(BattleAction.move(m))
	# Piege partiel (Ligotage...) : ne peut pas switcher tant que pris au piege.
	if active.partial_trap_turns_left <= 0:
		for i in range(team.members.size()):
			if i != team.active_index and not team.members[i].is_fainted():
				candidates.append(BattleAction.switch_to(i))
	if candidates.is_empty():
		candidates.append(BattleAction.move(active.moves[0]))
	return candidates


## Estime une distribution de scenarios probables pour le prochain coup de l'adversaire,
## uniquement a partir d'infos visibles (types, %HP, moves deja reveles).
## Renvoie Array[{ "kind": "stay"/"switch", "index": int, "weight": float }]
static func _estimate_opponent_scenarios(my_active: BattlePokemon, opp_team: BattleTeam, weather: String = "") -> Array:
	var opp_active := opp_team.active()

	# Menace que je represente pour l'actif adverse (pire cas parmi mes coups connus).
	var danger := _worst_case_threat(my_active, opp_active, weather)
	var low_hp_pressure := 1.0 - opp_active.hp_percent()  # plus il est bas, plus il a interet a switcher

	var switch_probability: float = clampf(danger * 0.8 + low_hp_pressure * 0.4, 0.0, 0.75)
	if opp_active.is_fainted():
		switch_probability = 1.0

	var scenarios: Array = []
	scenarios.append({"kind": "stay", "index": opp_team.active_index, "weight": 1.0 - switch_probability})

	var alive_others := []
	for i in range(opp_team.members.size()):
		if i != opp_team.active_index and not opp_team.members[i].is_fainted():
			alive_others.append(i)

	if switch_probability > 0.0 and not alive_others.is_empty():
		# Ils choisiraient plutot leur meilleure reponse defensive contre mon actif :
		# on pondere chaque switch possible par sa qualite de matchup (pas uniforme).
		var weights: Array = []
		var total := 0.0
		for i in alive_others:
			var w := _matchup_quality(opp_team.members[i], my_active)
			weights.append(w)
			total += w
		for idx in range(alive_others.size()):
			var share: float = (float(weights[idx]) / total) if total > 0.0 else (1.0 / alive_others.size())
			scenarios.append({"kind": "switch", "index": alive_others[idx], "weight": switch_probability * share})
	elif switch_probability > 0.0:
		# personne d'autre en vie : ils restent forcement
		scenarios[0]["weight"] = 1.0

	return scenarios


## Pire degat potentiel (en %HP) que mon actif pourrait infliger, en tenant compte
## des moves deja reveles de mon espece ; si rien n'est revele, estimation generique STAB.
static func _worst_case_threat(attacker: BattlePokemon, defender: BattlePokemon, weather: String = "") -> float:
	var worst := 0.0
	for m: String in attacker.moves:
		var move := GameData.get_move(m)
		if not move.get("power"):
			continue
		var result := BattleEngine.compute_damage(attacker, defender, move, false, AVERAGE_ROLL, weather)
		var pct: float = float(result["damage"]) / float(defender.max_hp)
		worst = max(worst, pct)
	return clampf(worst, 0.0, 1.0)


## Qualite (0..1) du matchup defensif de "candidate" contre "threat" (plus haut = meilleur switch-in).
static func _matchup_quality(candidate: BattlePokemon, threat: BattlePokemon) -> float:
	var incoming := _worst_case_threat(threat, candidate)
	var quality := 1.0 - incoming
	return clampf(quality, 0.05, 1.0)


## Estimation (optimiste, un seul coup par cible) : "mon" peut-il a lui seul
## OHKO chaque Pokemon encore en vie de l'equipe adverse ? Sert a detecter le
## cas de sweep quasi-garanti ou rester au combat et attaquer prime sur tout.
static func _can_sweep_remaining_team(mon: BattlePokemon, opp_team: BattleTeam, weather: String) -> bool:
	for opp_mon: BattlePokemon in opp_team.alive_members():
		if _worst_case_threat(mon, opp_mon, weather) < 1.0:
			return false
	return true


static func _score_action(state: BattleState, my_team: BattleTeam, opp_team: BattleTeam, action: BattleAction, opponent_scenarios: Array, profile: AIProfile, plan: Dictionary = {}) -> float:
	var score := 0.0
	for scenario: Dictionary in opponent_scenarios:
		var opp_active_after: BattlePokemon = opp_team.members[scenario["index"]]
		var is_switch_scenario: bool = scenario.get("kind", "") == "switch"
		score += float(scenario["weight"]) * _score_against(state, my_team, opp_team, action, opp_active_after, profile, is_switch_scenario, plan)

	score += _gameplan_bonus(state, my_team, opp_team, action, profile, plan)
	return score


## Score de "action" en supposant que l'actif adverse au moment de la resolution
## sera opp_active. `is_switch_scenario` indique que ce scenario represente un
## SWITCH adverse (utile pour Poursuite, qui intercepte alors le Pokemon
## ACTUEL avant qu'il ne parte, pas le remplacant).
static func _score_against(state: BattleState, my_team: BattleTeam, opp_team: BattleTeam, action: BattleAction, opp_active: BattlePokemon, profile: AIProfile, is_switch_scenario: bool = false, plan: Dictionary = {}) -> float:
	if action.kind == BattleAction.Kind.SWITCH:
		var candidate: BattlePokemon = my_team.members[action.switch_index]
		var candidate_quality := _matchup_quality(candidate, opp_active)
		var current_quality := _matchup_quality(my_team.active(), opp_active)
		# Le switch n'est valorise que s'il AMELIORE reellement le matchup courant
		# (sinon un profil "safety" haut rendait n'importe quel switch attractif).
		# Le poids de base est le MEME pour tous les profils (un switch defensif
		# clair doit se voir meme en Hyper Offense) ; "safety" ne fait que
		# moduler cette base en plus ou en moins, au lieu de l'ecraser pour les
		# profils peu prudents (bug confirme : seul Stall switchait sur un
		# mauvais matchup evident, Equilibre/Offensif attaquaient quand meme).
		var improvement := candidate_quality - current_quality
		var base_score := improvement * 70.0
		var safety_adjustment := improvement * 25.0 * (profile.safety - 1.0)
		var weather_bonus := _weather_setter_switch_bonus(my_team, opp_team, candidate, opp_active, state.weather, profile)
		# Win condition (gameplan) : la voie est degagee (plus d'obstacle
		# vivant) -> c'est le moment de la lancer plutot que de la garder au
		# chaud indefiniment.
		var win_condition_bonus := 0.0
		if candidate == plan.get("win_condition") and plan.get("obstacles", []).is_empty():
			win_condition_bonus = 35.0
		return base_score + safety_adjustment + candidate_quality * 6.0 + weather_bonus + win_condition_bonus

	var attacker := my_team.active()

	# Coince en rechargement (apres Lance-Soleil/Ultralaser...) : l'attaque
	# choisie ne fera RIEN ce tour (bloquee par _can_act), donc rester au
	# combat n'a aucune valeur offensive. Un switch ne coute rien de plus
	# (le tour etait de toute facon perdu) et evite d'encaisser un coup gratuit
	# -- bug confirme (Rafflesia restait en recharge sous Psyko au lieu de switcher).
	if attacker.must_recharge:
		return -20.0

	var move := GameData.get_move(action.move_name)
	var score := 0.0

	# Poursuite dans un scenario de switch adverse : intercepte le Pokemon
	# ACTUELLEMENT en jeu (avant qu'il ne parte) a puissance doublee, au lieu
	# de rater le remplacant comme le calcul generique le supposerait.
	if action.move_name == "pursuit" and is_switch_scenario:
		var current_opp := opp_team.active()
		var boosted := move.duplicate(true)
		boosted["power"] = int(move.get("power", 40)) * 2
		var pursuit_result := BattleEngine.compute_damage(attacker, current_opp, boosted, false, AVERAGE_ROLL, state.weather)
		var pursuit_dmg_pct: float = float(pursuit_result["damage"]) / float(max(1, current_opp.max_hp))
		var pursuit_kills: bool = pursuit_result["damage"] >= current_opp.current_hp
		return pursuit_dmg_pct * 130.0 * profile.aggression + (80.0 if pursuit_kills else 0.0)

	if move.get("power"):
		# Bug confirme : l'IA choisissait Lance-Soleil (et restait en jeu au
		# lieu de switcher face a une menace) sur la base de ses pleins degats
		# theoriques, sans savoir que ce tour prend en fait la charge (0 degat
		# reel) faute de Soleil actif -- ce qui masquait aussi a tort le
		# signal "l'adversaire risque de me tuer, je devrais switcher".
		var is_starting_charge: bool = RoleTagger.CHARGE_MOVES.has(action.move_name) and attacker.charging_move != action.move_name and state.weather != RoleTagger.CHARGE_MOVES[action.move_name]
		var result := BattleEngine.compute_damage(attacker, opp_active, move, false, AVERAGE_ROLL, state.weather)
		var effective_damage: int = 0 if is_starting_charge else result["damage"]
		var dmg_pct: float = float(effective_damage) / float(max(1, opp_active.max_hp))
		var i_kill_them: bool = effective_damage >= opp_active.current_hp
		score += dmg_pct * 100.0 * profile.aggression

		# Punir un sweeper deja en train de monter en stats est urgent (bug
		# confirme : l'IA laissait Danse Draco s'enchainer 3 fois sans jamais
		# reagir) -- plus il est deja boste, plus l'attaquer maintenant prime
		# sur n'importe quelle autre option (pieges, statut, etc.).
		var opp_boost_stages: int = max(0, opp_active.stat_stages.get("attack", 0)) + max(0, opp_active.stat_stages.get("special_attack", 0)) + max(0, opp_active.stat_stages.get("speed", 0))
		if opp_boost_stages > 0:
			score += float(opp_boost_stages) * 8.0 * profile.aggression

		if i_kill_them:
			score += 60.0 * profile.aggression
			# Cas quasi-certain : ce coup tue ET mon equipe peut estimer tuer
			# tout le reste de l'equipe adverse -> rester et attaquer est la
			# seule option sensee (switcher ne ferait que repousser le KO).
			if _can_sweep_remaining_team(attacker, opp_team, state.weather):
				score += 300.0
			# Un KO n'est vraiment SUR que si j'agis en premier : si je suis
			# plus lent que l'adversaire, il pourrait riposter (et potentiellement
			# me tuer, ex: strategie FEAR a 1 PV) avant que mon attaque ne parte.
			# Une attaque prioritaire securise le KO dans ce cas precis.
			var move_priority: int = move.get("priority", 0)
			if move_priority > 0 and BattleEngine.get_speed(attacker, state.weather) < BattleEngine.get_speed(opp_active, state.weather):
				score += 25.0
		else:
			var opp_faster := BattleEngine.get_speed(opp_active, state.weather) > BattleEngine.get_speed(attacker, state.weather)
			var incoming: float = _worst_case_threat(opp_active, attacker, state.weather)
			if is_switch_scenario:
				# Bug confirme : un adversaire qui VIENT DE switcher a deja
				# consomme son tour -- il ne peut pas aussi me frapper ce
				# meme tour. Le danger qu'il represente (ex: un Nymphali
				# rapide qui OHKO derriere un Mewtwo qui ne fait que 2HKO)
				# n'arrive qu'au tour SUIVANT, une fois qu'il a pu agir.
				# On le penalise donc en continu (proportionnel au risque
				# reel, pas un seuil tout-ou-rien) et attenue (j'aurai encore
				# une chance de reagir/switcher avant que ce risque se
				# concretise), plutot que comme une mort immediate.
				var deferred_penalty_weight: float = 15.0 if BattleEngine.get_speed(attacker, state.weather) >= BattleEngine.get_speed(opp_active, state.weather) else 35.0
				score -= incoming * deferred_penalty_weight * profile.safety
			elif opp_faster and incoming >= 1.0:
				# Course de vitesse : adversaire plus rapide qui peut me OHKO ce
				# tour alors que je ne le tue pas -> rester attaquer ne sert a
				# rien (je meurs avant d'avoir fait quoi que ce soit d'utile),
				# un switch est presque toujours strictement meilleur ici.
				score -= 45.0 * profile.safety
		var accuracy = move.get("accuracy")
		if accuracy != null and accuracy < 90:
			score -= (100.0 - accuracy) * 0.3 * profile.risk_aversion
	else:
		# Bug confirme : un piege (Pics Toxik...) deja au maximum de couches
		# touchait quand meme ce bonus plat, poussant l'IA a le reposer pour
		# "Ca n'a aucun effet" au lieu d'attaquer. Aucune valeur a un move de
		# statut qui ne peut plus rien faire.
		var is_maxed_hazard: bool = BattleEngine.HAZARD_MAX_LAYERS.has(action.move_name) and opp_team.hazards.get(action.move_name, 0) >= BattleEngine.HAZARD_MAX_LAYERS.get(action.move_name, 0)
		if not is_maxed_hazard:
			score += 5.0  # les moves de statut/buff purs sont valorises via le bonus de plan de jeu

	if BattleEngine.get_speed(attacker, state.weather) > BattleEngine.get_speed(opp_active, state.weather):
		score += 3.0

	return score


## Logique de switch specifique a un poseur de meteo : ne vaut le coup que si
## la meteo desiree n'est pas deja active (sinon rien a contrer). Au-dela d'un
## risque minimal, il DOIT vouloir contrer la meteo adverse en posant la
## sienne -- le bonus croit avec la securite du switch (moins il y a de
## risque, plus il doit le faire), plutot qu'un seuil tout-ou-rien. Seul un
## risque vraiment eleve fait basculer en logique de sacrifice pur : la ne se
## justifie plus que si un AUTRE Pokemon de l'equipe peut battre l'actif
## adverse une fois la meteo posee, et seulement si l'adversaire n'a plus de
## poseur (talent) capable de la recontester derriere.
static func _weather_setter_switch_bonus(my_team: BattleTeam, opp_team: BattleTeam, candidate: BattlePokemon, opp_active: BattlePokemon, weather: String, profile: AIProfile) -> float:
	if not candidate.role_tags.has("weather_setter"):
		return 0.0
	var desired := _desired_weather_of(candidate)
	if desired == "" or weather == desired:
		return 0.0

	var candidate_quality := _matchup_quality(candidate, opp_active)
	if candidate_quality >= 0.20:
		# Contrer vaut le coup des que le risque est raisonnable : le bonus est
		# proportionnel a la securite du switch (jusqu'a 18 * poids si tres sur).
		return 18.0 * profile.weather_priority * candidate_quality

	if not _sacrifice_sets_up_sweep(my_team, candidate, opp_active, desired):
		return 0.0
	if _find_weather_setter(opp_team) != null:
		return 0.0  # l'adversaire peut recontester la meteo, sacrifice inutile

	# Aucun poseur en face : une fois posee, la meteo ne sera jamais contestee.
	return 30.0 * profile.weather_priority


## Vrai si ce Pokemon a deja gagne au moins un cran offensif (Attaque/AttSpe)
## ou de Vitesse : signe qu'il est en train de monter en stats et devient une
## menace grandissante qu'il faut punir maintenant plutot que poursuivre son
## propre plan de jeu (pieges/meteo) sans se soucier de lui.
static func _opponent_is_setting_up(mon: BattlePokemon) -> bool:
	return mon.stat_stages.get("attack", 0) > 0 or mon.stat_stages.get("special_attack", 0) > 0 or mon.stat_stages.get("speed", 0) > 0


static func _desired_weather_of(mon: BattlePokemon) -> String:
	if AbilityEngine.WEATHER_SETTERS.has(mon.ability):
		return AbilityEngine.WEATHER_SETTERS[mon.ability]
	for m: String in mon.moves:
		if RoleTagger.WEATHER_MOVES.has(m):
			return RoleTagger.WEATHER_MOVES[m]
	return ""


## Un AUTRE membre de l'equipe (pas le poseur lui-meme) bat-il l'actif adverse
## une fois la meteo desiree active (plus rapide sous cette meteo ET peut le
## OHKO/tres largement blesser) ? Sert a juger si sacrifier le poseur en vaut la peine.
static func _sacrifice_sets_up_sweep(my_team: BattleTeam, setter: BattlePokemon, opp_active: BattlePokemon, desired_weather: String) -> bool:
	for mon: BattlePokemon in my_team.alive_members():
		if mon == setter:
			continue
		var my_speed := BattleEngine.get_speed(mon, desired_weather)
		var opp_speed := BattleEngine.get_speed(opp_active, desired_weather)
		if my_speed > opp_speed and _worst_case_threat(mon, opp_active, desired_weather) >= 1.0:
			return true
	return false


## Bonus lies au plan de jeu de l'equipe (hazards, meteo, setup sweeper, statut cible sur la menace).
static func _gameplan_bonus(state: BattleState, my_team: BattleTeam, opp_team: BattleTeam, action: BattleAction, profile: AIProfile, plan: Dictionary = {}) -> float:
	if action.kind != BattleAction.Kind.MOVE:
		return 0.0

	var attacker := my_team.active()
	var move := GameData.get_move(action.move_name)
	var bonus := 0.0

	if attacker.role_tags.has("hazard_setter") and BattleEngine.HAZARD_MAX_LAYERS.has(action.move_name):
		var max_layers: int = BattleEngine.HAZARD_MAX_LAYERS[action.move_name]
		var current: int = opp_team.hazards.get(action.move_name, 0)
		# Bug confirme : l'IA continuait de poser des pieges pendant que
		# l'adversaire s'auto-boostait tour apres tour (Danse Draco x3) sans
		# jamais etre inquiete -- alors qu'attaquer avec un STAB 4x efficace
		# etait disponible. Le plan de jeu perso ne doit pas primer sur le
		# besoin urgent de punir un sweeper deja en train de monter en stats.
		if current < max_layers and not _opponent_is_setting_up(opp_team.active()):
			bonus += 25.0 * profile.hazard_priority

	if attacker.role_tags.has("weather_setter") and RoleTagger.WEATHER_MOVES.has(action.move_name):
		var desired: String = RoleTagger.WEATHER_MOVES[action.move_name]
		if state.weather != desired:
			bonus += 22.0 * profile.weather_priority

	if attacker.role_tags.has("sweeper") and RoleTagger.BOOST_MOVES.has(action.move_name):
		var safe_window: bool = _worst_case_threat(opp_team.active(), attacker, state.weather) < 0.35
		if safe_window and attacker.hp_percent() > 0.6:
			bonus += 20.0 * profile.setup_priority

	if RoleTagger.CRIPPLE_STATUS_MOVES.has(action.move_name):
		var biggest_threat := _biggest_threat(opp_team, my_team)
		if biggest_threat == opp_team.active() and biggest_threat.status == "":
			bonus += 18.0 * profile.status_priority

	# Soin (Recover/Repos...) : utile si pas a pleine vie et pas en danger de
	# mourir ce tour-la (sinon se soigner "pour rien" avant de tomber au KO).
	if RoleTagger.RECOVERY_MOVES.has(action.move_name) and attacker.hp_percent() < 0.7:
		var lethal_incoming := _worst_case_threat(opp_team.active(), attacker, state.weather) >= 1.0
		if not lethal_incoming:
			bonus += 16.0 * (1.0 - attacker.hp_percent()) * profile.safety

	# Strategie FEAR (Focus Sash/Fermete + Effort + attaque prioritaire) : si
	# mes PV sont deja plus bas que ceux de l'adversaire (typiquement apres
	# avoir survecu a 1 PV), Effort le ramene a mes PV -- un enorme avantage
	# tactique qu'un score de degats "null" (power=null) ne refleterait pas.
	if RoleTagger.HP_EQUALIZE_MOVES.has(action.move_name) and attacker.current_hp < opp_team.active().current_hp:
		if GameData.type_effectiveness(move.get("type", "normal"), opp_team.active().types) > 0.0:
			bonus += 70.0
			# Bug confirme : le bonus "punir un sweeper deja boste" (attaquer
			# maintenant) s'appliquait aux attaques normales mais pas a Effort,
			# qui n'a pas de "power" et passe par cette branche a part -- ca
			# rognait progressivement l'avantage d'Effort face a un sweeper
			# boste alors que l'ecraser a 1 PV est encore PLUS precieux dans
			# ce cas (n'importe quel coup futur le tue), pas moins.
			var opp_boost_stages: int = max(0, opp_team.active().stat_stages.get("attack", 0)) + max(0, opp_team.active().stat_stages.get("special_attack", 0)) + max(0, opp_team.active().stat_stages.get("speed", 0))
			bonus += float(opp_boost_stages) * 8.0 * profile.aggression

	# Provoc : bloque un mur/poseur/support pas encore muselé, pour l'empecher
	# de se soigner, poser des pieges ou infliger un statut (cf. les strategies
	# "Taunt lead"/"Taunt fat" des guides stall).
	if action.move_name == "taunt" and opp_team.active().taunt_turns_left <= 0:
		var opp_active := opp_team.active()
		var is_support: bool = opp_active.role_tags.has("wall") or opp_active.role_tags.has("hazard_setter") or opp_active.role_tags.has("status_support")
		if is_support:
			bonus += 24.0 * profile.status_priority

	# Tour Rapide : utile des qu'il y a des pieges a retirer de son propre cote.
	if action.move_name == "rapid-spin" and not my_team.hazards.is_empty():
		bonus += 20.0 * my_team.hazards.size()

	# Gameplan (win condition) : si CE Pokemon n'est PAS la win condition
	# identifiee et que l'actif adverse est un obstacle a degager pour elle,
	# l'affaiblir avec ce coup fait progresser le plan -- meme si ce n'est
	# pas le meilleur coup "dans l'instant".
	var win_condition: BattlePokemon = plan.get("win_condition")
	if win_condition != null and attacker != win_condition and move.get("power"):
		var obstacles: Array = plan.get("obstacles", [])
		if obstacles.has(opp_team.active()):
			bonus += 12.0

	return bonus


## Identifie, parmi les Pokemon adverses vus jusqu'ici, celui qui menace le plus mon equipe.
static func _biggest_threat(opp_team: BattleTeam, my_team: BattleTeam) -> BattlePokemon:
	var worst_mon: BattlePokemon = opp_team.active()
	var worst_score := -1.0
	for mon: BattlePokemon in opp_team.alive_members():
		var threat := 0.0
		for my_mon: BattlePokemon in my_team.alive_members():
			threat = max(threat, _worst_case_threat(mon, my_mon))
		if threat > worst_score:
			worst_score = threat
			worst_mon = mon
	return worst_mon
