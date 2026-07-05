extends CharacterBody2D

# Déplacement fidèle FRLG (case par case, 60 px/s, tap-to-turn) + transitions
# entre maps quand on franchit un bord connecté.
const SPEED := 60.0
const JUMP_SPEED := 120.0   # rebord : saut de 2 cases, plus rapide qu'un pas normal
const TILE_SIZE := 16
const TURN_TIME := 0.1

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

enum { NOT_MOVING, TURNING, MOVING }
var state := NOT_MOVING
var is_moving := false
var is_busy := false   # true pendant un dialogue : ignore déplacement/interaction
var move_target := Vector2.ZERO
var facing := "south"     # south / north / west / east
var turn_timer := 0.0

var map_size := Vector2i(1000, 1000)
var connections: Array = []
var ledges: Array = []
var warps: Array = []
var current_speed := SPEED
var is_jumping := false
var jump_total_dist := 0.0
const JUMP_ARC_HEIGHT := 6.0   # pixels, arc visuel du saut de rebord

func _ready() -> void:
	add_to_group("player")
	_read_map_meta()
	# Arrivée via une transition : on se place au bon endroit de la nouvelle map.
	if Transitions.pending:
		facing = Transitions.facing
		if Transitions.direct:
			position = Vector2(Transitions.direct_tile) * TILE_SIZE
		else:
			position = Vector2(_entry_tile(Transitions.from_dir, Transitions.cross)) * TILE_SIZE
		Transitions.pending = false
	move_target = position
	_play("face")

func _read_map_meta() -> void:
	var root := get_parent()
	if root and root.has_meta("map_size"):
		map_size = root.get_meta("map_size")
	if root and root.has_meta("connections"):
		connections = root.get_meta("connections")
	if root and root.has_meta("ledges"):
		ledges = root.get_meta("ledges")
	if root and root.has_meta("warps"):
		warps = root.get_meta("warps")

# Warp ponctuel sur cette case (porte, entrée de grotte...), ou null si aucun.
func _warp_at(tile: Vector2i) -> Dictionary:
	for w in warps:
		if int(w.get("x", -1)) == tile.x and int(w.get("y", -1)) == tile.y:
			return w
	return {}

# Direction du rebord sur cette case ("down"/"up"/"left"/"right"), ou "" si aucun.
func _ledge_dir_at(tile: Vector2i) -> String:
	if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
		return ""
	var idx := tile.y * map_size.x + tile.x
	if idx < 0 or idx >= ledges.size():
		return ""
	return String(ledges[idx])

func _entry_tile(from_dir: String, cross: int) -> Vector2i:
	match from_dir:
		"up":   return Vector2i(cross, map_size.y - 1)   # sorti par le haut -> entre en bas
		"down": return Vector2i(cross, 0)                # sorti par le bas -> entre en haut
		"left": return Vector2i(map_size.x - 1, cross)   # entre à droite
		_:      return Vector2i(0, cross)                # entre à gauche

var interact_cooldown := 0.0   # évite de ré-ouvrir un dialogue avec la touche qui vient de le fermer

func _physics_process(delta: float) -> void:
	if interact_cooldown > 0.0:
		interact_cooldown -= delta
	if is_busy:
		return
	if is_moving == false and turn_timer <= 0.0 and interact_cooldown <= 0.0 and Input.is_action_just_pressed("ui_accept"):
		_try_interact()
		return
	if turn_timer > 0.0:
		turn_timer -= delta
		if _input_dir() == Vector2.ZERO:
			state = NOT_MOVING
			turn_timer = 0.0
		return
	if is_moving:
		_move_toward_target(delta)
	else:
		_check_input()

func _input_dir() -> Vector2:
	if Input.is_action_pressed("ui_down"):
		return Vector2(0, 1)
	if Input.is_action_pressed("ui_up"):
		return Vector2(0, -1)
	if Input.is_action_pressed("ui_left"):
		return Vector2(-1, 0)
	if Input.is_action_pressed("ui_right"):
		return Vector2(1, 0)
	return Vector2.ZERO

func _facing_offset(f: String) -> Vector2i:
	match f:
		"south": return Vector2i(0, 1)
		"north": return Vector2i(0, -1)
		"west":  return Vector2i(-1, 0)
		_:       return Vector2i(1, 0)

const INTERACT_RANGE := 2   # portée en cases (permet de parler par-dessus un comptoir)

func _try_interact() -> void:
	var cur := Vector2i(roundi(position.x / TILE_SIZE), roundi(position.y / TILE_SIZE))
	var offset := _facing_offset(facing)
	var npcs := get_tree().get_nodes_in_group("npc")
	for dist in range(1, INTERACT_RANGE + 1):
		var target_tile := cur + offset * dist
		for npc in npcs:
			if npc.tile() == target_tile:
				_talk_to(npc)
				return

