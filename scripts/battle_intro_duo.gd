class_name BattleIntroDuo
extends CanvasLayer

# Intro du combat duo (2v2, 4 dresseurs — voir la conversation de conception,
# zone 4 Parc Safari) : même séquence que battle_intro.gd (fondu au noir ->
# rideau qui s'ouvre -> les dresseurs glissent en place -> compteurs de
# Pokémon -> texte d'intro -> envoi des premiers Pokémon un par un), doublée
# pour afficher 2 dresseurs de chaque côté au lieu d'1. Fichier séparé plutôt
# qu'un paramétrage de battle_intro.gd : ses rects sont verrouillés ("VALIDÉ
# PAR GUS, NE PLUS RETOUCHER") pour le combat 1v1 (Yohan zone 3), un combat
# duo ne doit pas risquer de les régresser.
#
# Composant pur-code (pas de .tscn, même convention que battle_intro.gd).
#
# Index fixe pour tout le combat (même convention que duo_battle.gd) :
#   0 = joueur, 1 = allié, 2 = ennemi 1, 3 = ennemi 2
#
# Usage : var intro := BattleIntroDuo.new(); intro.player_party = [...] ;
# intro.ally_party = [...] ; intro.ally_trainer_name = "..." ;
# intro.ally_sprite_key = "..." ; intro.enemy1_party = [...] ; ... ;
# add_child(intro); await intro.play(); intro.queue_free()

@export var player_party: Array = []
@export var ally_party: Array = []
@export var ally_trainer_name := ""
@export var ally_sprite_key := ""
@export var enemy1_party: Array = []
@export var enemy1_trainer_name := ""
@export var enemy1_sprite_key := ""
@export var enemy2_party: Array = []
@export var enemy2_trainer_name := ""
@export var enemy2_sprite_key := ""

@export var fade_duration := 0.7
const SPLIT_DURATION := 0.5
const SLIDE_DURATION := 1.6
const SEAM_OVERLAP := 0.01
const SEND_OUT_SLIDE_DURATION := 0.8
const POKEBALL_SIZE := 40.0
const POKEBALL_POP_DURATION := 0.3
const BALL_CLOSED_HOLD := 0.15
const POKEMON_APPEAR_DELAY := 0.25
const POKEBALL_FLASH_DURATION := 0.35
const POKEMON_REVEAL_DURATION := 0.35
const SILHOUETTE_FADE_IN_DURATION := 0.2
const SPARKLE_COUNT := 8
const SPARKLE_SIZE := 14.0
const SPARKLE_TRAVEL := 46.0
const SPARKLE_DURATION := 0.45

const BgTexture := preload("res://assets/ui/battle_bg_neutral.png")
const PlatformTexture := preload("res://assets/ui/platform.png")
const PartyBallTexture := preload("res://assets/ui/battle_party_ball.png")
const PartyBallEmptyTexture := preload("res://assets/ui/battle_party_ball_empty.png")
const PartyBarTexture := preload("res://assets/ui/battle_party_bar.png")
const PokeballTexture := preload("res://assets/ui/pokeball_thrown.png")
const PokeballOpenTexture := preload("res://assets/ui/pokeball_thrown_open.png")
const SparkleTextures := [
	preload("res://assets/ui/pokeball_sparkle_diag.png"),
	preload("res://assets/ui/pokeball_sparkle_vert.png"),
	preload("res://assets/ui/pokeball_sparkle_horiz.png"),
]
const DialogueFont := preload("res://assets/fonts/dialogue_latin.fnt")
const GENDER_MALE_COLOR := Color(0.2, 0.501961, 0.976471)
const GENDER_FEMALE_COLOR := Color(0.976471, 0.211765, 0.501961)
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")

const PARTY_SLOTS := 6
# Même graphismes/tailles que battle_intro.gd (voir Gus : la rangée de
# Poké Ball doit être au même endroit qu'en solo, pas une taille/position
# inventée pour le duo).
const BALL_SIZE := 30.0
const BALL_PITCH := 34.0
const ROW_PADDING := Vector2(8.0, 8.0)
const BAR_WIDTH := 280.0
const BAR_HEIGHT := 26.0
const ENEMY_BAR_OFFSET_X := -60.0
const PLAYER_BAR_OFFSET_X := -30.0
const PLAYER_ROW_OFFSET_X := 100.0

