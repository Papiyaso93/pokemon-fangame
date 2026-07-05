class_name BattleAction
extends RefCounted
## Decrit une action choisie par un camp pour le tour en cours.

enum Kind { MOVE, SWITCH }

var kind: int
var move_name: String = ""
var switch_index: int = -1


static func move(name: String) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.MOVE
	a.move_name = name
	return a


static func switch_to(index: int) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.SWITCH
	a.switch_index = index
	return a
