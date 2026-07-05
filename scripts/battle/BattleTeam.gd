class_name BattleTeam
extends RefCounted
## Une equipe engagee dans un combat (format singles : 1 actif a la fois).

var trainer_name: String = ""
var members: Array = []      ## Array[BattlePokemon]
var active_index: int = 0

## Ce que ce camp a "revele" a l'adversaire au fil du combat (pas de triche :
## l'IA adverse ne doit lire QUE ce qui est stocke ici).
var revealed_moves: Dictionary = {}  ## species_name -> Array[String] moves deja utilises
var hazards: Dictionary = {}          ## "stealth_rock": true, "spikes": 0..3, ...
var pivot_pending: bool = false       ## Change Eclair/Demi-Tour a touche : switch a choisir, actif pas KO


func active() -> BattlePokemon:
	return members[active_index]


func is_defeated() -> bool:
	for m: BattlePokemon in members:
		if not m.is_fainted():
			return false
	return true


func alive_members() -> Array:
	return members.filter(func(m: BattlePokemon) -> bool: return not m.is_fainted())


func reveal_move(species_name: String, move_name: String) -> void:
	if not revealed_moves.has(species_name):
		revealed_moves[species_name] = []
	var arr: Array = revealed_moves[species_name]
	if not arr.has(move_name):
		arr.append(move_name)


func switch_active(index: int) -> void:
	active_index = index
