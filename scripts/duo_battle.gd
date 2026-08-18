extends CanvasLayer

# Écran de combat duo (2v2, 4 dresseurs distincts — voir la conversation de
# conception, zone 4 Parc Safari) : le joueur et un allié (IA) affrontent 2
# dresseurs adverses (IA), chacun envoyant 1 Pokémon actif à la fois depuis
# sa propre équipe. Généralise trainer_battle.gd (1v1) à 4 côtés indexés
# 0..3 au lieu d'un simple booléen is_player :
#   0 = joueur (contrôlé), 1 = allié (IA), 2 = ennemi 1 (IA), 3 = ennemi 2 (IA)
# Pilote battle_engine_duo.gd (BattleEngineDuo) au lieu de battle_engine.gd —
# même pattern (resolve_turn() pur, liste d'évènements rejouée un par un),
# mais avec ciblage manuel : une attaque doit préciser QUEL adversaire elle
# vise (2 possibles), pas implicitement "l'unique adversaire" comme en 1v1.
#
# Propriétés à poser AVANT add_child() (même convention que trainer_battle.gd) :
#   player_entries : Array[{"species","level","moves"}] — équipe du joueur
#   ally_entries / ally_trainer_name : équipe + nom de l'allié IA
#   enemy1_entries / enemy1_trainer_name, enemy2_entries / enemy2_trainer_name
#   pre_turn_hook : Callable(int) -> void, optionnel (même rôle qu'en 1v1)

signal finished(result: String)

signal _choice_made(value)
var _switch_cancel_enabled := false

const FRENCH_TYPE_NAMES := {
	"NORMAL": "Normal",
	"FIRE": "Feu",
	"WATER": "Eau",
	"GRASS": "Plante",
	"FIGHTING": "Combat",
}
const FRENCH_CATEGORY_NAMES := {
	"PHYSICAL": "Physique",
	"SPECIAL": "Spéciale",
	"STATUS": "Statut",
}

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const DialogueFont := preload("res://assets/fonts/dialogue_latin.fnt")
const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const ListPickerScene := preload("res://scenes/ui/list_picker.tscn")

const PokeballTexture := preload("res://assets/ui/pokeball_thrown.png")
const PokeballOpenTexture := preload("res://assets/ui/pokeball_thrown_open.png")
const SparkleTextures := [
	preload("res://assets/ui/pokeball_sparkle_diag.png"),
	preload("res://assets/ui/pokeball_sparkle_vert.png"),
	preload("res://assets/ui/pokeball_sparkle_horiz.png"),
]
const POKEBALL_SIZE := 40.0
const POKEBALL_POP_DURATION := 0.3
const BALL_CLOSED_HOLD := 0.15
const POKEMON_APPEAR_DELAY := 0.25
const SILHOUETTE_FADE_IN_DURATION := 0.2
const POKEMON_REVEAL_DURATION := 0.35
const SPARKLE_COUNT := 8
const SPARKLE_SIZE := 14.0
const SPARKLE_TRAVEL := 46.0
const SPARKLE_DURATION := 0.45

# Mêmes sprites d'effet d'attaque que trainer_battle.gd (voir
# kanto-pipeline/build_move_effects.py) — dupliqués ici plutôt que partagés
# via un fichier commun, même convention que le reste de cet écran (chaque
# écran de combat reste autonome).
const ImpactTexture := preload("res://assets/effects/moves/impact.png")
const ScratchTexture1 := preload("res://assets/effects/moves/scratch_1.png")
const ScratchTexture2 := preload("res://assets/effects/moves/scratch_2.png")
const ChopFistTexture := preload("res://assets/effects/moves/chop_fist.png")
const RapidSpinTexture1 := preload("res://assets/effects/moves/rapid_spin_1.png")
const RapidSpinTexture2 := preload("res://assets/effects/moves/rapid_spin_2.png")
const EmberTexture1 := preload("res://assets/effects/moves/ember_1.png")
const EmberTexture2 := preload("res://assets/effects/moves/ember_2.png")
const EmberTexture3 := preload("res://assets/effects/moves/ember_3.png")
const WaterDropletTexture := preload("res://assets/effects/moves/water_droplet.png")
const WaterSplashTexture := preload("res://assets/effects/moves/water_splash.png")
const VineTexture := preload("res://assets/effects/moves/vine.png")
const LeafTexture1 := preload("res://assets/effects/moves/leaf_1.png")
const LeafTexture2 := preload("res://assets/effects/moves/leaf_2.png")
const LeafTexture3 := preload("res://assets/effects/moves/leaf_3.png")
const RazorLeafTexture := preload("res://assets/effects/moves/razor_leaf.png")
const RaindropTexture := preload("res://assets/effects/moves/raindrop.png")

const RAIN_OVERLAY_COLOR := Color(0.08, 0.12, 0.32, 0.28)
const RAIN_OVERLAY_FADE_DURATION := 0.4
const RAIN_DROP_INTERVAL := 0.12
const RAIN_DROP_FALL_DURATION := 0.55

var player_entries: Array = []
var ally_entries: Array = []
var ally_trainer_name := ""
var enemy1_entries: Array = []
var enemy1_trainer_name := ""
var enemy2_entries: Array = []
var enemy2_trainer_name := ""
var pre_turn_hook: Callable = Callable()

# sides[0]=joueur sides[1]=allié sides[2]=ennemi1 sides[3]=ennemi2 — index
# fixe pour tout le combat, voir battle_engine_duo.gd.
var sides: Array[BattleSide] = []
var engine: BattleEngineDuo
var _turn_number := 0
var _empty_button_style: StyleBoxEmpty

