extends Node

# Singleton (autoload) : transmet l'info de spawn lors d'un changement de map.
# Rempli par le joueur avant change_scene_to_file, lu par le joueur de la map suivante.

var pending := false
var direct := false     # true = warp ponctuel (coord précise) ; false = bord de map
var from_dir := "up"    # (mode bord) direction franchie pour sortir de la map précédente
var cross := 0          # (mode bord) coord le long du bord
var direct_tile := Vector2i.ZERO   # (mode direct) case d'arrivée exacte
var facing := "south"   # orientation conservée
