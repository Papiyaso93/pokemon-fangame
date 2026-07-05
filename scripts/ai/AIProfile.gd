class_name AIProfile
extends Resource
## Poids qui definissent la "personnalite" strategique d'un dresseur CPU.
## Un archetype competitif (Hyper Offense, Stall, Balance, Weather...) = un set de poids.

@export var profile_name: String = "Balance"

## Poids sur les degats/KO immediats (haut = agressif).
@export var aggression: float = 1.0

## Poids sur la securite du matchup lors d'un switch (haut = prudent).
@export var safety: float = 1.0

## Penalite appliquee quand une action est risquee (fort recul, faible precision...).
@export var risk_aversion: float = 1.0

## Poids sur l'utilite de poser des hazards.
@export var hazard_priority: float = 1.0

## Poids sur l'utilite de booster un sweeper en position sure.
@export var setup_priority: float = 1.0

## Poids sur l'utilite d'infliger un statut a la plus grosse menace adverse.
@export var status_priority: float = 1.0

## Poids sur l'utilite de poser sa meteo favorite.
@export var weather_priority: float = 1.0


static func balance() -> AIProfile:
	var p := AIProfile.new()
	p.profile_name = "Balance"
	return p


static func hyper_offense() -> AIProfile:
	var p := AIProfile.new()
	p.profile_name = "Hyper Offense"
	p.aggression = 1.6
	p.safety = 0.6
	p.risk_aversion = 0.6
	p.setup_priority = 1.4
	p.hazard_priority = 0.8
	p.status_priority = 0.7
	return p


static func stall() -> AIProfile:
	var p := AIProfile.new()
	p.profile_name = "Stall"
	p.aggression = 0.5
	p.safety = 1.6
	p.risk_aversion = 1.4
	p.setup_priority = 0.5
	p.hazard_priority = 1.3
	p.status_priority = 1.6
	return p


static func weather() -> AIProfile:
	var p := AIProfile.new()
	p.profile_name = "Weather"
	p.aggression = 1.1
	p.safety = 1.0
	p.hazard_priority = 1.0
	p.setup_priority = 0.9
	p.status_priority = 0.9
	p.weather_priority = 1.8
	return p