@onready var _root: Control = $Root
@onready var _player_sprite_node: TextureRect = $Root/PlayerSprite
@onready var _ally_sprite_node: TextureRect = $Root/AllySprite
@onready var _enemy1_sprite_node: TextureRect = $Root/Enemy1Sprite
@onready var _enemy2_sprite_node: TextureRect = $Root/Enemy2Sprite

@onready var _player_health_box_node: PanelContainer = $Root/PlayerHealthBox
@onready var _player_name_label_node: Label = $Root/PlayerHealthBox/VBox/NameRow/NameLabel
@onready var _player_gender_label_node: Label = $Root/PlayerHealthBox/VBox/NameRow/GenderLabel
@onready var _player_level_label_node: Label = $Root/PlayerHealthBox/VBox/NameRow/LevelLabel
@onready var _player_hp_fill_node: ColorRect = $Root/PlayerHealthBox/VBox/HPBarBg/HPBarFill
@onready var _player_hp_label_node: Label = $Root/PlayerHealthBox/VBox/HPTextLabel

@onready var _ally_health_box_node: PanelContainer = $Root/AllyHealthBox
@onready var _ally_name_label_node: Label = $Root/AllyHealthBox/VBox/NameRow/NameLabel
@onready var _ally_gender_label_node: Label = $Root/AllyHealthBox/VBox/NameRow/GenderLabel
@onready var _ally_level_label_node: Label = $Root/AllyHealthBox/VBox/NameRow/LevelLabel
@onready var _ally_hp_fill_node: ColorRect = $Root/AllyHealthBox/VBox/HPBarBg/HPBarFill
@onready var _ally_hp_label_node: Label = $Root/AllyHealthBox/VBox/HPTextLabel

@onready var _enemy1_health_box_node: PanelContainer = $Root/Enemy1HealthBox
@onready var _enemy1_name_label_node: Label = $Root/Enemy1HealthBox/VBox/NameRow/NameLabel
@onready var _enemy1_gender_label_node: Label = $Root/Enemy1HealthBox/VBox/NameRow/GenderLabel
@onready var _enemy1_level_label_node: Label = $Root/Enemy1HealthBox/VBox/NameRow/LevelLabel
@onready var _enemy1_hp_fill_node: ColorRect = $Root/Enemy1HealthBox/VBox/HPBarBg/HPBarFill
@onready var _enemy1_hp_label_node: Label = $Root/Enemy1HealthBox/VBox/HPTextLabel

@onready var _enemy2_health_box_node: PanelContainer = $Root/Enemy2HealthBox
@onready var _enemy2_name_label_node: Label = $Root/Enemy2HealthBox/VBox/NameRow/NameLabel
@onready var _enemy2_gender_label_node: Label = $Root/Enemy2HealthBox/VBox/NameRow/GenderLabel
@onready var _enemy2_level_label_node: Label = $Root/Enemy2HealthBox/VBox/NameRow/LevelLabel
@onready var _enemy2_hp_fill_node: ColorRect = $Root/Enemy2HealthBox/VBox/HPBarBg/HPBarFill
@onready var _enemy2_hp_label_node: Label = $Root/Enemy2HealthBox/VBox/HPTextLabel

@onready var _action_window: PanelContainer = $Root/ActionWindow
@onready var _menu_container: Control = $Root/ActionWindow/MenuBox

# Tableaux indexés 0..3 (voir plus haut) — assemblés en _ready() à partir des
# @onready ci-dessus, pour que toute la logique par la suite (animations,
# rafraîchissement) prenne un simple side_index plutôt qu'un nom de nœud.
var _sprites: Array[TextureRect] = []
var _sprite_base_y: Array[float] = []
var _health_boxes: Array[PanelContainer] = []
var _name_labels: Array[Label] = []
var _gender_labels: Array[Label] = []
var _level_labels: Array[Label] = []
var _hp_fills: Array[ColorRect] = []
var _hp_labels: Array[Label] = []

var _prompt_dialogue: Node = null
var _action_layer: CanvasLayer = null
var _battle_dialogue: Node = null

var _rain_overlay: ColorRect = null
var _rain_timer: Timer = null

func _ready() -> void:
	layer = 90
	_empty_button_style = StyleBoxEmpty.new()
	_empty_button_style.content_margin_left = 8.0
	_empty_button_style.content_margin_top = 4.0
	_empty_button_style.content_margin_right = 8.0
	_empty_button_style.content_margin_bottom = 4.0

	sides = [
		_build_side(player_entries, 0, ""),
		_build_side(ally_entries, 0, ally_trainer_name),
		_build_side(enemy1_entries, 1, enemy1_trainer_name),
		_build_side(enemy2_entries, 1, enemy2_trainer_name),
	]
	engine = BattleEngineDuo.new(sides)

	_sprites = [_player_sprite_node, _ally_sprite_node, _enemy1_sprite_node, _enemy2_sprite_node]
	_health_boxes = [_player_health_box_node, _ally_health_box_node, _enemy1_health_box_node, _enemy2_health_box_node]
	_name_labels = [_player_name_label_node, _ally_name_label_node, _enemy1_name_label_node, _enemy2_name_label_node]
	_gender_labels = [_player_gender_label_node, _ally_gender_label_node, _enemy1_gender_label_node, _enemy2_gender_label_node]
	_level_labels = [_player_level_label_node, _ally_level_label_node, _enemy1_level_label_node, _enemy2_level_label_node]
	_hp_fills = [_player_hp_fill_node, _ally_hp_fill_node, _enemy1_hp_fill_node, _enemy2_hp_fill_node]
	_hp_labels = [_player_hp_label_node, _ally_hp_label_node, _enemy1_hp_label_node, _enemy2_hp_label_node]

	for i in range(4):
		_sprite_base_y.append(_sprites[i].position.y)
	for i in range(4):
		_refresh_sprite(i)
	for i in range(4):
		_refresh_health(i)

	# Même piège/correctif que trainer_battle.gd::_ready() : ActionWindow doit
	# ressortir dans son propre CanvasLayer à un layer supérieur à celui de la
	# boîte de dialogue (95) pour rester visible par-dessus.
	_action_layer = CanvasLayer.new()
	_action_layer.layer = 96
	get_tree().root.add_child(_action_layer)
	_action_window.reparent(_action_layer)
	_action_window.visible = false

	await _run_battle_loop()

