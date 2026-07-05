class_name ItemEngine
extends RefCounted
## Moteur d'objets tenus : large sous-ensemble des objets les plus utilises
## en competitif (pas les ~2000 objets du jeu complet). Les objets a "verrou"
## (Choix) n'imposent PAS le verrouillage sur une seule attaque ici
## (demanderait un suivi d'etat de tour supplementaire) : seul le boost de
## stat est applique -- simplification assumee, pas un bug.

## Chaque objet de type booste les degats des attaques de ce type de 20%.
const TYPE_BOOST_ITEMS := {
	"charcoal": "fire", "mystic-water": "water", "miracle-seed": "grass",
	"magnet": "electric", "never-melt-ice": "ice", "black-belt": "fighting",
	"poison-barb": "poison", "soft-sand": "ground", "sharp-beak": "flying",
	"twisted-spoon": "psychic", "silver-powder": "bug", "hard-stone": "rock",
	"spell-tag": "ghost", "dragon-fang": "dragon", "black-glasses": "dark",
	"metal-coat": "steel", "silk-scarf": "normal",
}

## Chaque Roche etend de 3 tours (5 -> 8) la duree de la meteo correspondante.
const WEATHER_ROCK_ITEMS := {
	"heat-rock": "sun", "damp-rock": "rain", "smooth-rock": "sandstorm", "icy-rock": "hail",
}

## GDScript n'autorise pas d'appel de methode (.keys()) dans une expression
## const : la liste des objets de type est donc dupliquee ici explicitement
## (memes cles que TYPE_BOOST_ITEMS ci-dessus).
const ITEMS := [
	"leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb",
	"focus-sash", "assault-vest", "black-sludge", "heavy-duty-boots",
	"eviolite", "scope-lens", "razor-claw", "expert-belt", "muscle-band",
	"wise-glasses", "shell-bell", "big-root", "sitrus-berry", "lum-berry",
	"charcoal", "mystic-water", "miracle-seed", "magnet", "never-melt-ice",
	"black-belt", "poison-barb", "soft-sand", "sharp-beak", "twisted-spoon",
	"silver-powder", "hard-stone", "spell-tag", "dragon-fang", "black-glasses",
	"metal-coat", "silk-scarf",
	"heat-rock", "damp-rock", "smooth-rock", "icy-rock",
]

const ITEM_DESCRIPTIONS_FR := {
	"leftovers": "Recupere 1/16 des PV max en fin de tour.",
	"choice-band": "Attaque x1.5 (le verrouillage sur une seule attaque n'est pas simule).",
	"choice-specs": "Attaque Speciale x1.5 (le verrouillage sur une seule attaque n'est pas simule).",
	"choice-scarf": "Vitesse x1.5 (le verrouillage sur une seule attaque n'est pas simule).",
	"life-orb": "Degats infliges x1.3, mais perd 1/10 des PV max apres chaque attaque qui touche.",
	"focus-sash": "Survit a 1 PV a une attaque qui l'aurait KO en un coup depuis les PV max (usage unique).",
	"assault-vest": "Defense Speciale x1.5 (les attaques de statut ne sont pas bloquees ici).",
	"black-sludge": "Recupere 1/16 des PV max en fin de tour si Poison, sinon perd 1/8 des PV max.",
	"heavy-duty-boots": "Immunise contre tous les degats/effets des pieges (Pointes, Picots, Toxik, Toile) a l'entree.",
	"eviolite": "Defense et Defense Speciale x1.5 si le Pokemon peut encore evoluer.",
	"scope-lens": "Taux de coup critique augmente d'un cran.",
	"razor-claw": "Taux de coup critique augmente d'un cran.",
	"expert-belt": "Degats des attaques super efficaces augmentes de 20%.",
	"muscle-band": "Degats des attaques physiques augmentes de 10%.",
	"wise-glasses": "Degats des attaques speciales augmentes de 10%.",
	"shell-bell": "Recupere 1/8 des degats infliges a chaque attaque qui touche.",
	"big-root": "Augmente de 30% les PV recuperes par les attaques a drain.",
	"sitrus-berry": "Recupere 25% des PV max des que les PV passent sous 50% (usage unique).",
	"lum-berry": "Guerit immediatement le premier statut ou la confusion inflige (usage unique).",
	"charcoal": "Attaques Feu boostees de 20%.",
	"mystic-water": "Attaques Eau boostees de 20%.",
	"miracle-seed": "Attaques Plante boostees de 20%.",
	"magnet": "Attaques Electrik boostees de 20%.",
	"never-melt-ice": "Attaques Glace boostees de 20%.",
	"black-belt": "Attaques Combat boostees de 20%.",
	"poison-barb": "Attaques Poison boostees de 20%.",
	"soft-sand": "Attaques Sol boostees de 20%.",
	"sharp-beak": "Attaques Vol boostees de 20%.",
	"twisted-spoon": "Attaques Psy boostees de 20%.",
	"silver-powder": "Attaques Insecte boostees de 20%.",
	"hard-stone": "Attaques Roche boostees de 20%.",
	"spell-tag": "Attaques Spectre boostees de 20%.",
	"dragon-fang": "Attaques Dragon boostees de 20%.",
	"black-glasses": "Attaques Tenebres boostees de 20%.",
	"metal-coat": "Attaques Acier boostees de 20%.",
	"silk-scarf": "Attaques Normal boostees de 20%.",
	"heat-rock": "Etend la duree du Soleil de 5 a 8 tours.",
	"damp-rock": "Etend la duree de la Pluie de 5 a 8 tours.",
	"smooth-rock": "Etend la duree de la Tempete de sable de 5 a 8 tours.",
	"icy-rock": "Etend la duree de la Grele de 5 a 8 tours.",
}


