extends Node

# Autoload : quête du Minidraco (Camille, zone 1 — coin nord-ouest du Parc
# Safari, voir acte1-parc-safari.md et la conversation de conception associée).
# Appelé depuis player.gd à chaque case franchie sur safari_zone_center
# (même point d'accroche que les tables de rencontre, voir
# _move_toward_target()) — pas de Area2D dans ce projet, tout se fait par
# case (cohérent avec _is_grass()/_grass_zone_at() etc.).
#
# État du motif (hunt_active/hunt_step/step_started_at) volontairement PAS persisté
# dans PlayerData/save_manager.gd : si le joueur quitte en plein motif, il
# repart de zéro à la prochaine tentative — cohérent avec le reset complet
# déjà prévu en cas de mauvaise approche.

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const GrassEffectTexture := preload("res://assets/effects/jump_tall_grass.png")   # FRLG (kanto-pipeline), 2 frames 16x16

const MAP_NAME := "safari_zone_center"

# Tuiles données par Gus (14/07/2026).
const ARRIVAL_TILES: Array[Vector2i] = [Vector2i(9, 17), Vector2i(9, 18)]

# Après le message d'arrivée, le joueur avance seul jusqu'ici, puis s'arrête.
const PLAYER_STOP_TILE := Vector2i(13, 17)

# Camille entre ensuite en marchant depuis cette case jusqu'à CAMILLE_STOP_TILE
# (juste au sud du joueur). Si (29,19) tombe hors-écran une fois testé en jeu,
# passer CAMILLE_START_TILE à Vector2i(28, 19) à la place (indiqué par Gus).
const CAMILLE_START_TILE := Vector2i(29, 19)
const CAMILLE_STOP_TILE := Vector2i(13, 18)

# Les 3 touffes du motif (petite zone d'herbe -> grande zone, 2 sauts).
# Motif "timing" (voir la conversation de conception — la version
# "direction" ne se lisait pas assez clairement) : chaque touffe alterne
# secousse (alerte, dangereux d'approcher) / pause (calme, on peut poser le
# pied dessus). Même rythme à 2 temps partout, seule la fenêtre "pause" se
# resserre d'une case à l'autre pour faire monter la difficulté — pas de
# comptage précis à faire, juste attraper le bon moment.
const HUNT_STEPS: Array[Dictionary] = [
	{"tile": Vector2i(16, 16), "shake": 0.6, "pause": 1.2},   # facile : grande fenêtre
	{"tile": Vector2i(12, 11), "shake": 0.6, "pause": 0.7},   # moyen
	{"tile": Vector2i(17, 9), "shake": 0.8, "pause": 0.35},   # difficile : fenêtre courte
]

var hunt_active := false
var hunt_step := 0
var step_started_at := 0.0   # Time.get_ticks_msec()/1000.0 au moment où la touffe actuelle est apparue

var camille_body: StaticBody2D = null   # collision (voir scenes/npc/npc.tscn) — sans ça le joueur la traverse
var camille_sprite: AnimatedSprite2D = null
var marker_sprite: AnimatedSprite2D = null

func check_tile(tile: Vector2i, map_name: String, player: Node) -> void:
	if map_name != MAP_NAME or PlayerData.minidraco_captured:
		return

	if not PlayerData.minidraco_spot_found and tile in ARRIVAL_TILES:
		PlayerData.minidraco_spot_found = true
		await _play_arrival_sequence(player)
	elif hunt_active:
		await _check_hunt_step(tile, player)

