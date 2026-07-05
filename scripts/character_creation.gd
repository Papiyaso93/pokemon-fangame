extends Control

signal creation_finished

enum { STEP_GENDER, STEP_NAME, STEP_APPEARANCE }
var step := STEP_GENDER
var chosen_appearance_index := 0

@onready var prompt: Label = $Center/Content/Prompt
@onready var gender_box: HBoxContainer = $Center/Content/GenderBox
@onready var name_box: VBoxContainer = $Center/Content/NameBox
@onready var name_edit: LineEdit = $Center/Content/NameBox/NameEdit
@onready var appearance_box: HBoxContainer = $Center/Content/AppearanceBox
@onready var appearance_left: TextureButton = $Center/Content/AppearanceBox/Left
@onready var appearance_right: TextureButton = $Center/Content/AppearanceBox/Right

func _ready() -> void:
	name_edit.max_length = PlayerData.NAME_MAX_LENGTH
	_show_step(STEP_GENDER)

func _show_step(s: int) -> void:
	step = s
	gender_box.visible = s == STEP_GENDER
	name_box.visible = s == STEP_NAME
	appearance_box.visible = s == STEP_APPEARANCE
	match s:
		STEP_GENDER:
			prompt.text = "Es-tu un garçon ou une fille ?"
		STEP_NAME:
			prompt.text = "Quel est ton nom ? (%d caractères max)" % PlayerData.NAME_MAX_LENGTH
			name_edit.text = ""
			name_edit.grab_focus()
		STEP_APPEARANCE:
			prompt.text = "Choisis ton apparence."
			_load_appearance_previews()

func _on_boy_pressed() -> void:
	PlayerData.gender = "male"
	_show_step(STEP_NAME)

func _on_girl_pressed() -> void:
	PlayerData.gender = "female"
	_show_step(STEP_NAME)

func _on_name_confirmed(_text := "") -> void:
	var n := name_edit.text.strip_edges()
	if n.is_empty():
		return
	PlayerData.player_name = n
	_show_step(STEP_APPEARANCE)

func _load_appearance_previews() -> void:
	var options: Array = PlayerData.APPEARANCES[PlayerData.gender]
	appearance_left.texture_normal = _face_preview(options[0])
	appearance_right.texture_normal = _face_preview(options[1])

func _face_preview(sprite_name: String) -> AtlasTexture:
	var tex := load("res://assets/characters/%s.png" % sprite_name) as Texture2D
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, 16, 32)   # frame 0 : face sud, debout
	return at

func _on_appearance_left_pressed() -> void:
	PlayerData.appearance = PlayerData.APPEARANCES[PlayerData.gender][0]
	creation_finished.emit()

func _on_appearance_right_pressed() -> void:
	PlayerData.appearance = PlayerData.APPEARANCES[PlayerData.gender][1]
	creation_finished.emit()