# Rects (fractions d'écran) — repris tels quels de scenes/ui/duo_battle.tscn
# pour que le passage entre l'intro et l'écran de combat soit invisible
# (même principe que battle_intro.gd/trainer_battle.tscn en 1v1). Index 0-3 :
# joueur, allié, ennemi 1, ennemi 2.
const SPRITE_RECTS := [
	Rect2(0.04, 0.46, 0.22, 0.28),
	Rect2(0.28, 0.46, 0.22, 0.28),
	Rect2(0.50, 0.06, 0.22, 0.28),
	Rect2(0.74, 0.06, 0.22, 0.28),
]
const SHADOW_RECTS := [
	Rect2(0.02, 0.74, 0.26, 0.06),
	Rect2(0.26, 0.74, 0.26, 0.06),
	Rect2(0.48, 0.34, 0.26, 0.06),
	Rect2(0.72, 0.34, 0.26, 0.06),
]
# Emplacement final de la carte nom/niveau/PV de chaque Pokémon envoyé
# (distinct de la rangée de Poké Ball partagée, voir ROW_RECTS ci-dessous) —
# reprend les 4 emplacements de scenes/ui/duo_battle.tscn.
const CARD_RECTS := [
	Rect2(0.54, 0.44, 0.30, 0.105),
	Rect2(0.54, 0.565, 0.30, 0.105),
	Rect2(0.02, 0.05, 0.30, 0.105),
	Rect2(0.02, 0.175, 0.30, 0.105),
]
# Rangée de Poké Ball : UNE SEULE par camp (pas 4), au même emplacement que
# battle_intro.gd::ENEMY_COUNT_RECT/PLAYER_COUNT_RECT — vérifié dans
# pokefirered (battle_interface.c::CreatePartyStatusSummarySprites) : en
# combat multi, c'est une rangée de 6 emplacements partagée par les 2
# dresseurs d'un même camp, PAS une rangée de 6 par dresseur (voir Gus).
# [0] = camp allié (joueur+allié), [1] = camp adverse (ennemi1+ennemi2).
const ROW_RECTS := [
	Rect2(0.65, 0.63, 0.32, 0.13),
	Rect2(0.03, 0.1225, 0.33, 0.13),
]

var _root: Control
var _black_top: ColorRect
var _black_bottom: ColorRect
var _sprites: Array[TextureRect] = []
var _shadows: Array[TextureRect] = []
var _ally_row: Control
var _enemy_row: Control
var _ally_row_exited := false
var _enemy_row_exited := false
var _dialogue: Node

func _ready() -> void:
	layer = 90
	_build_ui()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = BgTexture
	bg.expand_mode = 1
	_root.add_child(bg)

	for i in range(4):
		_shadows.append(_make_tex_rect(PlatformTexture, SHADOW_RECTS[i]))
	for i in range(4):
		_sprites.append(_make_sprite_rect(SPRITE_RECTS[i]))

	var player_path := "res://assets/characters/%s_back.png" % PlayerData.appearance
	if ResourceLoader.exists(player_path):
		_sprites[0].texture = load(player_path)
	# ally_sprite_key est un chemin res:// complet vers un sprite de DOS
	# (ex. "res://assets/characters/rs_may_back.png"), pas une clé composée
	# avec assets/characters/custom/battle/ comme les 2 ennemis — l'allié se
	# tient du même côté que le joueur, il doit être vu de dos comme lui, pas
	# de face comme un portrait de dresseur adverse (signalé par Gus).
	if ally_sprite_key != "" and ResourceLoader.exists(ally_sprite_key):
		_sprites[1].texture = load(ally_sprite_key)
	_set_trainer_sprite(2, enemy1_sprite_key)
	_set_trainer_sprite(3, enemy2_sprite_key)

	_ally_row = _make_count_row(ROW_RECTS[0])
	_enemy_row = _make_count_row(ROW_RECTS[1])

	_dialogue = DialogueBoxScene.instantiate()
	_dialogue.style = "battle"
	get_tree().root.add_child(_dialogue)
	_dialogue.visible = false

	_black_top = ColorRect.new()
	_black_top.color = Color.BLACK
	_black_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_bottom = ColorRect.new()
	_black_bottom.color = Color.BLACK
	_black_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black_top)
	_root.add_child(_black_bottom)
	_set_rect(_black_top, Rect2(0.0, 0.0, 1.0, 0.5 + SEAM_OVERLAP))
	_set_rect(_black_bottom, Rect2(0.0, 0.5 - SEAM_OVERLAP, 1.0, 0.5 + SEAM_OVERLAP))
	_black_top.modulate.a = 1.0
	_black_bottom.modulate.a = 1.0

	for i in range(4):
		_sprites[i].visible = false
		_shadows[i].visible = false
	_ally_row.visible = false
	_enemy_row.visible = false