# Message d'arrivée -> le joueur marche seul jusqu'à PLAYER_STOP_TILE ->
# Camille arrive en marchant -> les deux se tournent l'un vers l'autre ->
# dialogue d'intro -> le motif démarre.
func _play_arrival_sequence(player: Node) -> void:
	player.is_busy = true
	player._play("face")   # sinon l'anim de marche reste affichée pendant le message
	var dialogue := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(dialogue)
	var arrival_lines: Array[String] = ["Un bruissement inhabituel attire ton attention, un peu plus loin dans l'herbe."]
	dialogue.say(arrival_lines)
	await dialogue.finished
	dialogue.queue_free()

	# is_busy reste true tout du long : le joueur ne reprend la main qu'à la
	# toute fin de cette séquence scriptée (avant le motif lui-même).
	await _walk_player_to(player, PLAYER_STOP_TILE)

	_spawn_camille(player, CAMILLE_START_TILE)
	await _walk_camille_to(player, CAMILLE_STOP_TILE)

	# Face à face : Camille est au sud du joueur (voir CAMILLE_STOP_TILE).
	player.facing = "south"
	player._play("face")
	_camille_play("face", "north")

	var intro := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(intro)
	var intro_lines: Array[String] = [
		"Ah %s, toi aussi tu as remarqué quelque chose par ici." % PlayerData.player_name,
		"J'ai l'impression que Minidraco se trouve bien dans cette zone. Mais ce genre de Pokémon est extrêmement craintif : au moindre geste maladroit, il disparaît.",
		"Regarde bien : il s'agite quand il est sur ses gardes. Approche-toi seulement quand il se calme.",
		"Vas-y, je reste là si besoin.",
	]
	intro.say(intro_lines)
	await intro.finished
	intro.queue_free()

	player.is_busy = false
	# Sans ça, l'appui qui ferme la dernière page peut aussi redéclencher une
	# interaction avec Camille dès la frame suivante (elle est juste en face
	# du joueur) — même délai que _talk_to() après un dialogue normal.
	player.interact_cooldown = 0.2
	hunt_active = true
	hunt_step = 0
	_place_marker(player)

# Fait avancer le joueur case par case jusqu'à target_tile, en réutilisant le
# même pas que le déplacement normal (move_target + _move_toward_target +
# anim "walk"), simplement piloté ici plutôt que par l'input — is_busy reste
# true pendant tout le trajet donc _physics_process() n'interfère pas.
func _walk_player_to(player: Node, target_tile: Vector2i) -> void:
	var cur := _tile_of(player.position, player.TILE_SIZE)
	var path := _l_path(cur, target_tile)
	for step in path:
		var dir: Vector2i = step - cur
		player.facing = _facing_for(dir)
		player.current_speed = player.SPEED
		player.move_target = Vector2(step) * player.TILE_SIZE
		player.is_moving = true
		player._play("walk")
		while player.position != player.move_target:
			player._move_toward_target(player.get_process_delta_time())
			await player.get_tree().process_frame
		cur = step
	player._play("face")

# Camille n'a pas de cycle de marche animé dans ce projet (les PNJ sont
# statiques, voir npc.gd) : elle "glisse" case par case à la même vitesse que
# le joueur plutôt que de jouer une vraie animation de pas. À améliorer plus
# tard si on ajoute un vrai jeu d'animations de marche pour les PNJ.
func _walk_camille_to(player: Node, target_tile: Vector2i) -> void:
	if camille_body == null:
		return
	var cur := _tile_of(camille_body.position, player.TILE_SIZE)
	var path := _l_path(cur, target_tile)
	for step in path:
		var dir: Vector2i = step - cur
		var facing := _facing_for(dir)
		_camille_play("walk", facing)
		var from_pos: Vector2 = camille_body.position
		var to_pos: Vector2 = Vector2(step) * player.TILE_SIZE
		var duration: float = player.TILE_SIZE / player.SPEED
		var elapsed := 0.0
		while elapsed < duration:
			elapsed += player.get_process_delta_time()
			camille_body.position = from_pos.lerp(to_pos, clampf(elapsed / duration, 0.0, 1.0))
			await player.get_tree().process_frame
		camille_body.position = to_pos
		cur = step
	_camille_play("face", "south")

func _check_hunt_step(tile: Vector2i, player: Node) -> void:
	if hunt_step >= HUNT_STEPS.size():
		return
	var step: Dictionary = HUNT_STEPS[hunt_step]
	if tile != step["tile"]:
		return

	if not _in_calm_window(step):
		await _play_fail_reset(player)
		return

	hunt_step += 1
	if hunt_step >= HUNT_STEPS.size():
		hunt_active = false
		_clear_marker()
		await _launch_capture(player)
	else:
		_place_marker(player)

# true si on est actuellement dans la fenêtre "pause" (calme) du cycle
# secousse/pause de la touffe active — voir HUNT_STEPS et _place_marker().
func _in_calm_window(step: Dictionary) -> bool:
	var shake: float = float(step["shake"])
	var pause: float = float(step["pause"])
	var now := Time.get_ticks_msec() / 1000.0
	var elapsed := fmod(now - step_started_at, shake + pause)
	return elapsed >= shake