static func get_description(item: String) -> String:
	return ITEM_DESCRIPTIONS_FR.get(item, "(effet non documente)")


static func damage_dealt_multiplier(attacker: BattlePokemon, move: Dictionary, type_eff: float = 1.0) -> float:
	var mult := 1.0
	if attacker.held_item == "life-orb":
		mult *= 1.3
	elif attacker.held_item == "choice-band" and GameData.is_physical(move):
		mult *= 1.5
	elif attacker.held_item == "choice-specs" and not GameData.is_physical(move):
		mult *= 1.5
	elif attacker.held_item == "muscle-band" and GameData.is_physical(move):
		mult *= 1.1
	elif attacker.held_item == "wise-glasses" and not GameData.is_physical(move):
		mult *= 1.1

	if TYPE_BOOST_ITEMS.get(attacker.held_item, "") == move.get("type", ""):
		mult *= 1.2

	if attacker.held_item == "expert-belt" and type_eff > 1.0:
		mult *= 1.2

	return mult


## Reduction de degats subis (cote defenseur) : Veste de Combat sur les coups
## speciaux, Eviolite sur les deux categories (Def ET DefSpe boostees).
static func damage_taken_multiplier(defender: BattlePokemon, is_physical_hit: bool) -> float:
	var mult := 1.0
	if defender.held_item == "assault-vest" and not is_physical_hit:
		mult /= 1.5
	if defender.held_item == "eviolite" and GameData.can_still_evolve(defender.species_name):
		mult /= 1.5
	return mult


static func speed_multiplier(mon: BattlePokemon) -> float:
	return 1.5 if mon.held_item == "choice-scarf" else 1.0


## +3 tours (5 -> 8) si le poseur tient la Roche correspondant a la meteo posee.
static func weather_duration_bonus(setter: BattlePokemon, weather: String) -> int:
	return 3 if WEATHER_ROCK_ITEMS.get(setter.held_item, "") == weather else 0


## Bonus de stage de critique (Lentille Point/Griffe Rasoir : +1 cran).
static func crit_stage_bonus(mon: BattlePokemon) -> int:
	return 1 if mon.held_item in ["scope-lens", "razor-claw"] else 0


static func is_ohko_survivor(mon: BattlePokemon, would_be_damage: int) -> bool:
	return mon.held_item == "focus-sash" and not mon.item_consumed \
		and mon.current_hp == mon.max_hp and would_be_damage >= mon.current_hp