func _set_trainer_sprite(idx: int, sprite_key: String) -> void:
	if sprite_key == "":
		return
	var path := "res://assets/characters/custom/battle/%s.png" % sprite_key
	if ResourceLoader.exists(path):
		_sprites[idx].texture = load(path)

func _make_tex_rect(tex: Texture2D, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = 1
	t.stretch_mode = 0
	_root.add_child(t)
	_set_rect(t, rect)
	return t

func _make_sprite_rect(rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = 1
	t.stretch_mode = 5
	t.texture_filter = 1
	_root.add_child(t)
	_set_rect(t, rect)
	return t

func _set_rect(c: Control, rect: Rect2) -> void:
	c.anchor_left = rect.position.x
	c.anchor_top = rect.position.y
	c.anchor_right = rect.position.x + rect.size.x
	c.anchor_bottom = rect.position.y + rect.size.y
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0

func _place_centered(c: Control, rect: Rect2, size: float) -> void:
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5
	c.anchor_left = cx
	c.anchor_right = cx
	c.anchor_top = cy
	c.anchor_bottom = cy
	c.offset_left = -size * 0.5
	c.offset_right = size * 0.5
	c.offset_top = -size * 0.5
	c.offset_bottom = size * 0.5

func _make_count_row(rect: Rect2) -> Control:
	var box := Control.new()
	_root.add_child(box)
	_set_rect(box, rect)
	return box

# Rangée de 6 emplacements PARTAGÉE par les 2 dresseurs d'un même camp,
# divisée en 2 blocs de 3 (un par dresseur) — vérifié dans pokefirered
# (battle_interface.c) : chaque bloc reflète directement l'équipe de son
# dresseur (2 Pokémon + 1 vide, PUIS 1 Pokémon + 2 vides), les Poké Ball
# pleines ne sont PAS regroupées entre les 2 dresseurs. `slots_from_right`
# (voir Gus, demandé pour l'adversaire uniquement comme en 1v1) inverse
# l'ordre plein/vide À L'INTÉRIEUR de chaque bloc de 3.
func _add_count_dots(row: Control, party_a: int, party_b: int, slots_from_right: bool = false) -> void:
	var row_shift_x: float = 0.0 if slots_from_right else PLAYER_ROW_OFFSET_X
	var block_sizes := [party_a, party_b]
	for block in range(2):
		var size: int = block_sizes[block]
		for j in range(3):
			var i: int = block * 3 + j
			var is_full: bool = (j >= 3 - size) if slots_from_right else (j < size)
			var dot := TextureRect.new()
			dot.texture = PartyBallTexture if is_full else PartyBallEmptyTexture
			dot.texture_filter = 1
			dot.expand_mode = 1
			dot.stretch_mode = 5
			dot.position = ROW_PADDING + Vector2(row_shift_x + i * BALL_PITCH, 0.0)
			dot.size = Vector2(BALL_SIZE, BALL_SIZE)
			dot.pivot_offset = Vector2(BALL_SIZE, BALL_SIZE) * 0.5
			dot.scale = Vector2.ZERO
			row.add_child(dot)

	var bar := TextureRect.new()
	bar.texture = PartyBarTexture
	bar.texture_filter = 1
	bar.expand_mode = 1
	bar.stretch_mode = 5
	bar.flip_h = slots_from_right
	var bar_offset_x: float = ENEMY_BAR_OFFSET_X if slots_from_right else PLAYER_BAR_OFFSET_X
	bar.position = ROW_PADDING + Vector2(row_shift_x + bar_offset_x, BALL_SIZE)
	bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	row.add_child(bar)

# --- Séquence ---

func play() -> void:
	await _fade_to_black()
	await _split_open()
	_dialogue.visible = true
	await _slide_in_combatants()
	await _animate_counts()
	await _show_intro_text()
	# Ordre fidèle au 1v1 (l'adversaire envoie en premier) : les 2 ennemis,
	# puis le joueur et son allié.
	await _send_out(2)
	await _send_out(3)
	await _send_out(0)
	await _send_out(1)
	_dialogue.queue_free()

func _fade_to_black() -> void:
	await get_tree().create_timer(fade_duration).timeout

func _split_open() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_black_top, "anchor_top", -0.5, SPLIT_DURATION).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_black_top, "anchor_bottom", 0.0, SPLIT_DURATION).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_black_bottom, "anchor_top", 1.0, SPLIT_DURATION).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_black_bottom, "anchor_bottom", 1.5, SPLIT_DURATION).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_black_top.visible = false
	_black_bottom.visible = false