func _talk_to(npc: Node) -> void:
	var lines: Array[String] = npc.get_lines()
	if lines.is_empty():
		return
	is_busy = true
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.finished.connect(func():
		dialogue.queue_free()
		is_busy = false
		interact_cooldown = 0.2
	)
	dialogue.say(lines)

func _facing_for(dir: Vector2) -> String:
	if dir.y > 0:
		return "south"
	if dir.y < 0:
		return "north"
	if dir.x < 0:
		return "west"
	return "east"

func _dir_name(dir: Vector2) -> String:
	if dir.y < 0:
		return "up"
	if dir.y > 0:
		return "down"
	if dir.x < 0:
		return "left"
	return "right"

func _check_input() -> void:
	var dir := _input_dir()
	if dir == Vector2.ZERO:
		state = NOT_MOVING
		_play("face")
		return

	var want := _facing_for(dir)
	# Nouvelle direction à l'arrêt : on pivote sans avancer (tap-to-turn).
	if want != facing and state != MOVING:
		facing = want
		state = TURNING
		turn_timer = TURN_TIME
		_play("face")
		return

	facing = want
	state = MOVING

	# Bord de map franchi ? -> transition si connexion vers une scène existante.
	var cur := Vector2i(roundi(position.x / TILE_SIZE), roundi(position.y / TILE_SIZE))
	var tgt := cur + Vector2i(int(dir.x), int(dir.y))
	if tgt.x < 0 or tgt.y < 0 or tgt.x >= map_size.x or tgt.y >= map_size.y:
		_try_transition(dir, cur)
		return

	# Warp ponctuel (porte, entrée de grotte) : téléportation à coord précise.
	var warp := _warp_at(tgt)
	if not warp.is_empty():
		var root := get_parent()
		# Point d'extension : la map peut verrouiller certains warps (ex. scène
		# scriptée) en implémentant gate_check()/on_gate_blocked().
		if root and root.has_method("gate_check") and not root.gate_check(warp):
			if root.has_method("on_gate_blocked"):
				root.on_gate_blocked(warp, self)
			return
		var target := String(warp.get("target", ""))
		var path := "res://scenes/maps/%s.tscn" % target
		if ResourceLoader.exists(path):
			Transitions.pending = true
			Transitions.direct = true
			Transitions.facing = String(warp.get("face", facing))
			Transitions.direct_tile = Vector2i(int(warp.get("tx", 0)), int(warp.get("ty", 0)))
			get_tree().change_scene_to_file(path)
			return

	# Rebord franchissable dans ce sens : saut de 2 cases (fidèle à FRLG),
	# on ignore la collision du rebord lui-même.
	var dname := _dir_name(dir)
	if _ledge_dir_at(tgt) == dname:
		current_speed = JUMP_SPEED
		is_jumping = true
		jump_total_dist = TILE_SIZE * 2
		move_target = position + dir * TILE_SIZE * 2
		is_moving = true
		_play("walk")
		return

	var motion := dir * TILE_SIZE
	if test_move(global_transform, motion):
		_play("face")            # bloqué : face à l'obstacle, sans avancer
	else:
		current_speed = SPEED
		is_jumping = false
		move_target = position + motion
		is_moving = true
		_play("walk")

func _try_transition(dir: Vector2, cur: Vector2i) -> void:
	var dname := _dir_name(dir)
	for c in connections:
		if String(c.get("dir")) == dname:
			var target := String(c.get("target", ""))
			var path := "res://scenes/maps/%s.tscn" % target
			if ResourceLoader.exists(path):
				var off := int(c.get("offset", 0))
				Transitions.pending = true
				Transitions.direct = false
				Transitions.from_dir = dname
				Transitions.facing = facing
				if dname == "up" or dname == "down":
					Transitions.cross = int(cur.x - off)
				else:
					Transitions.cross = int(cur.y - off)
				get_tree().change_scene_to_file(path)
				return
	_play("face")   # pas de connexion utilisable : mur

func _move_toward_target(delta: float) -> void:
	var diff := move_target - position
	var step := current_speed * delta
	if diff.length() <= step:
		position = move_target
		is_moving = false
		if is_jumping:
			is_jumping = false
			anim.position.y = 0.0
	else:
		position += diff.normalized() * step
	if is_jumping:
		var progress := 1.0 - (move_target - position).length() / jump_total_dist
		anim.position.y = -JUMP_ARC_HEIGHT * sin(progress * PI)

# East réutilise les frames "west" retournées horizontalement.
func _play(prefix: String) -> void:
	anim.flip_h = (facing == "east")
	var suffix := "west" if facing == "east" else facing
	anim.play(prefix + "_" + suffix)
