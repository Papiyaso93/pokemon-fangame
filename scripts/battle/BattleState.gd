class_name BattleState
extends RefCounted
## Etat complet d'un combat en cours.

var team_a: BattleTeam
var team_b: BattleTeam
var turn_number: int = 0
var log: Array = []           ## Array[String] historique lisible du combat
## Array[Dictionary] : snapshot de l'etat visuel au moment de chaque ligne de log
## (meme index que `log`), pour permettre a l'UI de rejouer message par message
## avec les barres de vie/sprites synchronises, plutot que tout afficher d'un coup.
var log_snapshots: Array = []
var is_over: bool = false
var winner: BattleTeam = null

var weather: String = ""            ## "", "rain", "sun", "sandstorm", "hail"
var weather_turns_left: int = 0     ## -1 = duree indefinie (posee par talent)


func other_team(team: BattleTeam) -> BattleTeam:
	return team_b if team == team_a else team_a


## `meta` : cles optionnelles fusionnees dans le snapshot de cette ligne
## (ex: "anim"/"anim_target"/"anim_move_type") pour piloter les animations
## generiques cote UI sans coupler le moteur de combat a l'affichage.
func add_log(line: String, meta: Dictionary = {}) -> void:
	log.append(line)
	var snap := _snapshot()
	for key: String in meta:
		snap[key] = meta[key]
	log_snapshots.append(snap)


func _snapshot() -> Dictionary:
	var a := team_a.active()
	var b := team_b.active()
	return {
		"a_species": a.species_name, "a_level": a.level, "a_hp": a.current_hp, "a_max_hp": a.max_hp,
		"a_status": a.status, "a_fainted": a.is_fainted(), "a_stat_stages": a.stat_stages.duplicate(),
		"b_species": b.species_name, "b_level": b.level, "b_hp": b.current_hp, "b_max_hp": b.max_hp,
		"b_status": b.status, "b_fainted": b.is_fainted(), "b_stat_stages": b.stat_stages.duplicate(),
		"weather": weather, "weather_turns_left": weather_turns_left,
		"a_hazards": team_a.hazards.duplicate(), "b_hazards": team_b.hazards.duplicate(),
	}


func check_end() -> void:
	if team_a.is_defeated():
		is_over = true
		winner = team_b
	elif team_b.is_defeated():
		is_over = true
		winner = team_a
