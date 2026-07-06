extends CanvasLayer

# Bandeau du nom de lieu, fidèle FRLG (pret src/map_name_popup.c) : se déroule
# depuis le haut-gauche de l'écran (même fenêtre "standard" que les menus de
# choix, pas le cadre ondulé des dialogues), reste ~2s, puis se réenroule.

const REST_Y := 20.0
const SLIDE_DURATION := 0.25
const HOLD_DURATION := 1.8

@onready var window: PanelContainer = $Root/Window
@onready var label: Label = $Root/Window/Label

func show_name(map_name: String) -> void:
	label.text = map_name
	await get_tree().process_frame
	var h := window.size.y
	window.position = Vector2(window.position.x, -h)

	var tw_in := create_tween()
	tw_in.tween_property(window, "position:y", REST_Y, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	await get_tree().create_timer(HOLD_DURATION).timeout

	var tw_out := create_tween()
	tw_out.tween_property(window, "position:y", -h, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw_out.finished
	queue_free()
