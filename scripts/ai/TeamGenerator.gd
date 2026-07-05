class_name TeamGenerator
extends RefCounted
## Genere une equipe CPU (ou joueur) automatiquement, a partir des stats de
## base et des sets recommandes (Smogon). C'est une approximation heuristique
## du "quels Pokemon vont avec quelle strat" -- pas une reproduction exacte
## des stats d'usage competitives (ca demanderait les donnees de
## co-occurrence d'equipe, hors de portee ici).
## Respecte les criteres de format (tier, Gen1 uniquement, pas d'evolution),
## garde les slots deja remplis par l'utilisateur intacts, et peut forcer un
## role precis sur un slot donne (le reste se complete pour la synergie :
## diversite de types + evitement des roles deja couverts).

const TYPE_OVERLAP_PENALTY := 10.0
const SHORTLIST_SIZE := 40
const ROLE_SHORTLIST_SIZE := 12

const WEATHER_SETTER_BY_PROFILE := {
	"rain": "drizzle", "sand": "sand-stream", "sun": "drought", "hail": "snow-warning",
}
const WEATHER_MOVE_BY_PROFILE := {
	"rain": "rain-dance", "sand": "sandstorm", "sun": "sunny-day", "hail": "hail",
}
const WEATHER_ABUSER_BY_PROFILE := {
	"rain": "swift-swim", "sand": "sand-rush", "sun": "chlorophyll", "hail": "slush-rush",
}

## Roles assignables a un slot precis (en plus de "auto", qui suit l'archetype d'equipe).
const ROLE_OPTIONS := [
	"auto", "sweeper", "wall", "hazard_setter", "status_support",
	"rain_setter", "sand_setter", "sun_setter", "hail_setter",
	"trapper", "spinner",
]
const ROLE_LABELS_FR := [
	"Auto (complete la synergie)", "Sweeper", "Mur (Wall)", "Poseur de pieges",
	"Support statut", "Setter Pluie", "Setter Sable", "Setter Soleil", "Setter Grele",
	"Trappeur (Poursuite)", "Spinner (Tour Rapide)",
]


## criteria (optionnel) : {"tier": String, "gen1_only": bool, "no_evolution": bool}
static func generate_team(profile_name: String, size: int, criteria: Dictionary = {}) -> Array:
	var empty_roster: Array = []
	var roles: Array = []
	for i in range(size):
		empty_roster.append({})
		roles.append("auto")
	return generate_slots(empty_roster, roles, profile_name, criteria)


## roster : Array de meme taille que roles. Une entree non-vide ({"species":...})
## est un PICK FIXE de l'utilisateur : conserve tel quel. Une entree vide ({})
## est generee. roles[i] force un role precis pour le slot i (ignore si le
## slot est deja fixe) ; "auto" suit l'archetype global (profile_name).
## max_new >= 0 limite le nombre de NOUVEAUX Pokemon generes (les slots vides
## au-dela restent vides) ; -1 = pas de limite (remplit tous les slots vides).
## type_filters (optionnel) : Array de meme taille que roles, "" = pas de
## contrainte, sinon force ce type pour le slot correspondant.
static func generate_slots(roster: Array, roles: Array, profile_name: String, criteria: Dictionary = {}, max_new: int = -1, type_filters: Array = []) -> Array:
	var species_pool := _filter_pool(GameData.get_all_species_names(), criteria)

	var used_species: Dictionary = {}
	var used_types: Dictionary = {}
	var roles_present: Dictionary = {}
	for entry: Dictionary in roster:
		if entry.is_empty():
			continue
		used_species[entry["species"]] = true
		for t: String in GameData.get_pokemon(entry["species"]).get("types", []):
			used_types[t] = used_types.get(t, 0) + 1
		for role: String in _infer_roles(entry["species"], entry.get("moves", [])):
			roles_present[role] = true

	var result: Array = roster.duplicate(true)
	var generated := 0

	for i in range(result.size()):
		if not result[i].is_empty():
			continue
		if max_new >= 0 and generated >= max_new:
			continue

		var slot_role: String = roles[i] if i < roles.size() else "auto"
		var slot_type: String = type_filters[i] if i < type_filters.size() else ""
		var species := _pick_species_for_slot(species_pool, used_species, used_types, roles_present, slot_role, profile_name, slot_type)
		if species == "":
			continue
		generated += 1

		used_species[species] = true
		for t: String in GameData.get_pokemon(species).get("types", []):
			used_types[t] = used_types.get(t, 0) + 1

		var moves := GameData.get_recommended_moves(species)
		if moves.size() < 2:
			moves = GameData.get_movepool(species).slice(0, 4)
		for role: String in _infer_roles(species, moves):
			roles_present[role] = true

		var ability := _pick_ability_for_species(species, profile_name, slot_role)
		result[i] = {"species": species, "level": 50, "moves": moves, "ability": ability}

	return result