func _play_fail_reset(player: Node) -> void:
	player.is_busy = true
	# Fondu rapide (même composant que les entrées/sorties de bâtiment, voir
	# screen_fade.gd, 0.15s) : tout le travail (téléportation, reset du
	# motif) se fait PENDANT le noir, puis on refond tout de suite. Le
	# dialogue vient après coup, une fois l'écran revenu à la normale — avant
	# ce correctif, il s'affichait pendant que le cache noir (layer 100,
	# au-dessus de tout) le recouvrait encore, donc invisible.
	await ScreenFade.fade_out()
	hunt_step = 0
	player.position = Vector2(PLAYER_STOP_TILE) * player.TILE_SIZE
	player.move_target = player.position
	player.is_moving = false
	player.facing = "south"
	player._play("face")
	# Camille a pu se tourner ailleurs si le joueur lui avait reparlé depuis
	# un autre angle pendant le motif (voir npc_camille_minidraco_hunt.gd::
	# face_toward()) — on la remet face au joueur, comme à l'arrivée.
	_camille_play("face", "north")
	_place_marker(player)
	await ScreenFade.fade_in()

	var dialogue := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(dialogue)
	var fail_lines: Array[String] = ["Raté, il a filé. Attends qu'il se calme avant de t'approcher."]
	dialogue.say(fail_lines)
	await dialogue.finished
	dialogue.queue_free()
	player.is_busy = false
	player.interact_cooldown = 0.2   # même correctif que _play_arrival_sequence()

func _launch_capture(player: Node) -> void:
	await player._start_encounter("dratini", true)

	if "dratini" not in PlayerData.pokedex_caught:
		# Fui ou plus de Safari Ball : pas d'échec bloquant, on repart pour un
		# nouvel essai du motif complet.
		player.is_busy = true
		hunt_active = true
		hunt_step = 0
		_place_marker(player)
		var dialogue := DialogueBoxScene.instantiate()
		player.get_tree().current_scene.add_child(dialogue)
		var retry_lines: Array[String] = ["Tant pis, on retente une prochaine fois."]
		dialogue.say(retry_lines)
		await dialogue.finished
		dialogue.queue_free()
		player.is_busy = false
		return

	PlayerData.minidraco_captured = true
	PlayerData.has_surf = true
	player.is_busy = true
	var dialogue := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(dialogue)
	var reveal_lines: Array[String] = [
		"Attends... ses couleurs ne sont pas normales. C'est... c'est un shiny !",
		"Il faut absolument qu'on l'étudie au labo. Merci pour ton aide, c'est une découverte incroyable.",
		"Beau travail. Tiens, avant que j'oublie : une Planche de Surf. Il y a des coins du parc qu'on n'atteint qu'en passant par l'eau, ça te sera utile pour la suite.",
	]
	dialogue.say(reveal_lines)
	await dialogue.finished
	dialogue.queue_free()
	player.is_busy = false
	_clear_camille()

# --- Repère de touffe d'herbe -----------------------------------------------
# Motif "timing" (voir HUNT_STEPS) : pas de teinte artificielle (rouge/vert
# retiré, ça rendait mal) — on revient à quelque chose de plus naturel,
# proche du tout premier essai : la touffe s'agite (boucle 2 frames de
# jump_tall_grass) pendant la secousse (danger), et reste immobile (1 frame
# fixe) pendant la pause (on peut s'approcher). Le mouvement lui-même porte
# l'info, pas une couleur.

func _marker_frames() -> SpriteFrames:
	var f0 := AtlasTexture.new()
	f0.atlas = GrassEffectTexture
	f0.region = Rect2(0, 0, 16, 16)
	var f1 := AtlasTexture.new()
	f1.atlas = GrassEffectTexture
	f1.region = Rect2(0, 16, 16, 16)

	var sf := SpriteFrames.new()
	sf.add_animation("alert")
	sf.set_animation_loop("alert", true)
	sf.set_animation_speed("alert", 6.0)
	sf.add_frame("alert", f0)
	sf.add_frame("alert", f1)
	sf.add_animation("calm")
	sf.set_animation_loop("calm", true)
	sf.add_frame("calm", f1)
	return sf

