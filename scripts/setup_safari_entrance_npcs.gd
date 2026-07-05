@tool
extends EditorScript

# Script ponctuel : ajoute worker_f et worker_m dans safari_entrance.tscn, une
# fois. Après exécution, safari_entrance est retiré de la liste auto-régénérée
# (scripts/import_map.gd) pour ne pas perdre ces PNJ à la prochaine génération.

const NPCScene := preload("res://scenes/npc/npc.tscn")
const TILE := 16

func _run() -> void:
	var path := "res://scenes/maps/safari_entrance.tscn"
	var packed := load(path) as PackedScene
	var root := packed.instantiate()

	_add_npc(root, "worker_f", "res://scripts/npc_worker_f.gd", Vector2i(7, 5), "west")
	_add_npc(root, "worker_m", "res://scripts/npc_worker_m.gd", Vector2i(1, 4), "east")

	var new_packed := PackedScene.new()
	new_packed.pack(root)
	var err := ResourceSaver.save(new_packed, path)
	if err != OK:
		push_error("Échec sauvegarde : %d" % err)
		return
	print("PNJ ajoutés dans ", path)

func _add_npc(root: Node, name: String, script_path: String, tile: Vector2i, facing: String) -> void:
	var npc := NPCScene.instantiate()
	npc.name = name
	npc.set_script(load(script_path))
	npc.facing = facing
	npc.sprite_name = name
	npc.position = Vector2(tile) * TILE
	root.add_child(npc)
	npc.owner = root
	for child in npc.get_children():
		child.owner = root