static func _pick_species_for_slot(species_pool: Array, used_species: Dictionary, used_types: Dictionary, roles_present: Dictionary, slot_role: String, profile_name: String, slot_type: String = "") -> String:
	var candidates: Array = species_pool.filter(func(s: String) -> bool:
		if used_species.has(s):
			return false
		if slot_type != "" and not GameData.get_pokemon(s).get("types", []).has(slot_type):
			return false
		return true
	)
	if candidates.is_empty():
		return ""

	var scored: Array = []
	for species: String in candidates:
		var data := GameData.get_pokemon(species)
		var score: float
		if slot_role == "auto":
			score = _fit_score(data, species, profile_name)
			# Complementarite : penalise legerement un role deja bien couvert par l'equipe,
			# pour eviter par exemple 3 poseurs de pieges et aucun mur.
			for role: String in _infer_roles(species, GameData.get_recommended_moves(species)):
				if roles_present.has(role):
					score -= 12.0
		else:
			score = _role_fit_score(data, species, slot_role)
		scored.append({"species": species, "score": score})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])

	var pool_size: int = ROLE_SHORTLIST_SIZE if slot_role != "auto" else SHORTLIST_SIZE
	var shortlist: Array = scored.slice(0, min(pool_size, scored.size()))

	var best_idx := -1
	var best_adjusted := -INF
	for i in range(shortlist.size()):
		var entry: Dictionary = shortlist[i]
		var species_data := GameData.get_pokemon(entry["species"])
		var penalty := 0.0
		for t: String in species_data.get("types", []):
			penalty += float(used_types.get(t, 0)) * TYPE_OVERLAP_PENALTY
		var adjusted: float = entry["score"] - penalty
		if adjusted > best_adjusted:
			best_adjusted = adjusted
			best_idx = i

	# Un peu d'alea parmi les tout meilleurs pour ne pas toujours proposer
	# exactement la meme equipe a criteres egaux.
	if shortlist.size() > 1 and randf() < 0.5:
		var alt_idx: int = randi_range(0, min(2, shortlist.size() - 1))
		return shortlist[alt_idx]["species"]

	return shortlist[best_idx]["species"] if best_idx >= 0 else ""


## Deduit les roles strategiques d'une espece a partir d'un moveset donne
## (utilise en generation, avant qu'un BattlePokemon existe -- cf RoleTagger
## pour l'equivalent en combat une fois l'instance creee).
static func _infer_roles(species: String, moves: Array) -> Array:
	var roles: Array = []
	var abilities := GameData.get_species_abilities(species)

	if moves.any(func(m: String) -> bool: return RoleTagger.HAZARD_MOVES.has(m)):
		roles.append("hazard_setter")
	if moves.any(func(m: String) -> bool: return RoleTagger.BOOST_MOVES.has(m)):
		roles.append("sweeper")
	if moves.any(func(m: String) -> bool: return RoleTagger.RECOVERY_MOVES.has(m)):
		roles.append("wall")
	if moves.any(func(m: String) -> bool: return RoleTagger.CRIPPLE_STATUS_MOVES.has(m)):
		roles.append("status_support")
	if moves.has("pursuit"):
		roles.append("trapper")
	if moves.has("rapid-spin"):
		roles.append("spinner")
	for profile: String in WEATHER_SETTER_BY_PROFILE:
		if abilities.has(WEATHER_SETTER_BY_PROFILE[profile]) or moves.has(WEATHER_MOVE_BY_PROFILE[profile]):
			roles.append(profile + "_setter")
	return roles


## Choisit le talent a assigner : priorise celui qui justifie la selection
## (ex: Neige Poudreuse pour un slot/archetype "grele") plutot que toujours le
## premier de la liste, qui peut etre un talent purement cosmetique (bug
## confirme : Feunard d'Alola a ["snow-cloak", "snow-warning"], et prendre
## bêtement l'index 0 donnait Cape Neige a la place du vrai setter de grele).
static func _pick_ability_for_species(species: String, profile_name: String, slot_role: String) -> String:
	var abilities := GameData.get_species_abilities(species)
	if abilities.is_empty():
		return ""

	var preferred: Array = []
	if WEATHER_SETTER_BY_PROFILE.has(profile_name):
		preferred.append(WEATHER_SETTER_BY_PROFILE[profile_name])
	var role_weather: String = slot_role.replace("_setter", "")
	if WEATHER_SETTER_BY_PROFILE.has(role_weather):
		preferred.append(WEATHER_SETTER_BY_PROFILE[role_weather])

	for p: String in preferred:
		if abilities.has(p):
			return p
	return abilities[0]


static func _filter_pool(species_pool: Array, criteria: Dictionary) -> Array:
	var tier: String = criteria.get("tier", "")
	var gen1_only: bool = criteria.get("gen1_only", false)
	var no_evolution: bool = criteria.get("no_evolution", false)

	return species_pool.filter(func(slug: String) -> bool:
		if not GameData.is_species_allowed(slug):
			return false
		if not GameData.tier_matches_filter(GameData.get_tier(slug), tier):
			return false
		if gen1_only and not GameData.is_gen1(slug):
			return false
		if no_evolution and GameData.has_pre_evolution(slug):
			return false
		return true
	)


