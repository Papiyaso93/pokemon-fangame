@tool
extends EditorScript

# Ajoute le jeu de tuiles d'une carte supplémentaire à un patch de bordure
# DÉJÀ EXISTANT (scripts/create_border_filler.gd), sans toucher aux tuiles
# déjà peintes — contrairement à create_border_filler.gd qui crée une scène
# neuve (donc écraserait tout), celui-ci charge la scène existante et rajoute
# juste une nouvelle source dans le TileSet du calque visé.
#
# TARGET_LAYER = "Below" (sol, fond opaque) ou "Above" (calque transparent
# superposé par-dessus, pour des éléments comme un sommet d'arbre isolé qui a
# besoin d'une tuile d'herbe en dessous — créé automatiquement s'il n'existe
# pas encore dans la scène).
#
# Marche à suivre :
# 1. Modifier les constantes ci-dessous.
# 2. Exécuter ce script.
# 3. Rouvrir la scène (si déjà ouverte, Scène -> Recharger la scène
#    sauvegardée) : la nouvelle carte source apparaît comme un nouvel onglet
#    dans le sélecteur de tuiles du calque visé, tes tuiles déjà peintes sont
#    intactes.

const TILE := 16

const FILLER_SCENE := "res://scenes/maps/fillers/route1_west.tscn"
const ADD_SOURCE_MAP := "route4"
const TARGET_LAYER := "Above"        # "Below" (sol opaque) ou "Above" (silhouettes transparentes, superposées)
const USE_ABOVE_ATLAS := true        # true -> charge <map>_above.png (silhouettes transparentes), false -> <map>_below.png

func _run() -> void:
	var packed := load(FILLER_SCENE) as PackedScene
	if packed == null:
		push_error("Scène introuvable : %s" % FILLER_SCENE)
		return
	var root := packed.instantiate()

	var layer := root.get_node_or_null(TARGET_LAYER) as TileMapLayer
	if layer == null:
		# N'existe pas encore sur ce patch -> créé avec son propre TileSet,
		# ajouté APRÈS "Below" dans l'arbre pour se dessiner par-dessus
		# (ordre des nœuds = ordre de dessin pour les CanvasItem).
		layer = TileMapLayer.new()
		layer.name = TARGET_LAYER
		layer.tile_set = TileSet.new()
		layer.tile_set.tile_size = Vector2i(TILE, TILE)
		root.add_child(layer)
		layer.owner = root
		print("Calque '%s' créé (n'existait pas encore)." % TARGET_LAYER)
	var ts := layer.tile_set

	var base := "res://generated/%s" % ADD_SOURCE_MAP
	var f := FileAccess.open(base + ".json", FileAccess.READ)
	if f == null:
		push_error("JSON introuvable : %s.json" % base)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var suffix := "_above.png" if USE_ABOVE_ATLAS else "_below.png"
	var tex := load(base + suffix) as Texture2D
	if tex == null:
		push_error("Atlas non importé : %s%s — rafraîchis le FileSystem ?" % [ADD_SOURCE_MAP, suffix])
		return

	var cols: int = data["atlas_cols"]
	var tiles: Array = data["tiles"]
	var above_flags: Array = data.get("above", [])

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for k in range(tiles.size()):
		if USE_ABOVE_ATLAS and not (k < above_flags.size() and above_flags[k]):
			continue   # cette tuile n'a pas de version "above", pas la peine de la créer
		src.create_tile(Vector2i(k % cols, k / cols))
	ts.add_source(src)

	var new_packed := PackedScene.new()
	new_packed.pack(root)
	var err := ResourceSaver.save(new_packed, FILLER_SCENE)
	if err != OK:
		push_error("Échec sauvegarde : %d" % err)
		return
	print("Source '%s' (%s) ajoutée au calque '%s' de %s — tuiles déjà peintes conservées." % [ADD_SOURCE_MAP, suffix, TARGET_LAYER, FILLER_SCENE])