func _build_side(entries: Array, team: int, trainer_name: String) -> BattleSide:
	var side := BattleSide.new()
	side.team = team
	side.trainer_name = trainer_name
	for e in entries:
		var moves: Array[String] = []
		for m in e["moves"]:
			moves.append(String(m))
		var gender := String(e.get("gender", ""))
		side.party.append(BattlePokemon.create(String(e["species"]), int(e["level"]), moves, gender))
	return side

# --- Rafraîchissement visuel ---

func _refresh_sprite(idx: int) -> void:
	var pkm: BattlePokemon = sides[idx].active()
	var suffix := "back" if sides[idx].team == 0 else "front"
	var path := "res://assets/pokemon/%s/%s.png" % [pkm.species_key, suffix]
	if ResourceLoader.exists(path):
		_sprites[idx].texture = load(path)
	_sprites[idx].modulate.a = 1.0
	_sprites[idx].position.y = _sprite_base_y[idx]

func _play_faint_animation(idx: int) -> void:
	var sprite: TextureRect = _sprites[idx]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "position:y", sprite.position.y + 50.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_health_boxes[idx].visible = false

func _play_send_out_animation(idx: int) -> void:
	var sprite: TextureRect = _sprites[idx]
	var pkm: BattlePokemon = sides[idx].active()
	var suffix := "back" if sides[idx].team == 0 else "front"
	var path := "res://assets/pokemon/%s/%s.png" % [pkm.species_key, suffix]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null

	sprite.visible = false
	sprite.modulate.a = 1.0
	sprite.position.y = _sprite_base_y[idx]

	var center := sprite.position + sprite.size * 0.5

	var ball := TextureRect.new()
	ball.texture = PokeballTexture
	ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_root.add_child(ball)
	ball.anchor_left = 0.0
	ball.anchor_top = 0.0
	ball.offset_left = center.x - POKEBALL_SIZE * 0.5
	ball.offset_top = center.y - POKEBALL_SIZE * 0.5
	ball.offset_right = ball.offset_left + POKEBALL_SIZE
	ball.offset_bottom = ball.offset_top + POKEBALL_SIZE
	ball.pivot_offset = Vector2(POKEBALL_SIZE, POKEBALL_SIZE) * 0.5
	ball.scale = Vector2.ZERO

	var ball_in := create_tween()
	ball_in.tween_property(ball, "scale", Vector2.ONE, POKEBALL_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await ball_in.finished
	await get_tree().create_timer(BALL_CLOSED_HOLD).timeout

	ball.texture = PokeballOpenTexture
	_spawn_pokeball_sparkles(center)
	var ball_out := create_tween()
	ball_out.tween_property(ball, "scale", Vector2.ZERO, POKEBALL_POP_DURATION)
	await get_tree().create_timer(POKEMON_APPEAR_DELAY).timeout
	ball.queue_free()

	sprite.texture = texture
	sprite.modulate = Color.WHITE
	sprite.visible = true

	var silhouette := TextureRect.new()
	silhouette.texture = texture
	silhouette.expand_mode = sprite.expand_mode
	silhouette.stretch_mode = sprite.stretch_mode
	silhouette.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	silhouette.material = _make_silhouette_material()
	silhouette.modulate.a = 0.0
	_root.add_child(silhouette)
	silhouette.anchor_left = 0.0
	silhouette.anchor_top = 0.0
	silhouette.offset_left = sprite.position.x
	silhouette.offset_top = sprite.position.y
	silhouette.offset_right = sprite.position.x + sprite.size.x
	silhouette.offset_bottom = sprite.position.y + sprite.size.y

	var appear := create_tween()
	appear.tween_property(silhouette, "modulate:a", 1.0, SILHOUETTE_FADE_IN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await appear.finished
	var reveal := create_tween()
	reveal.tween_property(silhouette, "modulate:a", 0.0, POKEMON_REVEAL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal.finished
	silhouette.queue_free()

func _spawn_pokeball_sparkles(center: Vector2) -> void:
	for i in range(SPARKLE_COUNT):
		var angle: float = TAU * float(i) / float(SPARKLE_COUNT)
		var spark := TextureRect.new()
		spark.texture = SparkleTextures[i % SparkleTextures.size()]
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_root.add_child(spark)
		spark.anchor_left = 0.0
		spark.anchor_top = 0.0
		spark.offset_left = center.x - SPARKLE_SIZE * 0.5
		spark.offset_top = center.y - SPARKLE_SIZE * 0.5
		spark.offset_right = spark.offset_left + SPARKLE_SIZE
		spark.offset_bottom = spark.offset_top + SPARKLE_SIZE
		spark.pivot_offset = Vector2(SPARKLE_SIZE, SPARKLE_SIZE) * 0.5
		spark.rotation = angle

		var target := Vector2(cos(angle), sin(angle)) * SPARKLE_TRAVEL
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "offset_left", spark.offset_left + target.x, SPARKLE_DURATION)
		tw.tween_property(spark, "offset_right", spark.offset_right + target.x, SPARKLE_DURATION)
		tw.tween_property(spark, "offset_top", spark.offset_top + target.y, SPARKLE_DURATION)
		tw.tween_property(spark, "offset_bottom", spark.offset_bottom + target.y, SPARKLE_DURATION)
		tw.tween_property(spark, "modulate:a", 0.0, SPARKLE_DURATION).set_delay(SPARKLE_DURATION * 0.4)
		tw.chain().tween_callback(spark.queue_free)

func _make_silhouette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _play_hit_animation(idx: int) -> void:
	var sprite: TextureRect = _sprites[idx]
	var base_x := sprite.position.x
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0), 0.06)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tw.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0), 0.06)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tw.parallel().tween_property(sprite, "position:x", base_x - 8.0, 0.05)
	tw.tween_property(sprite, "position:x", base_x + 8.0, 0.08)
	tw.tween_property(sprite, "position:x", base_x, 0.06)
	await tw.finished

