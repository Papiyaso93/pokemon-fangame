extends "res://scripts/npc.gd"

# PNJ de test pour les sprites custom (amis, persos d'autres univers — voir
# écran-titre "Tester" > "Tester des sprites"). Charge l'image directement
# depuis assets/characters/custom/ (pas assets/characters/) sans variation de
# direction pour l'instant (une seule face dessinée) — le but ici est juste de
# voir le rendu en jeu, pas une vraie intégration PNJ avec dialogues soignés.
# Une fois les 9 cases façon red_normal.png prêtes, on pourra repasser sur
# npc.gd tel quel (même format 16x32/colonnes).

func _update_sprite() -> void:
	var tex := load("res://assets/characters/custom/%s.png" % sprite_name) as Texture2D
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2(0, -16)

func get_lines() -> Array[String]:
	return ["Yo ! Test du sprite \"%s\" en conditions réelles." % sprite_name]

# Rempli (voir test_sprites_room.tscn) : parler à ce PNJ lance l'écran de
# combat "test" (scripts/test_battle_screen.gd) au lieu d'un dialogue normal —
# juste pour juger/comparer le rendu d'un ou plusieurs portraits 64x64, aucun
# vrai combat derrière. Plusieurs clés séparées par des virgules ("gus,zoro").
# Vide = comportement normal (dialogue via get_lines()), voir player.gd::_talk_to().
@export var test_battle_trainer := ""

const TestBattleScreenScene := preload("res://scenes/ui/test_battle_screen.tscn")

func start_test_battle() -> void:
	var screen := TestBattleScreenScene.instantiate()
	screen.trainer_key = test_battle_trainer
	get_tree().root.add_child(screen)
	await screen.finished
	screen.queue_free()
