extends CharacterBody2D

# Déplacement fidèle FRLG (case par case, 60 px/s, tap-to-turn) + transitions
# entre maps quand on franchit un bord connecté.
const SPEED := 60.0
const TILE_SIZE := 16
const TURN_TIME := 0.1

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

enum { NOT_MOVING, TURNING, MOVING }
var state := NOT_MOVING
var is_moving := false
var move_target := Vector2.ZERO
var facing := "south"     # south / north / west / east
var turn_timer := 0.0

var map_size := Vector2i(1000, 1000)
var connections: Array = []

func _ready() -> void:
	_read_map_meta()
	# Arrivée via une transition : on se place au bon bord de la nouvelle map.
	if Transitions.pending:
		facing = Transitions.facing
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

func _entry_tile(from_dir: String, cross: int) -> Vector2i:
	match from_dir:
		"up":   return Vector2i(cross, map_size.y - 1)   # sorti par le haut -> entre en bas
		"down": return Vector2i(cross, 0)                # sorti par le bas -> entre en haut
		"left": return Vector2i(map_size.x - 1, cross)   # entre à droite
		_:      return Vector2i(0, cross)                # entre à gauche

func _physics_process(delta: float) -> void:
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

	var motion := dir * TILE_SIZE
	if test_move(global_transform, motion):
		_play("face")            # bloqué : face à l'obstacle, sans avancer
	else:
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
	var step := SPEED * delta
	if diff.length() <= step:
		position = move_target
		is_moving = false
	else:
		position += diff.normalized() * step

# East réutilise les frames "west" retournées horizontalement.
func _play(prefix: String) -> void:
	anim.flip_h = (facing == "east")
	var suffix := "west" if facing == "east" else facing
	anim.play(prefix + "_" + suffix)