static func blocks_hazards(mon: BattlePokemon) -> bool:
	return mon.held_item == "heavy-duty-boots"


## Contrecoup du Screugneugnu (Life Orb) apres une attaque qui a touche.
static func post_attack_recoil(state: BattleState, attacker: BattlePokemon, damage_dealt: int) -> void:
	if attacker.held_item != "life-orb" or damage_dealt <= 0 or attacker.is_fainted():
		return
	if AbilityEngine.blocks_indirect_damage(attacker):
		return
	var recoil: int = max(1, int(attacker.max_hp / 10))
	attacker.apply_damage(recoil)
	state.add_log("%s est blesse par son Screugneugnu !" % GameData.fr_species(attacker.species_name))


## Soin de la Coque Placage (1/8 des degats infliges) apres une attaque qui a touche.
static func post_attack_heal(state: BattleState, attacker: BattlePokemon, damage_dealt: int) -> void:
	if attacker.held_item != "shell-bell" or damage_dealt <= 0 or attacker.is_fainted():
		return
	var heal: int = max(1, int(damage_dealt / 8))
	attacker.heal(heal)
	state.add_log("%s recupere des PV grace a sa Coque Placage !" % GameData.fr_species(attacker.species_name))


## Multiplicateur de soin des attaques a drain (Grosse Racine : +30%).
static func drain_heal_multiplier(mon: BattlePokemon) -> float:
	return 1.3 if mon.held_item == "big-root" else 1.0


## Talent Tension (Unnerve) de l'adversaire actif : empeche `mon` de manger
## toute baie tant que ce talent est sur le terrain en face.
static func _berry_blocked(state: BattleState, mon: BattlePokemon) -> bool:
	var opponent: BattlePokemon = state.team_b.active() if state.team_a.active() == mon else state.team_a.active()
	return AbilityEngine.blocks_opponent_berry(opponent)


## Baie Sitrus : declenche des que les PV passent sous 50% (usage unique).
## A appeler juste apres tout evenement qui reduit les PV de `mon`.
static func check_sitrus_berry(state: BattleState, mon: BattlePokemon) -> void:
	if mon.held_item != "sitrus-berry" or mon.item_consumed or mon.is_fainted():
		return
	if mon.hp_percent() > 0.5:
		return
	if _berry_blocked(state, mon):
		return
	mon.item_consumed = true
	var heal: int = int(mon.max_hp / 4)
	mon.heal(heal)
	state.add_log("%s recupere des PV grace a sa Baie Sitrus !" % GameData.fr_species(mon.species_name))


## Baie Prine : guerit immediatement le statut inflige (usage unique). A
## appeler juste apres qu'un statut a ete assigne a `mon`.
static func check_lum_berry(state: BattleState, mon: BattlePokemon) -> void:
	if mon.held_item != "lum-berry" or mon.item_consumed or mon.status == "":
		return
	if _berry_blocked(state, mon):
		return
	mon.item_consumed = true
	state.add_log("%s guerit grace a sa Baie Prine !" % GameData.fr_species(mon.species_name))
	mon.status = ""
	mon.toxic_counter = 0
	mon.sleep_turns_left = 0


static func end_of_turn(state: BattleState, mon: BattlePokemon) -> void:
	if mon.is_fainted():
		return
	if mon.held_item == "leftovers":
		var heal: int = max(1, int(mon.max_hp / 16))
		mon.heal(heal)
		state.add_log("%s recupere un peu de PV grace a ses Restes !" % GameData.fr_species(mon.species_name))
	elif mon.held_item == "black-sludge":
		if mon.types.has("poison"):
			var heal: int = max(1, int(mon.max_hp / 16))
			mon.heal(heal)
			state.add_log("%s recupere un peu de PV grace a sa Bue Noire !" % GameData.fr_species(mon.species_name))
		elif not AbilityEngine.blocks_indirect_damage(mon):
			var dmg: int = max(1, int(mon.max_hp / 8))
			mon.apply_damage(dmg)
			state.add_log("%s est blesse par la Bue Noire !" % GameData.fr_species(mon.species_name))
	check_sitrus_berry(state, mon)
