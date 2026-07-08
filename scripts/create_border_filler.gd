@tool
extends EditorScript

# Outil ponctuel (sélectionner ce fichier -> Fichier -> Exécuter) pour créer
# une nouvelle scène de patch de bordure (voir scripts/border_fillers.gd) :
# un TileMapLayer VIDE, prêt à peindre dans l'éditeur Godot, avec le vrai jeu
# de tuiles d'une ou plusieurs maps existantes (pour rester cohérent
# visuellement avec le terrain alentour côté "Below" — pas de calque "Above"/
# collision, ces patchs sont purement décoratifs, jamais dans une zone où le
# joueur peut physiquement marcher).
#
# Marche à suivre :
# 1. Modifier les constantes ci-dessous (SOURCE_MAPS peut contenir plusieurs
#    noms si le terrain à peindre combine plusieurs styles, ex. herbe +
#    montagne : ["route1", "route3"]).
# 2. Exécuter ce script (il crée scenes/maps/fillers/<OUT_NAME>.tscn).
# 3. Ouvrir cette scène, peindre le terrain voulu avec l'outil TileMapLayer —
#    chaque carte source apparaît comme un "TileSet Atlas Source" séparé dans
#    le sélecteur de tuiles (onglet en haut du panneau "Tuiles").
# 4. Ajouter une entrée dans BorderFillers.PATCHES (scripts/border_fillers.gd)
#    avec le bon "offset" (voir le script d'analyse pour les coordonnées).

const TILE := 16

# À adapter avant chaque exécution :
const SOURCE_MAPS := ["route2"]            # une ou plusieurs cartes dont on veut le jeu de tuiles
const OUT_NAME := "route2_west"            # nom du fichier de sortie (descriptif, ex. "<map>_<direction>")
const SIZE := Vector2i(16, 80)             # taille indicative du trou à couvrir (tuiles) — juste informatif, le TileMapLayer n'est pas borné
# Mettre à true UNIQUEMENT si tu veux vraiment écraser un patch déjà peint
# (ex. recommencer de zéro) — sinon le script refuse par sécurité (voir
# HANDOFF.md, incident où pallet_town_west.tscn a été effacé par une
# ré-exécution accidentelle sans avoir changé OUT_NAME).
const FORCE_OVERWRITE := false

func _run() -> void:
	var out := "res://scenes/maps/fillers/%s.tscn" % OUT_NAME
	if not FORCE_OVERWRITE and ResourceLoader.exists(out):
		push_error("REFUS : %s existe déjà (peut-être déjà peint !). Change OUT_NAME, ou mets FORCE_OVERWRITE=true si tu veux vraiment repartir de zéro." % out)
		return

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	for source_map in SOURCE_MAPS:
		var base := "res://generated/%s" % source_map
		var f := FileAccess.open(base + ".json", FileAccess.READ)
		if f == null:
			push_error("JSON introuvable : %s.json — ce nom existe bien dans generated/ ?" % base)
			return
		var data: Dictionary = JSON.parse_string(f.get_as_text())

		var tex_below := load(base + "_below.png") as Texture2D
		if tex_below == null:
			push_error("Atlas non importé : %s_below.png — rafraîchis le FileSystem ?" % source_map)
			return

		var cols: int = data["atlas_cols"]
		var tiles: Array = data["tiles"]

		var src := TileSetAtlasSource.new()
		src.texture = tex_below
		src.texture_region_size = Vector2i(TILE, TILE)
		for k in range(tiles.size()):
			src.create_tile(Vector2i(k % cols, k / cols))
		ts.add_source(src)

	var root := Node2D.new()
	root.name = "Filler"

	var layer := TileMapLayer.new()
	layer.name = "Below"
	layer.tile_set = ts
	root.add_child(layer)
	layer.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, out)
	if err != OK:
		push_error("Échec sauvegarde %s : %d" % [OUT_NAME, err])
		return
	print("Patch créé : %s (trou visé : %dx%d tuiles, jeux de tuiles de %s)." % [out, SIZE.x, SIZE.y, ", ".join(SOURCE_MAPS)])
	print("-> Ouvre cette scène, peins le terrain, puis ajoute une entrée dans BorderFillers.PATCHES.")
