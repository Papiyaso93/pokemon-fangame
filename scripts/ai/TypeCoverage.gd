class_name TypeCoverage
extends RefCounted
## Calcule la couverture de types d'une equipe (roster de team builder, pas
## un BattleTeam) : faiblesses defensives partagees et types non couverts
## offensivement par le moveset selectionne.

const ALL_TYPES := [
	"normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison",
	"ground", "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy",
]


## Renvoie {"weak_count": {type: int}, "resist_count": {type: int}, "offense_covered": {type: bool}}
static func analyze(roster: Array) -> Dictionary:
	var weak_count := {}
	var resist_count := {}
	var offense_covered := {}
	for t: String in ALL_TYPES:
		weak_count[t] = 0
		resist_count[t] = 0
		offense_covered[t] = false

	var move_types_used: Dictionary = {}

	for entry: Dictionary in roster:
		if entry.is_empty():
			continue
		var species_data := GameData.get_pokemon(entry.get("species", ""))
		var types: Array = species_data.get("types", [])
		for t: String in ALL_TYPES:
			var eff := GameData.type_effectiveness(t, types)
			if eff > 1.0:
				weak_count[t] += 1
			elif eff < 1.0:
				resist_count[t] += 1

		for m: String in entry.get("moves", []):
			var move_data := GameData.get_move(m)
			if not move_data.is_empty() and move_data.get("power"):
				move_types_used[move_data["type"]] = true

	for move_type: String in move_types_used:
		for t: String in ALL_TYPES:
			if GameData.type_effectiveness(move_type, [t]) > 1.0:
				offense_covered[t] = true

	return {"weak_count": weak_count, "resist_count": resist_count, "offense_covered": offense_covered}


## Formate l'analyse en texte lisible (francais).
static func format_report(analysis: Dictionary) -> String:
	var weak_count: Dictionary = analysis["weak_count"]
	var offense_covered: Dictionary = analysis["offense_covered"]

	var weak_types: Array = ALL_TYPES.filter(func(t: String) -> bool: return weak_count[t] >= 2)
	weak_types.sort_custom(func(a: String, b: String) -> bool: return weak_count[a] > weak_count[b])

	var uncovered: Array = ALL_TYPES.filter(func(t: String) -> bool: return not offense_covered[t])

	var lines: Array = []
	lines.append("[b]Trous defensifs[/b] (2+ Pokemon faibles au meme type) :")
	if weak_types.is_empty():
		lines.append("  Aucun -- bonne repartition des faiblesses.")
	else:
		for t: String in weak_types:
			lines.append("  %s : %d Pokemon faibles" % [GameData.fr_type(t), weak_count[t]])

	lines.append("")
	lines.append("[b]Types non couverts offensivement[/b] (aucune attaque super efficace) :")
	if uncovered.is_empty():
		lines.append("  Aucun -- couverture offensive complete.")
	else:
		var fr_list: Array = uncovered.map(func(t: String) -> String: return GameData.fr_type(t))
		lines.append("  " + ", ".join(fr_list))

	return "\n".join(lines)
