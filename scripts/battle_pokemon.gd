class_name BattlePokemon
extends RefCounted

# Instance de combat d'un Pokémon (espèce + niveau + moveset explicite).
# Stats effectives calculées avec la formule Gen 3, IV=0/EV=0/nature neutre
# fixés (simplification assumée : pas de vraie équipe joueur persistante
# pour l'instant, voir acte1-parc-safari.md — l'équipe de ce combat est
# prêtée par Yohan, éphémère). Facile à enrichir plus tard (IV/EV réels)
# une fois qu'une vraie notion d'équipe capturée existera.

var species_key := ""
var display_name := ""
var level := 1
var types: Array[String] = []
var gender := "none"   # "male" / "female" / "none" (espèces sans sexe, ex. Magnéti)

var max_hp := 0
var current_hp := 0
var attack := 0
var defense := 0
var sp_attack := 0
var sp_defense := 0
var speed := 0

var moves: Array[Dictionary] = []   # [{"key": String, "pp_current": int, "pp_max": int}]
var burned := false

# `gender` : sexe déjà tiré au sort (voir roll_gender()) et à réutiliser tel
# quel — laisser vide ("") retire le tirage à la volée ici (utile pour un
# appelant qui ne pré-tire pas). Le tirage doit se faire UNE SEULE fois par
# Pokémon envoyé et être transmis partout où ce même Pokémon est reconstruit
# (voir trainer_data.gd::roll_genders()) : battle_intro.gd construit son
# propre BattlePokemon juste pour l'affichage, trainer_battle.gd construit le
# sien pour de vrai — sans ce partage, un tirage aléatoire à chaque
# construction pourrait afficher 2 sexes différents pour le même Pokémon.
static func create(species_key: String, level: int, move_keys: Array[String], gender: String = "") -> BattlePokemon:
	var bp := BattlePokemon.new()
	bp.species_key = species_key
	var sp: Dictionary = SpeciesData.SPECIES[species_key]
	bp.display_name = String(sp["name"])
	bp.level = level

	var t: Array[String] = []
	for ty in sp["types"]:
		t.append(String(ty))
	bp.types = t
	bp.gender = gender if gender != "" else roll_gender(species_key)

	bp.max_hp = _stat(int(sp["base_hp"]), level, true)
	bp.current_hp = bp.max_hp
	bp.attack = _stat(int(sp["base_attack"]), level)
	bp.defense = _stat(int(sp["base_defense"]), level)
	bp.sp_attack = _stat(int(sp["base_sp_attack"]), level)
	bp.sp_defense = _stat(int(sp["base_sp_defense"]), level)
	bp.speed = _stat(int(sp["base_speed"]), level)

	var mv: Array[Dictionary] = []
	for key in move_keys:
		var pp: int = int(MoveData.MOVES[key]["pp"])
		mv.append({"key": key, "pp_current": pp, "pp_max": pp})
	bp.moves = mv

	return bp

# Vrai tirage aléatoire (pas déterministe), à partir de gender_ratio
# (species_data.gd, repris tel quel du jeu d'origine :
# "MON_MALE"/"MON_FEMALE"/"MON_GENDERLESS" ou "PERCENT_FEMALE(x)"). Le jeu
# d'origine dérive le sexe de la valeur de personnalité (fixée à la capture,
# donc "aléatoire" seulement une fois) — on simplifie avec randf() à chaque
# appel, mais l'appelant doit donc bien tirer une seule fois et transmettre
# le résultat (voir create()), pas rappeler cette fonction à chaque
# reconstruction du même Pokémon.
static func roll_gender(species_key: String) -> String:
	var sp: Dictionary = SpeciesData.SPECIES[species_key]
	var ratio: String = String(sp.get("gender_ratio", "MON_GENDERLESS"))
	if ratio == "MON_GENDERLESS":
		return "none"
	if ratio == "MON_MALE":
		return "male"
	if ratio == "MON_FEMALE":
		return "female"
	var regex := RegEx.new()
	regex.compile("PERCENT_FEMALE\\(([0-9.]+)\\)")
	var result := regex.search(ratio)
	var female_percent: float = float(result.get_string(1)) if result else 50.0
	return "female" if randf() * 100.0 < female_percent else "male"

# Formule Gen 3 (IV=0, EV=0, nature neutre) : stat = floor(2*base*level/100) + 5,
# ou +level+10 pour les PV.
static func _stat(base: int, level: int, is_hp: bool = false) -> int:
	var v: int = (2 * base * level) / 100
	if is_hp:
		return v + level + 10
	return v + 5

func is_fainted() -> bool:
	return current_hp <= 0

func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
