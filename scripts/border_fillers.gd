class_name BorderFillers
extends RefCounted

# Patchs décoratifs pour combler les zones grises aux jonctions de cartes dont
# les tailles ne correspondent pas exactement (cf. HANDOFF.md, section
# "Bordures de cartes mal jointes"). Indépendant du pipeline pret->Godot :
# les ~60 maps générées ne sont JAMAIS modifiées pour ça, donc restent
# régénérables à tout moment sans perdre ce travail.
#
# Chaque patch est une petite scène peinte à la main dans
# scenes/maps/fillers/ (généré vide par scripts/create_border_filler.gd,
# puis peint dans l'éditeur Godot comme n'importe quel TileMapLayer), posée
# par player.gd::_load_world() à un décalage fixe (en tuiles) par rapport à
# l'origine de la carte indiquée.
#
# offset : coin haut-gauche du patch, en tuiles, relatif à l'origine (0,0)
# de la carte "map" — peut être négatif (le patch déborde hors de la carte,
# c'est justement le but pour combler un trou au bord).

const PATCHES := {
	"route19": [
		{"scene": "res://scenes/maps/fillers/route19_left_top.tscn", "offset": Vector2i(-16, 0)},
	],
	"cinnabar_island": [
		# Aucune connexion à l'ouest de Cramois'île — juste la marge que la
		# caméra peut révéler au-delà du bord (pas d'autre carte à raccorder).
		{"scene": "res://scenes/maps/fillers/cinnabar_west.tscn", "offset": Vector2i(-16, 0)},
	],
	"route21_south": [
		# Aucune connexion gauche/droite sur route21_south — même cas que
		# Cramois'île, juste sur toute sa hauteur (50 tuiles).
		{"scene": "res://scenes/maps/fillers/route21_south_west.tscn", "offset": Vector2i(-16, 0)},
		{"scene": "res://scenes/maps/fillers/route21_south_east.tscn", "offset": Vector2i(24, 0)},
	],
	"route21_north": [
		# Même cas que route21_south : aucune connexion gauche/droite.
		{"scene": "res://scenes/maps/fillers/route21_north_west.tscn", "offset": Vector2i(-16, 0)},
		{"scene": "res://scenes/maps/fillers/route21_north_east.tscn", "offset": Vector2i(24, 0)},
	],
	"pallet_town": [
		# Aucune connexion gauche/droite — bord de carte = barrière
		# décorative (vérifié dans generated/pallet_town.json), avec des
		# arbres juste derrière (pas de l'eau, on n'est pas sur la côte ici).
		{"scene": "res://scenes/maps/fillers/pallet_town_west.tscn", "offset": Vector2i(-16, 0)},
		{"scene": "res://scenes/maps/fillers/pallet_town_east.tscn", "offset": Vector2i(24, 0)},
	],
	"route1": [
		# Aucune connexion gauche/droite — herbe/route derrière la barrière,
		# pas d'eau (route terrestre, pas côtière).
		{"scene": "res://scenes/maps/fillers/route1_west.tscn", "offset": Vector2i(-16, 0)},
		{"scene": "res://scenes/maps/fillers/route1_east.tscn", "offset": Vector2i(24, 0)},
	],
	"viridian_city": [
		# route22 (24 tuiles de haut) ne couvre que le milieu du bord gauche
		# de Jadielle (48x40, offset 10) — manque en haut (y 0-10) et en bas
		# (y 34-40). Jadielle a déjà sa tuile de montagne (#58) à cet endroit.
		{"scene": "res://scenes/maps/fillers/viridian_west_bottom.tscn", "offset": Vector2i(-16, 34)},
		{"scene": "res://scenes/maps/fillers/viridian_west_top.tscn", "offset": Vector2i(-16, 0)},
		# Aucune connexion à droite du tout — tout le bord est (40 tuiles).
		{"scene": "res://scenes/maps/fillers/viridian_east.tscn", "offset": Vector2i(48, 0)},
		# route2 (24 de large) ne couvre que le milieu du bord nord (offset
		# 12, x=12-36) — portion x=36-48 (coin nord-est) à combler.
		{"scene": "res://scenes/maps/fillers/viridian_north_right.tscn", "offset": Vector2i(36, -16)},
		# Même chose côté gauche du bord nord (x=0-12).
		{"scene": "res://scenes/maps/fillers/viridian_north_left.tscn", "offset": Vector2i(0, -16)},
	],
	"route22": [
		# Aucune connexion vers le bas du tout — tout le bord sud (48 tuiles
		# de large) est concerné. Sol déjà uniforme dans l'atlas de route22.
		{"scene": "res://scenes/maps/fillers/route22_south.tscn", "offset": Vector2i(0, 24)},
		# route23 (24 de large) ne couvre que la moitié gauche du bord nord
		# de route22 (48 de large) — moitié droite (x=24-48) à combler.
		{"scene": "res://scenes/maps/fillers/route22_north_right.tscn", "offset": Vector2i(24, -16)},
	],
	"route2": [
		# Aucune connexion gauche/droite — barrière/arbres sur toute la
		# hauteur (80 tuiles), même style que Jadielle.
		{"scene": "res://scenes/maps/fillers/route2_west.tscn", "offset": Vector2i(-16, 0)},
	],
	"route20": [
		# route19 (60 tuiles de haut) accroché à droite de route20 (20 tuiles
		# de haut seulement) déborde vers le haut (y<0). route20 n'a aucune
		# connexion "up" du tout, donc c'est TOUT son bord supérieur qui est
		# concerné, pas juste la portion près de la jonction — d'où un patch
		# aussi large que route20 elle-même (120 tuiles).
		{"scene": "res://scenes/maps/fillers/route20_top.tscn", "offset": Vector2i(0, -40)},
	],
}
