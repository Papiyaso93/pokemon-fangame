extends "res://scripts/npc.gd"

# PNJ custom "complet" (3 faces sud/nord/ouest — l'est réutilise l'ouest en
# miroir, comme npc.gd) : contrairement à npc_test_sprite.gd (une seule face,
# pour un tout premier test rapide), celui-ci se tourne vraiment vers le
# joueur comme un vrai PNJ. Seule différence avec npc.gd : le sprite vit dans
# assets/characters/custom/ plutôt que assets/characters/ (réservé aux
# assets officiels du jeu) — voir écran-titre "Tester" > "Tester des sprites".

func _update_sprite() -> void:
	var tex := load("res://assets/characters/custom/%s.png" % sprite_name) as Texture2D
	var at := AtlasTexture.new()
	at.atlas = tex
	var col: int = {"south": 0, "north": 1, "west": 2, "east": 2}.get(facing, 0)
	at.region = Rect2(col * 16, 0, 16, 32)
	sprite.texture = at
	sprite.flip_h = (facing == "east")

@export var dialogue_line := ""

func get_lines() -> Array[String]:
	var lines: Array[String] = []
	if dialogue_line != "":
		lines.append(dialogue_line)
	return lines

# Même mécanique que npc_test_sprite.gd (voir ce fichier) : parler à ce PNJ
# lance l'écran de combat "test" au lieu de refermer juste le dialogue, si
# test_battle_trainer est rempli. Plusieurs clés séparées par des virgules.
@export var test_battle_trainer := ""

const TestBattleScreenScene := preload("res://scenes/ui/test_battle_screen.tscn")

func start_test_battle() -> void:
	var screen := TestBattleScreenScene.instantiate()
	screen.trainer_key = test_battle_trainer
	get_tree().root.add_child(screen)
	await screen.finished
	screen.queue_free()