func _place_marker(player: Node) -> void:
	_clear_marker()
	if hunt_step >= HUNT_STEPS.size():
		return
	var step: Dictionary = HUNT_STEPS[hunt_step]
	var tile: Vector2i = step["tile"]
	var tile_pos: Vector2 = Vector2(tile) * player.TILE_SIZE
	var shake: float = float(step["shake"])
	var pause: float = float(step["pause"])

	marker_sprite = AnimatedSprite2D.new()
	marker_sprite.sprite_frames = _marker_frames()
	marker_sprite.centered = false
	marker_sprite.position = tile_pos
	player.get_tree().current_scene.add_child(marker_sprite)
	marker_sprite.play("alert")

	step_started_at = Time.get_ticks_msec() / 1000.0
	var tw := marker_sprite.create_tween()
	tw.set_loops()
	tw.tween_callback(marker_sprite.play.bind("alert"))
	tw.tween_interval(shake)
	tw.tween_callback(marker_sprite.play.bind("calm"))
	tw.tween_interval(pause)

func _clear_marker() -> void:
	if marker_sprite != null:
		marker_sprite.queue_free()
		marker_sprite = null

# --- Camille : sprite marchant --------------------------------------------
# Même sheet FRLG que assets/characters/scientist.png (10 colonnes de 16x32,
# récupérée telle quelle depuis kanto-pipeline) et même convention de frames
# que scenes/player/player.tscn (colonnes 0-8) : 0=face sud, 1=face nord,
# 2=face ouest, 3-4=marche sud, 5-6=marche nord, 7-8=marche ouest — l'est
# réutilise les frames ouest retournées (flip_h), comme _play() sur player.gd.

func _build_walk_frames(tex: Texture2D) -> SpriteFrames:
	var regions: Array[AtlasTexture] = []
	for i in range(9):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 16, 0, 16, 32)
		regions.append(at)
	var sf := SpriteFrames.new()
	var anims := {
		"face_south": [0], "face_north": [1], "face_west": [2],
		"walk_south": [3, 0, 4, 0], "walk_north": [5, 1, 6, 1], "walk_west": [7, 2, 8, 2],
	}
	for anim_name in anims:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		sf.set_animation_speed(anim_name, 7.5)
		for idx in anims[anim_name]:
			sf.add_frame(anim_name, regions[idx])
	return sf

func _spawn_camille(player: Node, at_tile: Vector2i) -> void:
	if camille_body != null:
		return
	var tex := load("res://assets/characters/scientist.png") as Texture2D

	camille_body = StaticBody2D.new()
	camille_body.set_script(load("res://scripts/npc_camille_minidraco_hunt.gd"))
	camille_body.position = Vector2(at_tile) * player.TILE_SIZE
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)   # même gabarit que scenes/npc/npc.tscn
	collision.shape = shape
	collision.position = Vector2(8, 8)
	camille_body.add_child(collision)

	camille_sprite = AnimatedSprite2D.new()
	camille_sprite.sprite_frames = _build_walk_frames(tex)
	camille_sprite.centered = false
	camille_sprite.position = Vector2(0, -16)   # offset fixe, comme npc.gd::_ready()
	camille_body.add_child(camille_sprite)

	player.get_tree().current_scene.add_child(camille_body)
	_camille_play("face", "west")

# East réutilise les frames "west" retournées horizontalement, comme
# player.gd::_play().
func _camille_play(prefix: String, dir: String) -> void:
	if camille_sprite == null:
		return
	camille_sprite.flip_h = (dir == "east")
	var suffix := "west" if dir == "east" else dir
	camille_sprite.play(prefix + "_" + suffix)

func _clear_camille() -> void:
	if camille_body != null:
		camille_body.queue_free()   # libère aussi camille_sprite, qui en est l'enfant
		camille_body = null
		camille_sprite = null

# --- Petits utilitaires ------------------------------------------------------

func _tile_of(world_pos: Vector2, tile_size: int) -> Vector2i:
	return Vector2i(roundi(world_pos.x / tile_size), roundi(world_pos.y / tile_size))

# Trajet en L (horizontal puis vertical) entre 2 cases — pas de pathfinding
# réel, pas de vérification d'obstacle : simple pour un couloir dégagé,
# à revoir si le chemin traverse un obstacle une fois testé en jeu.
func _l_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var step := from
	while step.x != to.x:
		step.x += signi(to.x - step.x)
		path.append(step)
	while step.y != to.y:
		step.y += signi(to.y - step.y)
		path.append(step)
	return path

func _facing_for(dir: Vector2i) -> String:
	if dir.x > 0:
		return "east"
	if dir.x < 0:
		return "west"
	if dir.y > 0:
		return "south"
	if dir.y < 0:
		return "north"
	return "south"