# +1 pour le camp allié (0/1, en bas de l'écran, avance vers le haut), -1
# pour le camp adverse (2/3, en haut, avance vers le bas) — généralise le
# is_player bool de trainer_battle.gd (qui ne distinguait que 2 côtés).
func _team_sign(idx: int) -> float:
	return 1.0 if sides[idx].team == 0 else -1.0

func _play_lunge_animation(idx: int) -> void:
	var sprite: TextureRect = _sprites[idx]
	var base_x := sprite.position.x
	var dx := 24.0 * _team_sign(idx)
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", base_x + dx, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:x", base_x, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

# --- Animations d'attaque par capacité (voir trainer_battle.gd pour le
# détail de conception de chacune — reprises ici avec un attaquant/une
# cible explicites au lieu d'un simple is_player, puisqu'une attaque peut
# viser l'un ou l'autre des 2 adversaires) ---

func _sprite_center(idx: int) -> Vector2:
	return _sprites[idx].position + _sprites[idx].size * 0.5

func _spawn_effect_sprite(texture: Texture2D, center: Vector2, size: float) -> TextureRect:
	var fx := TextureRect.new()
	fx.texture = texture
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.size = Vector2(size, size)
	fx.position = center - fx.size * 0.5
	fx.pivot_offset = fx.size * 0.5
	_root.add_child(fx)
	return fx

func _play_move_animation(attacker_idx: int, target_idx: int, move_key: String) -> void:
	match move_key:
		"TACKLE":
			await _play_tackle_animation(attacker_idx, target_idx)
		"SCRATCH":
			await _play_scratch_animation(attacker_idx, target_idx)
		"KARATE_CHOP":
			await _play_karate_chop_animation(attacker_idx, target_idx)
		"RAPID_SPIN":
			await _play_rapid_spin_animation(attacker_idx, target_idx)
		"EMBER":
			await _play_ember_animation(attacker_idx, target_idx)
		"WATER_GUN":
			await _play_water_gun_animation(attacker_idx, target_idx)
		"VINE_WHIP":
			await _play_vine_whip_animation(attacker_idx, target_idx)
		"RAZOR_LEAF":
			await _play_razor_leaf_animation(attacker_idx, target_idx)
		"RAIN_DANCE":
			await _play_rain_dance_animation(attacker_idx)
		_:
			await _play_lunge_animation(attacker_idx)

func _play_tackle_animation(attacker_idx: int, target_idx: int) -> void:
	await _play_lunge_animation(attacker_idx)
	var fx := _spawn_effect_sprite(ImpactTexture, _sprite_center(target_idx), 90.0)
	fx.scale = Vector2(0.4, 0.4)
	fx.pivot_offset = fx.size * 0.5
	var tw := create_tween()
	tw.tween_property(fx, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.06)
	tw.tween_property(fx, "modulate:a", 0.0, 0.14)
	await tw.finished
	fx.queue_free()

func _play_scratch_animation(_attacker_idx: int, target_idx: int) -> void:
	var center := _sprite_center(target_idx)
	for texture in [ScratchTexture1, ScratchTexture2]:
		var fx := _spawn_effect_sprite(texture, center, 90.0)
		fx.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(fx, "modulate:a", 1.0, 0.05)
		tw.tween_interval(0.1)
		tw.tween_property(fx, "modulate:a", 0.0, 0.12)
		await tw.finished
		fx.queue_free()

func _play_karate_chop_animation(attacker_idx: int, target_idx: int) -> void:
	var sign := _team_sign(attacker_idx)
	var target_center := _sprite_center(target_idx)
	var start := target_center + Vector2(-38.0 * sign, -14.0)
	var end := target_center + Vector2(38.0 * sign, 14.0)
	var fx := _spawn_effect_sprite(ChopFistTexture, start, 64.0)
	fx.rotation = -0.5 * sign
	var tw := create_tween()
	tw.tween_property(fx, "position", end - fx.size * 0.5, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.16).set_delay(0.08)
	var target_sprite: TextureRect = _sprites[target_idx]
	var flash := create_tween()
	flash.tween_property(target_sprite, "modulate", Color(3.0, 3.0, 3.0), 0.06)
	flash.tween_property(target_sprite, "modulate", Color.WHITE, 0.08)
	await tw.finished
	fx.queue_free()

