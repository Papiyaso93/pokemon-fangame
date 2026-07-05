class_name BattlePokemon
extends RefCounted
## Instance d'un Pokemon dans un combat en cours (etat mutable).
## Separe des donnees statiques (especes) qui restent dans GameData.

var species_name: String
var level: int
var types: Array = []
var moves: Array = []          ## Array[String] noms des 4 attaques choisies
var pp_left: Dictionary = {}   ## move_name -> pp restants

## Librement assignable : ne se limite pas au pool "canonique" de l'espece,
## pour permettre le homebrew d'equilibrage (ex: donner Sable Stream a Onix).
var ability: String = ""
var flash_fire_active: bool = false

## Objet tenu, librement assignable comme le talent (voir ItemEngine).
var held_item: String = ""
var item_consumed: bool = false  ## Objets a usage unique (Focus Sash) deja declenches

var max_hp: int
var current_hp: int
var stats: Dictionary = {}     ## attack, defense, special_attack, special_defense, speed

var status: String = ""        ## "", "burn", "poison", "toxic", "paralysis", "sleep", "freeze"
var toxic_counter: int = 0
var sleep_turns_left: int = 0
var must_recharge: bool = false  ## Hyper Beam et attaques similaires : bloque le prochain tour
var is_protected: bool = false   ## Abri/Detection actif ce tour (reinitialise a chaque tour)
var taunt_turns_left: int = 0    ## Provoc actif : ne peut pas utiliser d'attaque de statut
var protect_streak: int = 0      ## Usages consecutifs d'Abri/Detection (fait chuter le taux de succes)
var is_flinched: bool = false    ## Apeure ce tour (reinitialise a chaque tour, consomme par _can_act)
var cursed: bool = false         ## Malediction (variante Spectre) : perd 1/4 PV max en fin de tour
var focus_energy_active: bool = false  ## Puissance (Focus Energy) : +2 crans de critique
var charging_move: String = ""   ## Lance-Soleil/Lame Solaire en cours de charge (vide = aucune)
var substitute_hp: int = 0       ## PV du Clonage actif (0 = aucun clone)
var partial_trap_turns_left: int = 0  ## Ligotage/Etreinte... : ne peut plus switcher, subit des degats chaque tour
var partial_trap_damage: int = 0      ## Degats fixes par tour du piege partiel (calcules a la pose)
var partial_trap_source: BattlePokemon = null  ## Le pokemon qui a pose le piege (s'il quitte le terrain, le piege se leve)

## Stages de boost (-6 a +6). accuracy/evasion utilisent une echelle a part
## (voir BattleEngine._accuracy_multiplier), pas effective_stat().
var stat_stages: Dictionary = {
	"attack": 0, "defense": 0, "special_attack": 0, "special_defense": 0, "speed": 0,
	"accuracy": 0, "evasion": 0,
}

var role_tags: Array = []      ## ex: ["sweeper", "hazard_setter"]


static func create(species_name: String, level: int, move_names: Array, ability_override: String = "", ivs: int = 31, evs: int = 0, held_item: String = "") -> BattlePokemon:
	var mon := BattlePokemon.new()
	var species := GameData.get_pokemon(species_name)
	if species.is_empty():
		push_error("BattlePokemon: espece inconnue '%s'" % species_name)
		return mon

	mon.species_name = species_name
	mon.level = level
	mon.types = species["types"].duplicate()
	mon.moves = move_names.duplicate()
	mon.held_item = held_item

	if ability_override != "":
		mon.ability = ability_override
	else:
		var abilities: Array = species.get("abilities", [])
		mon.ability = abilities[0]["name"] if not abilities.is_empty() else ""

	for m: String in move_names:
		var move_data := GameData.get_move(m)
		mon.pp_left[m] = move_data.get("pp", 0)

	var base: Dictionary = species["base_stats"]
	mon.max_hp = _calc_hp(base["hp"], level, ivs, evs)
	mon.current_hp = mon.max_hp
	mon.stats = {
		"attack": _calc_stat(base["attack"], level, ivs, evs),
		"defense": _calc_stat(base["defense"], level, ivs, evs),
		"special_attack": _calc_stat(base["special_attack"], level, ivs, evs),
		"special_defense": _calc_stat(base["special_defense"], level, ivs, evs),
		"speed": _calc_stat(base["speed"], level, ivs, evs),
	}
	return mon


static func _calc_hp(base: int, level: int, iv: int, ev: int) -> int:
	return int(floor(float((2 * base + iv + int(floor(ev / 4.0))) * level) / 100.0)) + level + 10


static func _calc_stat(base: int, level: int, iv: int, ev: int) -> int:
	return int(floor(float((2 * base + iv + int(floor(ev / 4.0))) * level) / 100.0)) + 5


## Stat effective (apres stage de boost + malus de statut pour la vitesse/attaque).
func effective_stat(stat_name: String) -> int:
	var base_value: int = stats.get(stat_name, 0)
	var stage: int = stat_stages.get(stat_name, 0)
	var multiplier := _stage_multiplier(stage)
	var value := base_value * multiplier

	if stat_name == "speed" and status == "paralysis":
		value *= 0.25
	if stat_name == "attack" and status == "burn":
		value *= 0.5

	return max(1, int(floor(value)))


static func _stage_multiplier(stage: int) -> float:
	stage = clampi(stage, -6, 6)
	if stage >= 0:
		return (2.0 + stage) / 2.0
	return 2.0 / (2.0 - stage)


func is_fainted() -> bool:
	return current_hp <= 0


func hp_percent() -> float:
	return float(current_hp) / float(max_hp)


## Renvoie les PV reellement perdus (plafonnes a ce qu'il restait), pour que
## les messages de log affichent la perte reelle plutot que les degats bruts
## theoriques quand un coup depasse les PV restants (bug confirme : "perd 458
## PV" affiche sur un coup qui achevait un Pokemon avec beaucoup moins de PV).
func apply_damage(amount: int) -> int:
	var before := current_hp
	current_hp = clampi(current_hp - amount, 0, max_hp)
	return before - current_hp


func heal(amount: int) -> void:
	current_hp = clampi(current_hp + amount, 0, max_hp)


## Tout ce qui est "volatile" (lie a CE passage sur le terrain) s'efface au
## switch, que ce soit volontaire ou force par un KO -- bug confirme : les
## stages de stats (buffs/malus) persistaient d'un passage sur le terrain a
## l'autre au lieu d'etre remis a zero comme dans les jeux officiels.
func reset_on_switch_out() -> void:
	for key: String in stat_stages.keys():
		stat_stages[key] = 0
	flash_fire_active = false
	focus_energy_active = false
	protect_streak = 0
	if status == "toxic":
		toxic_counter = 0
	must_recharge = false
	taunt_turns_left = 0
	cursed = false
	charging_move = ""
	substitute_hp = 0
	partial_trap_turns_left = 0
	partial_trap_damage = 0
	partial_trap_source = null


func has_usable_move() -> bool:
	for m: String in moves:
		if pp_left.get(m, 0) > 0:
			return true
	return false
