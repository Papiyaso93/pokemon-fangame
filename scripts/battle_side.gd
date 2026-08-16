class_name BattleSide
extends RefCounted

# Un camp de combat (joueur ou dresseur adverse) : une équipe de BattlePokemon
# + l'index de celui actif. Volontairement symétrique/générique pour rester
# réutilisable plus tard avec une vraie équipe persistante du joueur et avec
# le format duo (zone 4, hors scope de ce lot).

var party: Array[BattlePokemon] = []
var active_index := 0
var is_player := false
var trainer_name := ""

func active() -> BattlePokemon:
	return party[active_index]

func has_alive() -> bool:
	for p in party:
		if not p.is_fainted():
			return true
	return false

# Index du prochain Pokémon vivant (pour un switch automatique côté IA après
# K.O.), -1 si toute l'équipe est K.O.
func next_alive_index() -> int:
	for i in range(party.size()):
		if not party[i].is_fainted():
			return i
	return -1
