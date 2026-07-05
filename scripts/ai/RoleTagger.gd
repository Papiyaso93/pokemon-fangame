class_name RoleTagger
extends RefCounted
## Deduit automatiquement les roles strategiques d'un BattlePokemon a partir
## de son moveset choisi, pour nourrir les bonus de plan de jeu de l'IA.

const HAZARD_MOVES := ["stealth-rock", "spikes", "toxic-spikes", "sticky-web"]
const BOOST_MOVES := ["swords-dance", "dragon-dance", "nasty-plot", "amnesia", "growth", "agility"]
## Tous les moves de soin instantane cible sur soi (champ "healing" > 0 en
## donnees) : Repos-Sur, Sieste Auree, Synthese etc. avaient le meme bug que
## Repos (le champ "healing" est bien lu par le moteur depuis cette session,
## mais l'IA ne les reconnaissait pas comme "moves de soin" pour autant, donc
## ne les priorisait jamais correctement).
const RECOVERY_MOVES := ["recover", "soft-boiled", "rest", "roost", "synthesis", "moonlight", "morning-sun", "slack-off"]
const CRIPPLE_STATUS_MOVES := ["thunder-wave", "toxic", "poison-powder", "stun-spore", "sleep-powder", "hypnosis", "will-o-wisp"]
const WEATHER_MOVES := {
	"rain-dance": "rain", "sunny-day": "sun", "sandstorm": "sandstorm", "hail": "hail",
}
## Doivent "recharger" (ne peuvent pas agir) le tour suivant leur utilisation.
const RECHARGE_MOVES := [
	"hyper-beam", "giga-impact", "frenzy-plant", "blast-burn", "hydro-cannon",
	"rock-wrecker", "roar-of-time", "prismatic-laser", "eternabeam", "meteor-assault",
]
## Bloquent les attaques ciblees ce tour ; taux de succes decroissant si spamme.
const PROTECT_MOVES := ["protect", "detect", "king-shield", "spiky-shield", "baneful-bunker"]
## L'utilisateur s'evanouit apres l'attaque (qu'elle touche ou non).
const SELF_KO_MOVES := ["explosion", "self-destruct", "misty-explosion"]
## Degats = niveau de l'attaquant, sans stats/STAB/critique/meteo (juste
## bloquees par une immunite de type standard). Ex : Frappe Atlas (Seismic Toss).
const FIXED_LEVEL_DAMAGE_MOVES := ["seismic-toss", "night-shade"]
## Degats fixes independants du niveau/des stats.
const FIXED_VALUE_DAMAGE_MOVES := {"dragon-rage": 40, "sonic-boom": 20}
## Ramene les PV de la cible a ceux du lanceur ; echoue si le lanceur a plus
## ou autant de PV que la cible (Effort/Endeavor). Cle de la strategie FEAR.
const HP_EQUALIZE_MOVES := ["endeavor"]

## Necessitent un tour de "charge" avant de frapper (sauf meteo indiquee, qui
## permet un tir instantane). Mecanique totalement absente jusqu'ici : ces
## moves frappaient toujours instantanement, quelle que soit la meteo.
const CHARGE_MOVES := {"solar-beam": "sun", "solar-blade": "sun"}
const CHARGE_MOVE_MESSAGES := {"solar-beam": "absorbe la lumiere", "solar-blade": "concentre son energie"}

## Apres avoir touche, forcent un changement de Pokemon du cote du lanceur
## (s'il est toujours en vie et qu'il reste un remplacant) : Change Eclair,
## Demi-Tour. Mecanique absente jusqu'ici (degats infliges mais jamais de switch).
const PIVOT_MOVES := ["u-turn", "volt-switch"]


static func tag(mon: BattlePokemon) -> void:
	mon.role_tags.clear()

	var has_hazard := false
	var has_boost := false
	var has_recovery := false
	var has_cripple := false
	var has_weather := AbilityEngine.WEATHER_SETTERS.has(mon.ability)

	for m: String in mon.moves:
		if HAZARD_MOVES.has(m):
			has_hazard = true
		if BOOST_MOVES.has(m):
			has_boost = true
		if RECOVERY_MOVES.has(m):
			has_recovery = true
		if CRIPPLE_STATUS_MOVES.has(m):
			has_cripple = true
		if WEATHER_MOVES.has(m):
			has_weather = true

	if has_hazard:
		mon.role_tags.append("hazard_setter")
	if has_boost:
		mon.role_tags.append("sweeper")
	if has_recovery and mon.stats.get("defense", 0) + mon.stats.get("special_defense", 0) > mon.stats.get("attack", 0) + mon.stats.get("special_attack", 0):
		mon.role_tags.append("wall")
	if has_cripple:
		mon.role_tags.append("status_support")
	if has_weather:
		mon.role_tags.append("weather_setter")
