class_name SafariRoster
extends RefCounted

# Roster de la Zone Safari (décision de Gus, 09/07/2026) : tous les Pokémon
# "de base" (pas le résultat d'une évolution) de la 1ère génération, sauf les
# 5 légendaires/mythiques — cohérent avec l'histoire modifiée du jeu qui fait
# commencer le joueur ici. Volontairement pas de canne à pêche/Surf pour
# l'instant (viendront plus tard dans l'histoire) donc les espèces
# habituellement "eau uniquement" sont quand même incluses ici en attendant.
# Pas de répartition par sous-zone pour l'instant (décision de Gus : toutes
# les zones ont le même roster en attendant qu'on tranche la répartition).
#
# Calculé depuis SpeciesData plutôt qu'une liste figée à la main : reste
# juste si species_data.gd est régénéré (nouvelle évolution ajoutée, etc.).

const LEGENDARY_KEYS := ["articuno", "zapdos", "moltres", "mewtwo", "mew"]

static func base_species() -> Array[String]:
	var evolution_targets := {}
	for key in SpeciesData.SPECIES:
		for evo in SpeciesData.SPECIES[key]["evolutions"]:
			evolution_targets[String(evo["target"]).to_lower()] = true
	var result: Array[String] = []
	for key in SpeciesData.SPECIES:
		if not evolution_targets.has(key) and key not in LEGENDARY_KEYS:
			result.append(key)
	return result
