extends Node

# Singleton (autoload) : transmet l'info de spawn lors d'un changement de map.
# Rempli par le joueur avant change_scene_to_file, lu par le joueur de la map suivante.

var pending := false
var from_dir := "up"    # direction franchie pour sortir de la map précédente
var cross := 0          # coord le long du bord (x pour up/down, y pour left/right)
var facing := "south"   # orientation conservée