static func _fit_score(data: Dictionary, species: String, profile_name: String) -> float:
	var stats: Dictionary = data.get("base_stats", {})
	var hp: float = stats.get("hp", 0)
	var atk: float = stats.get("attack", 0)
	var defe: float = stats.get("defense", 0)
	var spa: float = stats.get("special_attack", 0)
	var spd: float = stats.get("special_defense", 0)
	var spe: float = stats.get("speed", 0)

	var bulk := hp + defe + spd
	var offense: float = max(atk, spa)

	var recommended := GameData.get_recommended_moves(species)
	var has_recovery := recommended.any(func(m: String) -> bool: return RoleTagger.RECOVERY_MOVES.has(m))
	var has_boost := recommended.any(func(m: String) -> bool: return RoleTagger.BOOST_MOVES.has(m))
	var abilities := GameData.get_species_abilities(species)

	if WEATHER_SETTER_BY_PROFILE.has(profile_name):
		var setter_ability: String = WEATHER_SETTER_BY_PROFILE[profile_name]
		var setter_move: String = WEATHER_MOVE_BY_PROFILE[profile_name]
		var abuser_ability: String = WEATHER_ABUSER_BY_PROFILE[profile_name]
		var is_setter := abilities.has(setter_ability) or recommended.has(setter_move)
		var is_abuser := abilities.has(abuser_ability)
		return (160.0 if is_setter else 0.0) + (70.0 if is_abuser else 0.0) + offense * 0.5 + spe * 0.4

	match profile_name:
		"hyper_offense":
			return offense * 1.5 + spe * 1.3 + (35.0 if has_boost else 0.0)
		"stall":
			return bulk * 1.4 + (45.0 if has_recovery else 0.0) - spe * 0.3
		_:
			return bulk * 0.7 + offense * 0.7 + spe * 0.5


## Score de pertinence d'une espece pour un role PRECIS demande sur un slot
## (independant de l'archetype global de l'equipe).
static func _role_fit_score(data: Dictionary, species: String, role: String) -> float:
	var stats: Dictionary = data.get("base_stats", {})
	var hp: float = stats.get("hp", 0)
	var atk: float = stats.get("attack", 0)
	var defe: float = stats.get("defense", 0)
	var spa: float = stats.get("special_attack", 0)
	var spd: float = stats.get("special_defense", 0)
	var spe: float = stats.get("speed", 0)
	var bulk := hp + defe + spd
	var offense: float = max(atk, spa)

	var recommended := GameData.get_recommended_moves(species)
	var abilities := GameData.get_species_abilities(species)

	match role:
		"sweeper":
			var has_boost := recommended.any(func(m: String) -> bool: return RoleTagger.BOOST_MOVES.has(m))
			return offense * 1.6 + spe * 1.5 + (200.0 if has_boost else 0.0)
		"wall":
			var has_recovery := recommended.any(func(m: String) -> bool: return RoleTagger.RECOVERY_MOVES.has(m))
			return bulk * 1.8 + (200.0 if has_recovery else 0.0) - spe * 0.2
		"hazard_setter":
			var has_hazard := recommended.any(func(m: String) -> bool: return RoleTagger.HAZARD_MOVES.has(m))
			return (300.0 if has_hazard else 0.0) + bulk * 0.3
		"status_support":
			var has_cripple := recommended.any(func(m: String) -> bool: return RoleTagger.CRIPPLE_STATUS_MOVES.has(m))
			return (300.0 if has_cripple else 0.0) + bulk * 0.4
		"rain_setter", "sand_setter", "sun_setter", "hail_setter":
			var weather: String = role.replace("_setter", "")
			var setter_ability: String = WEATHER_SETTER_BY_PROFILE.get(weather, "")
			var setter_move: String = WEATHER_MOVE_BY_PROFILE.get(weather, "")
			var is_setter := abilities.has(setter_ability) or recommended.has(setter_move)
			return (400.0 if is_setter else 0.0) + offense * 0.3 + spe * 0.2
		"trapper":
			# Piege les menaces qui switchent (Poursuite) : bon bulk pour encaisser
			# en attendant l'occasion, l'offense importe moins que la fiabilite.
			var has_pursuit := recommended.has("pursuit")
			return (300.0 if has_pursuit else 0.0) + bulk * 0.5 + offense * 0.3
		"spinner":
			# Degage les pieges du terrain (Tour Rapide) : bulk avant tout pour
			# survivre assez de tours et pivoter librement (cf. stalls "avec spin").
			var has_spin := recommended.has("rapid-spin")
			return (300.0 if has_spin else 0.0) + bulk * 0.6
		_:
			return bulk * 0.7 + offense * 0.7 + spe * 0.5