func _play_rapid_spin_animation(attacker_idx: int, target_idx: int) -> void:
	var center := _sprite_center(attacker_idx)
	var textures := [RapidSpinTexture1, RapidSpinTexture2]
	for i in range(5):
		var fx := _spawn_effect_sprite(textures[i % 2], center, 90.0)
		fx.rotation = randf_range(-0.3, 0.3)
		await get_tree().create_timer(0.09).timeout
		fx.queue_free()
	var impact := _spawn_effect_sprite(ImpactTexture, _sprite_center(target_idx), 80.0)
	var tw := create_tween()
	tw.tween_interval(0.04)
	tw.tween_property(impact, "modulate:a", 0.0, 0.16)
	await tw.finished
	impact.queue_free()

func _play_ember_animation(attacker_idx: int, target_idx: int) -> void:
	var from := _sprite_center(attacker_idx)
	var to := _sprite_center(target_idx)
	for texture in [EmberTexture1, EmberTexture2, EmberTexture3]:
		var fx := _spawn_effect_sprite(texture, from, 40.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(fx, "position", to - fx.size * 0.5, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(fx, "size", Vector2(56.0, 56.0), 0.24)
		tw.chain().tween_property(fx, "modulate:a", 0.0, 0.1)
		tw.tween_callback(fx.queue_free)
		await get_tree().create_timer(0.09).timeout
	await get_tree().create_timer(0.2).timeout

func _play_water_gun_animation(attacker_idx: int, target_idx: int) -> void:
	var from := _sprite_center(attacker_idx)
	var to := _sprite_center(target_idx)
	var drop := _spawn_effect_sprite(WaterDropletTexture, from, 40.0)
	var tw := create_tween()
	tw.tween_property(drop, "position", to - drop.size * 0.5, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	drop.queue_free()
	var splash := _spawn_effect_sprite(WaterSplashTexture, to, 90.0)
	splash.scale = Vector2(0.5, 0.5)
	splash.pivot_offset = splash.size * 0.5
	var splash_tw := create_tween()
	splash_tw.tween_property(splash, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	splash_tw.tween_interval(0.05)
	splash_tw.tween_property(splash, "modulate:a", 0.0, 0.14)
	await splash_tw.finished
	splash.queue_free()

func _play_vine_whip_animation(attacker_idx: int, target_idx: int) -> void:
	var from := _sprite_center(attacker_idx)
	var to := _sprite_center(target_idx)
	var vine := _spawn_effect_sprite(VineTexture, from, 110.0)
	vine.scale = Vector2(0.3, 0.3)
	vine.pivot_offset = vine.size * 0.5
	var out_tw := create_tween()
	out_tw.set_parallel(true)
	out_tw.tween_property(vine, "position", to - vine.size * 0.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	out_tw.tween_property(vine, "scale", Vector2.ONE, 0.2)
	await out_tw.finished
	var back_tw := create_tween()
	back_tw.set_parallel(true)
	back_tw.tween_property(vine, "position", from - vine.size * 0.5, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	back_tw.tween_property(vine, "modulate:a", 0.0, 0.16).set_delay(0.05)
	await back_tw.finished
	vine.queue_free()

func _play_razor_leaf_animation(attacker_idx: int, target_idx: int) -> void:
	var attacker_center := _sprite_center(attacker_idx)
	for texture in [LeafTexture1, LeafTexture2, LeafTexture3]:
		var offset := Vector2(randf_range(-30.0, 30.0), randf_range(-38.0, -8.0))
		var leaf := _spawn_effect_sprite(texture, attacker_center + offset, 34.0)
		leaf.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(leaf, "modulate:a", 1.0, 0.05)
		tw.tween_interval(0.09)
		tw.tween_property(leaf, "modulate:a", 0.0, 0.09)
		tw.tween_callback(leaf.queue_free)
		await get_tree().create_timer(0.08).timeout

	var to := _sprite_center(target_idx)
	var sign := _team_sign(attacker_idx)
	var cutter := _spawn_effect_sprite(RazorLeafTexture, attacker_center, 100.0)
	cutter.rotation = 0.0 if sign > 0.0 else PI
	var tw := create_tween()
	tw.tween_property(cutter, "position", to - cutter.size * 0.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(cutter, "rotation", cutter.rotation + 0.6 * sign, 0.2)
	await tw.finished
	cutter.queue_free()

func _play_rain_dance_animation(attacker_idx: int) -> void:
	var center := _sprite_center(attacker_idx)
	for i in range(4):
		var offset := Vector2(randf_range(-34.0, 34.0), -40.0)
		var drop := _spawn_effect_sprite(RaindropTexture, center + offset, 20.0)
		var tw := create_tween()
		tw.tween_property(drop, "position:y", drop.position.y + 55.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(drop, "modulate:a", 0.0, 0.3).set_delay(0.12)
		tw.tween_callback(drop.queue_free)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.15).timeout

# --- Pluie ambiante (persiste tant que battle_engine_duo.gd signale RAIN) ---

func _start_ambient_rain() -> void:
	if _rain_overlay != null:
		return
	_rain_overlay = ColorRect.new()
	_rain_overlay.color = RAIN_OVERLAY_COLOR
	_rain_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain_overlay.modulate.a = 0.0
	_rain_overlay.anchor_right = 1.0
	_rain_overlay.anchor_bottom = 1.0
	_root.add_child(_rain_overlay)
	_root.move_child(_rain_overlay, 1)
	var tw := create_tween()
	tw.tween_property(_rain_overlay, "modulate:a", 1.0, RAIN_OVERLAY_FADE_DURATION)

	_rain_timer = Timer.new()
	_rain_timer.wait_time = RAIN_DROP_INTERVAL
	_root.add_child(_rain_timer)
	_rain_timer.timeout.connect(_spawn_ambient_raindrop)
	_rain_timer.start()

func _stop_ambient_rain() -> void:
	if _rain_timer != null:
		_rain_timer.queue_free()
		_rain_timer = null
	if _rain_overlay != null:
		var overlay := _rain_overlay
		_rain_overlay = null
		var tw := create_tween()
		tw.tween_property(overlay, "modulate:a", 0.0, RAIN_OVERLAY_FADE_DURATION)
		tw.tween_callback(overlay.queue_free)

func _spawn_ambient_raindrop() -> void:
	var bounds := get_viewport().get_visible_rect().size
	var x := randf_range(8.0, bounds.x - 8.0)
	var drop := _spawn_effect_sprite(RaindropTexture, Vector2(x, -10.0), 16.0)
	var tw := create_tween()
	tw.tween_property(drop, "position:y", bounds.y + 10.0, RAIN_DROP_FALL_DURATION).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(drop.queue_free)

const GENDER_MALE_COLOR := Color(0.2, 0.501961, 0.976471)
const GENDER_FEMALE_COLOR := Color(0.976471, 0.211765, 0.501961)

func _set_gender_label(label: Label, gender: String) -> void:
	if gender == "male":
		label.text = " ♂"
		label.add_theme_color_override("font_color", GENDER_MALE_COLOR)
	elif gender == "female":
		label.text = " ♀"
		label.add_theme_color_override("font_color", GENDER_FEMALE_COLOR)
	else:
		label.text = ""

func _refresh_health(idx: int, animate: bool = false) -> void:
	_health_boxes[idx].visible = true
	var pkm: BattlePokemon = sides[idx].active()
	_name_labels[idx].text = pkm.display_name
	_set_gender_label(_gender_labels[idx], pkm.gender)
	_level_labels[idx].text = "N.%d" % pkm.level
	_hp_labels[idx].text = "%d/%d" % [pkm.current_hp, pkm.max_hp]
	_set_hp_bar(_hp_fills[idx], pkm, animate)

func _set_hp_bar(fill: ColorRect, pkm: BattlePokemon, animate: bool) -> void:
	var ratio: float = float(pkm.current_hp) / float(pkm.max_hp) if pkm.max_hp > 0 else 0.0
	var target := Vector2(maxf(ratio, 0.0), 1.0)
	fill.pivot_offset = Vector2.ZERO
	if animate:
		var tw := create_tween()
		tw.tween_property(fill, "scale", target, 0.3)
	else:
		fill.scale = target
	fill.color = Color(0.45098, 1, 0.67451, 1) if ratio > 0.2 else Color(1.0, 0.4, 0.35, 1.0)

# Suffixe pour désambiguïser les noms dans les messages de combat (voir
# trainer_battle.gd, qui n'avait que " ennemi" à gérer côté 1v1) : 4 côtés
# ici, donc l'allié et les 2 ennemis (noms de dresseur potentiellement
# différents) doivent être identifiables séparément.
func _side_suffix(idx: int) -> String:
	match idx:
		0:
			return ""
		1:
			return " allié"
		_:
			return " (%s)" % sides[idx].trainer_name

func _open_prompt(text: String) -> void:
	_close_prompt()
	if _battle_dialogue != null:
		_battle_dialogue.visible = false
	_prompt_dialogue = DialogueBoxScene.instantiate()
	_prompt_dialogue.style = "battle"
	get_tree().root.add_child(_prompt_dialogue)
	var lines: Array[String] = [text]
	_prompt_dialogue.say(lines)
	await _prompt_dialogue.page_typed
	_prompt_dialogue.active = false
	_action_window.visible = true

func _close_prompt() -> void:
	_action_window.visible = false
	if _prompt_dialogue != null:
		_prompt_dialogue.queue_free()
		_prompt_dialogue = null

# --- Boucle de combat ---

func _run_battle_loop() -> void:
	while true:
		_turn_number += 1
		if pre_turn_hook.is_valid():
			await pre_turn_hook.call(_turn_number)

		var player_action := await _prompt_player_action()
		_close_prompt()
		var actions: Array[Dictionary] = [
			player_action,
			engine.choose_ai_action(1),
			engine.choose_ai_action(2),
			engine.choose_ai_action(3),
		]
		var events := engine.resolve_turn(actions)
		var result := await _play_events(events)
		if result != "":
			_finish(result)
			return

		# Switch automatique des IA (allié/ennemis) après K.O., comme
		# battle_engine.gd::auto_switch_enemy_if_fainted() en 1v1 — le switch
		# forcé du joueur (index 0) passe par un vrai menu, plus bas.
		for i in [1, 2, 3]:
			if sides[i].active().is_fainted():
				engine.auto_switch_if_fainted(i)
				if not sides[i].active().is_fainted():
					await _say(["%s envoie %s !" % [sides[i].trainer_name, sides[i].active().display_name]])
					_refresh_sprite(i)
					_refresh_health(i)
					await _play_send_out_animation(i)

		if sides[0].active().is_fainted() and sides[0].has_alive():
			await ScreenFade.fade_out()
			var idx := await _prompt_switch(true, true)
			# resolve_turn() attend une action pour les 4 côtés — les 3 autres
			# n'ont rien à faire ici (seul le joueur switche de force après un
			# K.O.), donc un switch "sur soi-même" en no-op pour eux (même
			# correctif que trainer_battle.gd pour le 1v1 : passer un mauvais
			# index réassignerait leur active_index par erreur). Résultat
			# ignoré volontairement (pas de _play_events) : ce n'est pas un
			# vrai tour, juste l'application du switch forcé.
			engine.resolve_turn([
				{"kind": "switch", "index": idx},
				{"kind": "switch", "index": sides[1].active_index},
				{"kind": "switch", "index": sides[2].active_index},
				{"kind": "switch", "index": sides[3].active_index},
			])
			_refresh_sprite(0)
			await _say(["Vas-y, %s !" % sides[0].active().display_name])
			_refresh_health(0)
			await _play_send_out_animation(0)

func _finish(result: String) -> void:
	_stop_ambient_rain()
	finished.emit(result)
	if _action_layer != null:
		_action_layer.queue_free()
	if _battle_dialogue != null:
		_battle_dialogue.queue_free()
	queue_free()

func _play_events(events: Array[Dictionary]) -> String:
	for ev in events:
		match String(ev["type"]):
			"switch":
				var side_idx: int = int(ev["side"])
				if side_idx == 0:
					await _say(["Vas-y, %s !" % sides[0].active().display_name])
				_refresh_health(side_idx)
				await _play_send_out_animation(side_idx)
			"move_used":
				var attacker_idx: int = int(ev["side"])
				var target_idx: int = int(ev["target_side"])
				var attacker_name: String = String(ev["pokemon"]) + _side_suffix(attacker_idx)
				await _say(["%s utilise %s !" % [attacker_name, String(ev["move"])]])
				await _play_move_animation(attacker_idx, target_idx, String(ev["move_key"]))
			"message":
				await _say([String(ev["text"])])
			"hp_changed":
				var side_idx: int = int(ev["side"])
				_refresh_health(side_idx, true)
				if not bool(ev["residual"]):
					_play_hit_animation(side_idx)
				await get_tree().create_timer(0.3).timeout
			"status":
				await _say(["%s est brûlé !" % (String(ev["pokemon"]) + _side_suffix(int(ev["side"])))])
			"weather_changed":
				if String(ev["weather"]) == "RAIN":
					await _say(["Le temps se met à changer... il commence à pleuvoir !"])
					_start_ambient_rain()
				else:
					await _say(["La pluie s'arrête."])
					_stop_ambient_rain()
			"pokemon_fainted":
				var side_idx: int = int(ev["side"])
				await _play_faint_animation(side_idx)
				await _say(["%s est mis K.O. !" % (String(ev["pokemon"]) + _side_suffix(side_idx))])
			"battle_ended":
				return String(ev["result"])
	return ""

func _say(lines: Array[String]) -> void:
	if _battle_dialogue == null:
		_battle_dialogue = DialogueBoxScene.instantiate()
		_battle_dialogue.style = "battle"
		get_tree().root.add_child(_battle_dialogue)
	_battle_dialogue.say(lines, -1, 0.0, true)
	await _battle_dialogue.finished
	_battle_dialogue.visible = true

# --- Menus ---

func _clear_menu() -> void:
	for c in _menu_container.get_children():
		c.queue_free()

# Retourne {"kind": "attack", "move_key": ..., "target": int} ou
# {"kind": "switch", "index": ...}. `target` = index dans sides[] de
# l'adversaire visé — choisi automatiquement s'il n'en reste qu'un vivant,
# sinon via un sous-menu de ciblage (voir _prompt_target()).
func _prompt_player_action() -> Dictionary:
	var need_new_prompt := true
	while true:
		if need_new_prompt:
			await _open_prompt("Que doit faire %s ?" % sides[0].active().display_name)
		need_new_prompt = true
		_clear_menu()

		var grid := GridContainer.new()
		grid.columns = 2
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 2)
		var attack_btn := _menu_button("ATTAQUE")
		var bag_btn := _menu_button("SAC")
		var switch_btn := _menu_button("POKÉMON")
		var run_btn := _menu_button("FUITE")
		for b in [attack_btn, bag_btn, switch_btn, run_btn]:
			grid.add_child(b)
		_menu_container.add_child(grid)
		attack_btn.grab_focus()

		attack_btn.pressed.connect(func(): _choice_made.emit(0))
		bag_btn.pressed.connect(func(): _choice_made.emit(1))
		switch_btn.pressed.connect(func(): _choice_made.emit(2))
		run_btn.pressed.connect(func(): _choice_made.emit(3))
		var choice: int = await _choice_made

		match choice:
			0:
				var move_key := await _prompt_move_choice()
				if move_key != "":
					var move: Dictionary = MoveData.MOVES[move_key]
					if String(move["effect"]) == "EFFECT_RAIN_DANCE":
						return {"kind": "attack", "move_key": move_key, "target": 0}
					var alive_targets: Array[int] = []
					for idx in engine.opposing_indices(0):
						if not sides[idx].active().is_fainted():
							alive_targets.append(idx)
					if alive_targets.size() == 1:
						return {"kind": "attack", "move_key": move_key, "target": alive_targets[0]}
					var picked := await _prompt_target(alive_targets)
					if picked != -1:
						return {"kind": "attack", "move_key": move_key, "target": picked}
					# Ciblage annulé -> retombe au menu principal, comme une
					# annulation du choix de capacité (voir plus bas).
				need_new_prompt = false
			1:
				_close_prompt()
				await _say(["Impossible d'utiliser un objet en combat officiel !"])
			2:
				var idx := await _prompt_switch(false)
				if idx >= 0:
					return {"kind": "switch", "index": idx}
				need_new_prompt = false
			3:
				_close_prompt()
				await _say(["Tu ne peux pas fuir un combat de dresseur !"])
		# Sous-menu annulé, ou Sac/Fuite refusés : on reboucle et réaffiche le menu.
	return {}   # inatteignable (while true ne sort que par un return ci-dessus), pour l'analyseur statique

# Sous-menu de ciblage (2 options : les 2 adversaires vivants), affiché via
# ListPickerScene (déjà utilisé ailleurs dans le jeu, voir title_screen.gd)
# plutôt qu'un écran dédié — layer explicite car ListPickerScene est à son
# layer par défaut (1), qui serait masqué sous celui de ce combat (90) et de
# sa fenêtre d'action (96) sans ça. Retourne -1 si annulé (Échap).
func _prompt_target(candidates: Array[int]) -> int:
	_action_window.visible = false
	var options: Array = []
	for idx in candidates:
		var pkm: BattlePokemon = sides[idx].active()
		options.append({"label": "%s  PV %d/%d" % [pkm.display_name, pkm.current_hp, pkm.max_hp], "value": idx})
	var picker := ListPickerScene.instantiate()
	picker.layer = 97
	get_tree().root.add_child(picker)
	picker.setup(options)
	var chosen = await picker.chosen
	picker.queue_free()
	_action_window.visible = true
	return -1 if chosen == null else int(chosen)

func _prompt_move_choice() -> String:
	if _prompt_dialogue != null:
		_prompt_dialogue.visible = false

	var move_box := _make_move_list_box()
	var grid: GridContainer = move_box.get_child(0)

	_clear_menu()
	var pp_label := _info_label(28)
	var type_category_label := _info_label(28)
	var info_box := VBoxContainer.new()
	info_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_box.add_theme_constant_override("separation", 8)
	info_box.add_child(pp_label)
	info_box.add_child(type_category_label)
	_menu_container.add_child(info_box)

	var moves: Array[Dictionary] = sides[0].active().moves
	var first: Button = null
	for i in range(4):
		if i < moves.size():
			var mv: Dictionary = moves[i]
			var key: String = String(mv["key"])
			var move: Dictionary = MoveData.MOVES[key]
			var btn := _menu_button(String(move["name"]), 28)
			var pp_text := "PP  %d/%d" % [int(mv["pp_current"]), int(mv["pp_max"])]
			var type_name: String = FRENCH_TYPE_NAMES.get(String(move["type"]), String(move["type"]))
			var category_name: String = FRENCH_CATEGORY_NAMES.get(String(move["category"]), String(move["category"]))
			var type_category_text := "%s / %s" % [type_name, category_name]
			btn.focus_entered.connect(func():
				pp_label.text = pp_text
				type_category_label.text = type_category_text
			)
			btn.pressed.connect(func(): _choice_made.emit(key))
			grid.add_child(btn)
			if first == null:
				first = btn
				pp_label.text = pp_text
				type_category_label.text = type_category_text
		else:
			var empty_btn := _menu_button("-", 28)
			empty_btn.disabled = true
			empty_btn.focus_mode = Control.FOCUS_NONE
			grid.add_child(empty_btn)

	_switch_cancel_enabled = true
	if first:
		first.grab_focus()
	var chosen: Variant = await _choice_made
	_switch_cancel_enabled = false
	move_box.queue_free()
	_clear_menu()
	if _prompt_dialogue != null:
		_prompt_dialogue.visible = true
	return "" if chosen is int and chosen == -1 else String(chosen)

func _make_move_list_box() -> PanelContainer:
	var box := PanelContainer.new()
	box.theme = _action_window.theme
	box.add_theme_stylebox_override("panel", _action_window.get_theme_stylebox("panel"))
	_action_layer.add_child(box)
	box.anchor_left = 0.02
	box.anchor_top = _action_window.anchor_top
	box.anchor_right = _action_window.anchor_left - 0.02
	box.anchor_bottom = _action_window.anchor_bottom
	box.offset_left = 0.0
	box.offset_top = 0.0
	box.offset_right = 0.0
	box.offset_bottom = 0.0

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	return box

func _info_label(font_size: int = 20) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", DialogueFont)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _prompt_switch(forced: bool, and_fade_in: bool = false) -> int:
	_clear_menu()
	if _prompt_dialogue != null:
		_prompt_dialogue.visible = false

	var sel := PartySelect.new()
	sel.party = sides[0].party
	sel.active_index = sides[0].active_index
	sel.forced = forced
	get_tree().root.add_child(sel)
	if and_fade_in:
		await ScreenFade.fade_in()
	var idx: int = await sel.pick()
	sel.queue_free()

	if _prompt_dialogue != null:
		_prompt_dialogue.visible = true
	return idx

func _unhandled_input(event: InputEvent) -> void:
	if _switch_cancel_enabled and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_choice_made.emit(-1)

func _menu_button(text: String, font_size: int = 22) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", DialogueFont)
	btn.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, _empty_button_style)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.icon = BlankTexture
	btn.mouse_entered.connect(func(): btn.grab_focus())
	btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
	btn.focus_exited.connect(func(): btn.icon = BlankTexture)
	return btn
