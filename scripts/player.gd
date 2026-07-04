extends CharacterBody2D

# Déplacement fidèle FRLG : case par case, 60 px/s (1 tuile / 16 frames),
# avec tap-to-turn (une direction nouvelle fait d'abord pivoter sur place).
const SPEED := 60.0
const TILE_SIZE := 16
const TURN_TIME := 0.1   # durée du pivot sur place

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

enum { NOT_MOVING, TURNING, MOVING }
var state := NOT_MOVING
var is_moving := false
var move_target := Vector2.ZERO
var facing := "south"     # south / north / west / east
var turn_timer := 0.0

func _ready() -> void:
	move_target = position
	_play("face")

func _physics_process(delta: float) -> void:
	# Pendant le pivot : on attend, et si on relâche on reste juste tourné.
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

	# Marche
	facing = want
	state = MOVING
	var motion := dir * TILE_SIZE
	if test_move(global_transform, motion):
		_play("face")            # bloqué : face à l'obstacle, sans avancer
	else:
		move_target = position + motion
		is_moving = true
		_play("walk")

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
