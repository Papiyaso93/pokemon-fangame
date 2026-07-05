class_name GamePlan
extends RefCounted
## Couche strategique "long terme" (equivalent de la notion de win condition
## et de gameplan des guides competitifs) : identifie, a partir de l'etat
## ACTUEL du combat, quel Pokemon de l'equipe a le meilleur potentiel pour
## nettoyer le reste de l'equipe adverse, et quels Pokemon adverses s'y
## opposent (des "obstacles" a degager avant de le lancer).
##
## Volontairement PAS un plan fige ni une simulation complete du futur (arbre
## de jeu façon minimax, hors de portee ici) : build() est appele a CHAQUE
## tour depuis l'etat courant, donc si la win condition tombe K.O., si un
## obstacle meurt autrement ou qu'une nouvelle menace apparait, le plan
## s'ajuste tout seul au tour suivant sans etat a maintenir entre les tours.


## Renvoie {"win_condition": BattlePokemon|null, "obstacles": Array[BattlePokemon]}.
static func build(my_team: BattleTeam, opp_team: BattleTeam) -> Dictionary:
	var win_condition := identify_win_condition(my_team, opp_team)
	var obstacles := identify_obstacles(win_condition, opp_team)
	return {"win_condition": win_condition, "obstacles": obstacles}


## Le Pokemon vivant qui bat le plus grand nombre de membres adverses encore
## en vie (1v1, dans les deux sens : je le tue et il ne me tue pas), avec un
## bonus pour les sweepers deja en position de setup et pour sa vie actuelle
## (une win condition a moitie morte est moins fiable).
static func identify_win_condition(my_team: BattleTeam, opp_team: BattleTeam) -> BattlePokemon:
	var alive: Array = my_team.alive_members()
	if alive.is_empty():
		return null

	var best: BattlePokemon = alive[0]
	var best_score := -INF
	for mon: BattlePokemon in alive:
		var score := _win_condition_score(mon, opp_team)
		if score > best_score:
			best_score = score
			best = mon
	return best


static func _win_condition_score(mon: BattlePokemon, opp_team: BattleTeam) -> float:
	var opp_alive: Array = opp_team.alive_members()
	if opp_alive.is_empty():
		return 0.0

	var beats := 0
	for opp_mon: BattlePokemon in opp_alive:
		var i_beat_it: bool = BattleAI._worst_case_threat(mon, opp_mon, "") >= 1.0
		var it_beats_me: bool = BattleAI._worst_case_threat(opp_mon, mon, "") >= 1.0
		if i_beat_it and not it_beats_me:
			beats += 1

	var coverage: float = float(beats) / float(opp_alive.size())
	var sweeper_bonus := 15.0 if mon.role_tags.has("sweeper") else 0.0
	return coverage * 100.0 + sweeper_bonus + mon.hp_percent() * 10.0


## Membres adverses encore en vie que la win condition ne bat PAS (menace
## reelle ou simple wall) : ce sont les cibles a affaiblir/degager en
## priorite par le reste de l'equipe avant de lancer la win condition.
static func identify_obstacles(win_condition: BattlePokemon, opp_team: BattleTeam) -> Array:
	var obstacles: Array = []
	if win_condition == null:
		return obstacles
	for opp_mon: BattlePokemon in opp_team.alive_members():
		if BattleAI._worst_case_threat(win_condition, opp_mon, "") < 1.0:
			obstacles.append(opp_mon)
	return obstacles
