extends CanvasLayer

# Fondu noir plein écran (autoload, persiste entre les scènes). Fidèle FRLG
# (pret `WarpFadeInScreen` dans field_fadetransition.c : fondu au noir avant un
# warp, refondu après) — sert aussi à masquer le petit temps de construction du
# monde seamless (`_load_world()`) pendant un changement de carte par warp,
# pour éviter la saccade visible en entrant/sortant d'un bâtiment.
const FADE_TIME := 0.15

var rect: ColorRect

func _ready() -> void:
	layer = 100
	rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)

func fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, FADE_TIME)
	await tw.finished

func fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, FADE_TIME)
	await tw.finished
