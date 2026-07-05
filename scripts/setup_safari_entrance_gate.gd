@tool
extends EditorScript

# Script ponctuel : attache safari_entrance_gate.gd à la racine de
# safari_entrance.tscn pour verrouiller les sorties pendant l'intro.

func _run() -> void:
	var path := "res://scenes/maps/safari_entrance.tscn"
	var packed := load(path) as PackedScene
	var root := packed.instantiate()
	root.set_script(load("res://scripts/safari_entrance_gate.gd"))

	var new_packed := PackedScene.new()
	new_packed.pack(root)
	var err := ResourceSaver.save(new_packed, path)
	if err != OK:
		push_error("Échec sauvegarde : %d" % err)
		return
	print("Script de verrouillage attaché à ", path)
