extends CanvasLayer

# Choix de l'apparence : exception au principe "fenêtre" des autres écrans
# (demandé par Gus) — les 2 sprites sont affichés en grand, en plein milieu
# de l'écran, sans fenêtre autour. Une petite flèche clignotante apparaît
# au-dessus du personnage survolé, comme indice de sélection (même texture
# que la flèche "suite" de dialogue_box.gd/le défilement de partner_choice.gd).

signal chosen(index: int)

const ARROW_TEXTURES := [
	preload("res://assets/ui/down_arrow_3.png"),
	preload("res://assets/ui/down_arrow_4.png"),
]
const ARROW_BLINK := 0.3

@onready var left_btn: TextureButton = $Root/Center/HBox/LeftBox/Left
@onready var right_btn: TextureButton = $Root/Center/HBox/RightBox/Right
@onready var left_arrow: TextureRect = $Root/Center/HBox/LeftBox/LeftArrow
@onready var right_arrow: TextureRect = $Root/Center/HBox/RightBox/RightArrow

var arrow_frame := 0
var arrow_timer := 0.0
var hovering_left := false
var hovering_right := false

func _ready() -> void:
	left_btn.pressed.connect(func(): chosen.emit(0))
	right_btn.pressed.connect(func(): chosen.emit(1))
	left_btn.mouse_entered.connect(func(): hovering_left = true)
	left_btn.mouse_exited.connect(func(): hovering_left = false; left_arrow.modulate.a = 0.0)
	right_btn.mouse_entered.connect(func(): hovering_right = true)
	right_btn.mouse_exited.connect(func(): hovering_right = false; right_arrow.modulate.a = 0.0)

# À appeler juste après instanciation.
func setup(options: Array) -> void:
	left_btn.texture_normal = _face_preview(options[0])
	right_btn.texture_normal = _face_preview(options[1])

func _face_preview(sprite_name: String) -> AtlasTexture:
	var tex := load("res://assets/characters/%s.png" % sprite_name) as Texture2D
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, 16, 32)   # frame 0 : face sud, debout
	return at

func _process(delta: float) -> void:
	if not (hovering_left or hovering_right):
		return
	arrow_timer += delta
	if arrow_timer >= ARROW_BLINK:
		arrow_timer = 0.0
		arrow_frame = 1 - arrow_frame
		var tex = ARROW_TEXTURES[arrow_frame]
		if hovering_left:
			left_arrow.texture = tex
			left_arrow.modulate.a = 1.0
		if hovering_right:
			right_arrow.texture = tex
			right_arrow.modulate.a = 1.0