# Ennemis (2, 3) entrent depuis la gauche, joueur+allié (0, 1) depuis la
# droite — même convention que battle_intro.gd (adversaire à gauche, joueur
# à droite), doublée par côté.
func _slide_in_combatants() -> void:
	for i in range(4):
		_sprites[i].visible = true
		_shadows[i].visible = true

	for i in range(4):
		var dx: float = 1.0 if i < 2 else -1.0
		_set_rect(_sprites[i], _shifted(SPRITE_RECTS[i], dx))
		_set_rect(_shadows[i], _shifted(SHADOW_RECTS[i], dx))

	var tw := create_tween()
	tw.set_parallel(true)
	for i in range(4):
		_tween_horizontal(tw, _sprites[i], SPRITE_RECTS[i])
		_tween_horizontal(tw, _shadows[i], SHADOW_RECTS[i])
	await tw.finished

func _shifted(rect: Rect2, delta_x: float) -> Rect2:
	var r := rect
	r.position.x += delta_x
	return r

func _tween_horizontal(tw: Tween, c: Control, target: Rect2, duration: float = SLIDE_DURATION) -> void:
	tw.tween_property(c, "anchor_left", target.position.x, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "anchor_right", target.position.x + target.size.x, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_counts() -> void:
	_ally_row.visible = true
	_enemy_row.visible = true
	_add_count_dots(_ally_row, player_party.size(), ally_party.size())
	_add_count_dots(_enemy_row, enemy1_party.size(), enemy2_party.size(), true)

	for i in range(PARTY_SLOTS):
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_ally_row.get_child(i), "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_enemy_row.get_child(PARTY_SLOTS - 1 - i), "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished

func _show_intro_text() -> void:
	var lines: Array[String] = ["Un combat est lancé par %s et %s !" % [enemy1_trainer_name, enemy2_trainer_name]]
	_dialogue.say(lines, -1, 0.0, true)
	await _dialogue.finished

# --- Phase 2 : envoi du 1er Pokémon d'un dresseur ---

func _party_for(idx: int) -> Array:
	match idx:
		0:
			return player_party
		1:
			return ally_party
		2:
			return enemy1_party
		_:
			return enemy2_party

func _trainer_name_for(idx: int) -> String:
	match idx:
		1:
			return ally_trainer_name
		2:
			return enemy1_trainer_name
		3:
			return enemy2_trainer_name
		_:
			return ""

func _send_out(idx: int) -> void:
	var party: Array = _party_for(idx)
	if party.is_empty():
		return
	var entry: Dictionary = party[0]
	var species_key: String = String(entry["species"])
	var level: int = int(entry["level"])
	var species_name: String = String(SpeciesData.SPECIES[species_key]["name"])
	var gender: String = String(entry.get("gender", ""))
	var max_hp: int = BattlePokemon.create(species_key, level, [], gender).max_hp

	var trainer_sprite: TextureRect = _sprites[idx]
	var pokemon_rect: Rect2 = SPRITE_RECTS[idx]
	var card_rect: Rect2 = CARD_RECTS[idx]
	var is_ally_camp: bool = idx < 2

	var sprite_exit_dx: float = -1.0 if is_ally_camp else 1.0

	var text: String
	if idx == 0:
		text = "Vas-y, %s !" % species_name
	else:
		text = "%s est envoyé par %s !" % [species_name, _trainer_name_for(idx)]
	var lines: Array[String] = [text]
	_dialogue.say(lines)
	await _dialogue.page_typed
	_dialogue.active = false

	# La rangée de Poké Ball est PARTAGÉE par les 2 dresseurs d'un même camp
	# (voir _add_count_dots()) : elle ne quitte le terrain qu'une seule fois,
	# au premier envoi de ce camp (ennemi 1 ou joueur, voir play()) — pas à
	# chaque envoi individuel, sinon elle réapparaîtrait/disparaîtrait 2 fois.
	var row: Control = _ally_row if is_ally_camp else _enemy_row
	var row_rect: Rect2 = ROW_RECTS[0] if is_ally_camp else ROW_RECTS[1]
	var row_already_exited: bool = _ally_row_exited if is_ally_camp else _enemy_row_exited

	var exit_tw := create_tween()
	exit_tw.set_parallel(true)
	_tween_horizontal(exit_tw, trainer_sprite, _shifted(pokemon_rect, sprite_exit_dx), SEND_OUT_SLIDE_DURATION)
	if not row_already_exited:
		var row_exit_dx: float = 1.0 if _rect_center_x(row_rect) > 0.5 else -1.0
		_tween_horizontal(exit_tw, row, _shifted(row_rect, row_exit_dx), SEND_OUT_SLIDE_DURATION)
	await exit_tw.finished
	trainer_sprite.visible = false
	if not row_already_exited:
		row.visible = false
		if is_ally_camp:
			_ally_row_exited = true
		else:
			_enemy_row_exited = true

	var ball := TextureRect.new()
	ball.texture = PokeballTexture
	ball.texture_filter = 1
	ball.expand_mode = 1
	ball.stretch_mode = 5
	_root.add_child(ball)
	_place_centered(ball, pokemon_rect, POKEBALL_SIZE)
	ball.pivot_offset = Vector2(POKEBALL_SIZE, POKEBALL_SIZE) * 0.5
	ball.scale = Vector2.ZERO
	var ball_in := create_tween()
	ball_in.tween_property(ball, "scale", Vector2.ONE, POKEBALL_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await ball_in.finished
	await get_tree().create_timer(BALL_CLOSED_HOLD).timeout

	ball.texture = PokeballOpenTexture
	_spawn_pokeball_sparkles(pokemon_rect)
	var ball_out := create_tween()
	ball_out.tween_property(ball, "scale", Vector2.ZERO, POKEBALL_POP_DURATION)
	await get_tree().create_timer(POKEMON_APPEAR_DELAY).timeout
	ball.queue_free()

	trainer_sprite.texture = _load_pokemon_texture(species_key, is_ally_camp)
	_set_rect(trainer_sprite, pokemon_rect)
	trainer_sprite.modulate = Color.WHITE
	trainer_sprite.visible = true

	var silhouette := TextureRect.new()
	silhouette.texture = trainer_sprite.texture
	silhouette.expand_mode = trainer_sprite.expand_mode
	silhouette.stretch_mode = trainer_sprite.stretch_mode
	silhouette.texture_filter = 1
	silhouette.material = _make_silhouette_material()
	silhouette.modulate.a = 0.0
	_root.add_child(silhouette)
	_set_rect(silhouette, pokemon_rect)

	var appear := create_tween()
	appear.tween_property(silhouette, "modulate:a", 1.0, SILHOUETTE_FADE_IN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await appear.finished

	var reveal := create_tween()
	reveal.tween_property(silhouette, "modulate:a", 0.0, POKEMON_REVEAL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal.finished
	silhouette.queue_free()

	var card := _make_nameplate(species_name, level, max_hp, gender)
	_set_rect(card, card_rect)
	card.modulate.a = 0.0
	var card_tw := create_tween()
	card_tw.tween_property(card, "modulate:a", 1.0, 0.4)
	await card_tw.finished

func _spawn_pokeball_sparkles(rect: Rect2) -> void:
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5
	for i in range(SPARKLE_COUNT):
		var angle: float = TAU * float(i) / float(SPARKLE_COUNT)
		var spark := TextureRect.new()
		spark.texture = SparkleTextures[i % SparkleTextures.size()]
		spark.texture_filter = 1
		spark.expand_mode = 1
		spark.stretch_mode = 5
		_root.add_child(spark)
		spark.anchor_left = cx
		spark.anchor_right = cx
		spark.anchor_top = cy
		spark.anchor_bottom = cy
		spark.offset_left = -SPARKLE_SIZE * 0.5
		spark.offset_right = SPARKLE_SIZE * 0.5
		spark.offset_top = -SPARKLE_SIZE * 0.5
		spark.offset_bottom = SPARKLE_SIZE * 0.5
		spark.pivot_offset = Vector2(SPARKLE_SIZE, SPARKLE_SIZE) * 0.5
		spark.rotation = angle

		var target := Vector2(cos(angle), sin(angle)) * SPARKLE_TRAVEL
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "offset_left", spark.offset_left + target.x, SPARKLE_DURATION)
		tw.tween_property(spark, "offset_right", spark.offset_right + target.x, SPARKLE_DURATION)
		tw.tween_property(spark, "offset_top", spark.offset_top + target.y, SPARKLE_DURATION)
		tw.tween_property(spark, "offset_bottom", spark.offset_bottom + target.y, SPARKLE_DURATION)
		tw.tween_property(spark, "modulate:a", 0.0, SPARKLE_DURATION)
		tw.finished.connect(spark.queue_free)

func _rect_center_x(rect: Rect2) -> float:
	return rect.position.x + rect.size.x * 0.5

func _load_pokemon_texture(species_key: String, is_ally_camp: bool) -> Texture2D:
	var suffix := "back" if is_ally_camp else "front"
	var path := "res://assets/pokemon/%s/%s.png" % [species_key, suffix]
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _make_silhouette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _add_gender_label(parent: HBoxContainer, gender: String) -> void:
	if gender != "male" and gender != "female":
		return
	var label := Label.new()
	label.text = " ♂" if gender == "male" else " ♀"
	label.add_theme_font_override("font", DialogueFont)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", GENDER_MALE_COLOR if gender == "male" else GENDER_FEMALE_COLOR)
	parent.add_child(label)

func _make_nameplate(pokemon_name: String, level: int, max_hp: int, gender: String) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 0.870588, 1)
	style.set_border_width_all(3)
	style.border_color = Color(0.12549, 0.223529, 0, 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style)
	_root.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	box.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = pokemon_name
	name_label.add_theme_font_override("font", DialogueFont)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(name_label)

	_add_gender_label(name_row, gender)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(spacer)

	var level_label := Label.new()
	level_label.text = "N.%d" % level
	level_label.add_theme_font_override("font", DialogueFont)
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(level_label)

	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(0, 10)
	hp_bg.color = Color(0.321569, 0.415686, 0.352941, 1)
	vbox.add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_fill.offset_left = 2.0
	hp_fill.offset_top = 2.0
	hp_fill.offset_right = -2.0
	hp_fill.offset_bottom = -2.0
	hp_fill.color = Color(0.45098, 1, 0.67451, 1)
	hp_bg.add_child(hp_fill)

	var hp_text := Label.new()
	hp_text.text = "%d/%d" % [max_hp, max_hp]
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_text.add_theme_font_override("font", DialogueFont)
	hp_text.add_theme_font_size_override("font_size", 16)
	hp_text.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(hp_text)

	return box
