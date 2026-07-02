extends CharacterBody2D

const SPEED = 48  # pixels per second (tune this)
const TILE_SIZE = 16

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var is_moving := false
var move_target := Vector2.ZERO
var move_direction := "down"

func _ready() -> void:
	move_target = position
	anim.play("idle_down")

func _physics_process(delta: float) -> void:
	if is_moving:
		_move_toward_target(delta)
	else:
		_check_input()

func _check_input() -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_down"):
		dir = Vector2(0, 1)
		move_direction = "down"
	elif Input.is_action_pressed("ui_up"):
		dir = Vector2(0, -1)
		move_direction = "up"
	elif Input.is_action_pressed("ui_left"):
		dir = Vector2(-1, 0)
		move_direction = "left"
	elif Input.is_action_pressed("ui_right"):
		dir = Vector2(1, 0)
		move_direction = "right"

	if dir != Vector2.ZERO:
		move_target = position + dir * TILE_SIZE
		is_moving = true
		anim.play("walk_" + move_direction)
	else:
		anim.play("idle_" + move_direction)

func _move_toward_target(delta: float) -> void:
	var diff := move_target - position
	var step := SPEED * delta
	if diff.length() <= step:
		position = move_target
		is_moving = false
	else:
		position += diff.normalized() * step
		velocity = diff.normalized() * SPEED
		move_and_slide()
