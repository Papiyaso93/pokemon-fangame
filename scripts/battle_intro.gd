class_name BattleIntro
extends CanvasLayer

# Intro complète d'un combat dresseur (voir la conversation de conception),
# en 2 phases :
# 1. "Lancement du combat" : écran noir (déjà opaque dès la construction du
#    composant, pas de fondu progressif — voir _build_ui()/_fade_to_black())
#    -> l'écran s'ouvre en deux horizontalement -> le dresseur adverse et le
#    joueur glissent en place (plateforme comprise) -> compteur de Pokémon
#    de chaque équipe -> "Un combat est lancé par X !" -> attente d'une touche.
# 2. "Envoi des premiers Pokémon" : pour l'adversaire puis le joueur, dans
#    cet ordre (fidèle au vrai jeu) — message "X est envoyé par Y !" -> le
#    dresseur et son compteur de Pokémon quittent le terrain, chacun vers
#    l'extérieur -> une Poké Ball apparaît à l'emplacement du dresseur,
#    s'ouvre -> le Pokémon apparaît progressivement (silhouette sombre puis
#    sprite) -> la carte nom/niveau/PV glisse en place.
#
# Composant pur-code (pas de .tscn : tout est construit dans _build_ui()) et
# volontairement générique — un seul combat dresseur (Yohan zone 3) l'utilise
# aujourd'hui, mais rien ici ne connaît "Yohan". Seules les propriétés
# ci-dessous changent d'un combat à l'autre ; le reste (positions, timings)
# est fixe et réutilisable tel quel.
#
# Usage : var intro := BattleIntro.new(); intro.enemy_trainer_name = "..." ;
# intro.enemy_party = [...] ; intro.player_party = [...] ; ... ;
# add_child(intro); await intro.play(); intro.queue_free()

@export var enemy_trainer_name := ""
@export var enemy_sprite_key := ""   # res://assets/characters/custom/battle/<key>.png
# {"species", "level", "moves"} par entrée, même format que
# trainer_data.gd::TRAINERS/PLAYER_LOAN_TEAM — seul le premier élément de
# chaque équipe sert à la phase 2 (envoi du premier Pokémon), le reste ne
# sert qu'à compter les emplacements pleins du compteur de la phase 1.
@export var enemy_party: Array = []
@export var player_party: Array = []

# Durée du fondu au noir initial, pensée pour être allongée plus tard sur les
# combats importants (Gus a mentionné des motifs de fondu différents selon
# l'importance du combat dans le vrai jeu) — seule la durée est réglable ici,
# aucun motif animé n'est implémenté, uniquement un fondu uni.
@export var fade_duration := 0.7
const SPLIT_DURATION := 0.5
const SLIDE_DURATION := 1.6
const SEAM_OVERLAP := 0.01   # voir _build_ui() : évite un interstice d'1px à la jointure des 2 rects noirs
const SEND_OUT_SLIDE_DURATION := 0.8   # sorties/entrées de la phase 2
const POKEBALL_SIZE := 40.0            # icône centrée sur l'emplacement du Pokémon, pas étirée pour le remplir
const POKEBALL_POP_DURATION := 0.3
const BALL_CLOSED_HOLD := 0.15         # temps où la balle reste visiblement fermée avant l'ouverture
const POKEMON_APPEAR_DELAY := 0.25     # temps où la balle ouverte reste visible seule avant que le Pokémon apparaisse
const ENEMY_BALL_OFFSET_Y := 20.0      # décale la Poké Ball adverse vers le bas (uniquement ce côté, voir Gus)
const POKEBALL_FLASH_DURATION := 0.35
const POKEMON_REVEAL_DURATION := 0.35
const SILHOUETTE_FADE_IN_DURATION := 0.2
const SPARKLE_COUNT := 8
const SPARKLE_SIZE := 14.0
const SPARKLE_TRAVEL := 46.0
const SPARKLE_DURATION := 0.45

# Fond neutre (gris très clair, rayures discrètes) dérivé de
# battle_bg_grass.png par désaturation totale — battle_bg_grass.png reste tel
# quel pour l'écran de capture Safari (encounter.tscn), où le vert reste
# pertinent (rencontre en hautes herbes) ; ce fond-ci est propre aux combats
# dresseur (voir la conversation de conception, Gus ne voulait plus aucune
# dominante verte ici).
const BgTexture := preload("res://assets/ui/battle_bg_neutral.png")
const PlatformTexture := preload("res://assets/ui/platform.png")
# Extraits depuis kanto-pipeline/pokefirered/graphics/battle_interface/ (voir
# la conversation de conception) : healthbox_elements.png tuiles 66/67 (états
# "pleine"/"vide" de l'icône Poké Ball du compteur de résumé d'équipe,
# B_INTERFACE_GFX_BALL_PARTY_SUMMARY dans battle_interface.c) et
# party_summary_bar.png (le trait qui souligne la rangée) — recadrés et
# rendus transparents (l'index de palette 0 du jeu original, exporté en noir
# opaque par le pipeline, redevient alpha=0) à la main, pas de script de
# build dédié pour 3 si petites images.
const PartyBallTexture := preload("res://assets/ui/battle_party_ball.png")
const PartyBallEmptyTexture := preload("res://assets/ui/battle_party_ball_empty.png")
const PartyBarTexture := preload("res://assets/ui/battle_party_bar.png")
# Icône de Poké Ball "lancée" (recadrée depuis
# kanto-pipeline/pokefirered/graphics/interface/ball/poke.png, fond blanc
# rendu transparent par flood-fill depuis les bords — le blanc du fond et le
# blanc de l'éclat sur la balle ne sont pas la même zone contiguë).
const PokeballTexture := preload("res://assets/ui/pokeball_thrown.png")
# 2e des 3 frames empilées dans le même fichier source (poke.png, 16x48 —
# fermée / en train de s'ouvrir / vide) : la balle "ouverte", jusque-là
# jamais utilisée (on ne montrait que la balle fermée qui disparaissait
# directement, sans jamais s'ouvrir à l'écran).
const PokeballOpenTexture := preload("res://assets/ui/pokeball_thrown_open.png")
# Éclats qui jaillissent de la Poké Ball à l'ouverture — 3 frames recadrées
# depuis graphics/battle_anims/sprites/particles.png (couleur clé
# RGB(98,41,255) rendue transparente), reprenant sAnim_RegularBall
# (battle_anim_special.c, utilisée par BALL_POKE) : diagonale, verticale et
# horizontale, dispersées en éventail plutôt que rejouées en place comme le
# fait le vrai jeu (cyclage d'anim sprite par sprite) — rendu équivalent en
# beaucoup plus simple à orchestrer avec de simples Tween.
const SparkleTextures := [
	preload("res://assets/ui/pokeball_sparkle_diag.png"),
	preload("res://assets/ui/pokeball_sparkle_vert.png"),
	preload("res://assets/ui/pokeball_sparkle_horiz.png"),
]
const DialogueFont := preload("res://assets/fonts/dialogue_latin.fnt")
# Couleurs du symbole de sexe façon vrai jeu — même valeurs dans
# trainer_battle.gd, à garder synchronisées.
const GENDER_MALE_COLOR := Color(0.2, 0.501961, 0.976471)
const GENDER_FEMALE_COLOR := Color(0.976471, 0.211765, 0.501961)
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")

const PARTY_SLOTS := 6   # toujours 6 emplacements affichés, vides au-delà de la taille réelle de l'équipe
const BALL_SIZE := 30.0
const BALL_PITCH := 34.0
const ROW_PADDING := Vector2(8.0, 8.0)   # décalage depuis le coin haut-gauche du cadre réservé (ENEMY_COUNT_RECT/PLAYER_COUNT_RECT)
# VALIDÉ PAR GUS, NE PLUS RETOUCHER (2026-08-16) : taille (280x26) et
# position (décalages ci-dessous) de la barre sous les Poké Ball jugées
# parfaites après plusieurs itérations.
const BAR_WIDTH := 280.0
const BAR_HEIGHT := 26.0
# Décalage horizontal de la barre par rapport à sa position par défaut
# (ROW_PADDING.x = 8) — négatif = vers la gauche. Adversaire décalé plus
# fort que joueur, voir Gus.
const ENEMY_BAR_OFFSET_X := -60.0
const PLAYER_BAR_OFFSET_X := -30.0
# Décale toute la rangée du joueur (balles + barre) vers la droite, voir Gus.
const PLAYER_ROW_OFFSET_X := 100.0

# Rectangles anchor (left, top, width, height) en fractions d'écran — repris
# tels quels de scenes/ui/trainer_battle.tscn pour que le dresseur adverse et
# le joueur arrivent exactement là où l'écran de combat les attend ensuite
# (aucun "saut" visuel au passage de ce composant à trainer_battle.tscn).
# VALIDÉ PAR GUS, NE PLUS RETOUCHER (2026-08-16) : le sprite du dresseur
# adverse, celui de son Pokémon (même emplacement, voir ENEMY_SPRITE_RECT
# réutilisé dans _send_out) et leur plateforme sont jugés parfaits — ne pas
# les décaler à nouveau sans qu'il ne le redemande explicitement.
const ENEMY_SPRITE_RECT := Rect2(0.5833, 0.13, 0.3, 0.4)
const ENEMY_SHADOW_RECT := Rect2(0.4733, 0.435, 0.52, 0.13)
const PLAYER_SPRITE_RECT := Rect2(0.06, 0.34, 0.4, 0.42)
const PLAYER_SHADOW_RECT := Rect2(0.06, 0.70, 0.4, 0.11)
const ENEMY_COUNT_RECT := Rect2(0.03, 0.1225, 0.33, 0.13)
const PLAYER_COUNT_RECT := Rect2(0.65, 0.63, 0.32, 0.13)
# Emplacement final de la carte nom/niveau/PV du joueur (phase 2) — DIFFÉRENT
# de PLAYER_COUNT_RECT : la rangée de Poké Ball (déjà validée, ne plus
# toucher) reste à sa position d'origine, seule la carte qui la remplace
# ensuite doit remonter (elle empiétait sur la boîte de dialogue, voir Gus).
const PLAYER_CARD_RECT := Rect2(0.65, 0.56, 0.32, 0.13)
# Emplacement du Pokémon du joueur (phase 2) — distinct de PLAYER_SPRITE_RECT
# (relevé pour le dresseur en phase 1, voir les retours de Gus) : celui-ci
# reprend tel quel scenes/ui/trainer_battle.tscn::PlayerSprite pour que la
# transition finale vers cet écran soit invisible.
const PLAYER_POKEMON_RECT := Rect2(0.06, 0.42, 0.4, 0.42)

var _root: Control
var _black_top: ColorRect
var _black_bottom: ColorRect
var _speed_lines: SpeedLinesFX
var _enemy_sprite: TextureRect
var _enemy_shadow: TextureRect
var _player_sprite: TextureRect
var _player_shadow: TextureRect
var _enemy_count: Control
var _player_count: Control
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

	_enemy_shadow = _make_tex_rect(PlatformTexture, ENEMY_SHADOW_RECT)
	_player_shadow = _make_tex_rect(PlatformTexture, PLAYER_SHADOW_RECT)
	_enemy_sprite = _make_sprite_rect(ENEMY_SPRITE_RECT)
	_player_sprite = _make_sprite_rect(PLAYER_SPRITE_RECT)

	if enemy_sprite_key != "":
		var enemy_path := "res://assets/characters/custom/battle/%s.png" % enemy_sprite_key
		if ResourceLoader.exists(enemy_path):
			_enemy_sprite.texture = load(enemy_path)
	# Dos du personnage du joueur (pas de sprite dresseur pour l'adversaire à
	# ce stade, le Pokémon n'est envoyé qu'à la phase suivante).
	var player_path := "res://assets/characters/%s_back.png" % PlayerData.appearance
	if ResourceLoader.exists(player_path):
		_player_sprite.texture = load(player_path)

	_enemy_count = _make_count_row(ENEMY_COUNT_RECT)
	_player_count = _make_count_row(PLAYER_COUNT_RECT)

	# Boîte de dialogue construite ici mais gardée invisible pour l'instant —
	# say() (plus loin dans play()) réutilise cette même instance. Ajoutée à
	# la racine du Viewport et NON à _root ni à current_scene : un
	# CanvasLayer (DialogueBox) ajouté comme descendant d'un autre
	# CanvasLayer (ce BattleIntro, ou même title_screen.gd quand ce
	# composant est lancé depuis Tests > Tester un combat) ne s'affiche pas,
	# piège Godot déjà rencontré ailleurs (voir title_screen.gd::_open_slots()).
	# Sa couche (layer 95, voir dialogue_box.gd) est AU-DESSUS du rideau noir
	# (layer 90) : si on la rendait visible dès maintenant, elle apparaîtrait
	# par-dessus le fondu au noir et le rideau qui s'ouvre, avant même que le
	# terrain ne soit révélé — visible.true est donc posé plus tard dans
	# play(), une fois le rideau totalement rouvert (_split_open() terminé).
	_dialogue = DialogueBoxScene.instantiate()
	_dialogue.style = "battle"
	get_tree().root.add_child(_dialogue)
	_dialogue.visible = false

	_speed_lines = SpeedLinesFX.new()
	_speed_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_lines.visible = false
	_root.add_child(_speed_lines)

	_black_top = ColorRect.new()
	_black_top.color = Color.BLACK
	_black_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_bottom = ColorRect.new()
	_black_bottom.color = Color.BLACK
	_black_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black_top)
	_root.add_child(_black_bottom)
	# Léger chevauchement (pas pile 0.0/0.5/0.5/1.0) à la jointure du milieu :
	# 2 rects anchorés bord à bord peuvent laisser un interstice d'1px par
	# arrondi de sous-pixel selon la résolution, qui laisse passer le fond
	# clair en dessous — un fin trait blanc pile au milieu de l'écran noir
	# (signalé par Gus). SEAM_OVERLAP absorbe cet arrondi ; les bords
	# extérieurs (haut de l'écran, bas de l'écran) n'ont pas ce problème
	# (rien ne les chevauche).
	_set_rect(_black_top, Rect2(0.0, 0.0, 1.0, 0.5 + SEAM_OVERLAP))
	_set_rect(_black_bottom, Rect2(0.0, 0.5 - SEAM_OVERLAP, 1.0, 0.5 + SEAM_OVERLAP))
	# Opaques dès la construction (pas 0.0) : ce fond neutre et les sprites
	# tout juste créés au-dessus ne doivent JAMAIS être visibles avant le
	# rideau, même une seule frame — sinon on voit un flash blanc au tout
	# premier instant (ce que Gus a signalé). _fade_to_black() ne les fait
	# donc plus apparaître par un fondu d'opacité (il n'y a rien à voir
	# apparaître, tout est déjà masqué) : c'est juste un temps d'arrêt sur
	# écran noir avant l'ouverture du rideau, voir plus bas.
	_black_top.modulate.a = 1.0
	_black_bottom.modulate.a = 1.0

	# Cachés / hors-écran tant que la séquence ne les a pas amenés en jeu.
	_enemy_sprite.visible = false
	_enemy_shadow.visible = false
	_player_sprite.visible = false
	_player_shadow.visible = false
	_enemy_count.visible = false
	_player_count.visible = false

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

# Positionne `c` avec une taille fixe (en pixels) centrée sur le centre de
# `rect` (fraction d'écran) — pour un élément qui doit garder une taille
# constante quelle que soit la résolution plutôt que d'être étiré pour
# remplir un rectangle relatif (voir la Poké Ball de _send_out()).
func _place_centered(c: Control, rect: Rect2, size: float, offset_y: float = 0.0) -> void:
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5
	c.anchor_left = cx
	c.anchor_right = cx
	c.anchor_top = cy
	c.anchor_bottom = cy
	c.offset_left = -size * 0.5
	c.offset_right = size * 0.5
	c.offset_top = -size * 0.5 + offset_y
	c.offset_bottom = size * 0.5 + offset_y

func _make_count_row(rect: Rect2) -> Control:
	# Control simple (pas de layout automatique) : la rangée mélange des
	# icônes espacées à pas fixe et une barre en-dessous dont la largeur
	# dépend du nombre de Pokémon, un HBoxContainer seul ne suffirait pas.
	var box := Control.new()
	_root.add_child(box)
	_set_rect(box, rect)
	return box

# Rangée de 6 emplacements (comme dans le vrai jeu, quelle que soit la
# taille réelle de l'équipe : icône "pleine" pour les Pokémon existants,
# "vide" au-delà) + le trait qui souligne la rangée. Vrais graphismes FRLG
# (voir les const en tête de fichier). Taille fixe en pixels (pas relative à
# la largeur du conteneur, qui donnait des icônes bien trop grosses) : les 6
# tiennent largement dans le rectangle qui leur est réservé, positionnées
# dans son coin haut-gauche plutôt qu'étirées pour le remplir. Les icônes
# démarrent à scale 0 pour l'apparition progressive dans _animate_counts().
# `slots_from_right` (voir Gus : demandé pour l'adversaire uniquement) :
# quand l'équipe fait moins de 6, les emplacements vides se placent à
# gauche et les pleins à droite (fin de rangée) plutôt que l'inverse.
func _add_count_dots(row: Control, party_size: int, slots_from_right: bool = false) -> void:
	var pitch: float = BALL_PITCH
	var ball_size: float = BALL_SIZE
	var empty_slots: int = PARTY_SLOTS - party_size
	# Décale toute la rangée (balles + barre) vers la droite côté joueur
	# uniquement, voir Gus.
	var row_shift_x: float = 0.0 if slots_from_right else PLAYER_ROW_OFFSET_X
	for i in range(PARTY_SLOTS):
		var is_full: bool = (i >= empty_slots) if slots_from_right else (i < party_size)
		var dot := TextureRect.new()
		dot.texture = PartyBallTexture if is_full else PartyBallEmptyTexture
		dot.texture_filter = 1
		dot.expand_mode = 1
		dot.stretch_mode = 5
		dot.position = ROW_PADDING + Vector2(row_shift_x + i * pitch, 0.0)
		dot.size = Vector2(ball_size, ball_size)
		dot.pivot_offset = Vector2(ball_size, ball_size) * 0.5
		dot.scale = Vector2.ZERO
		row.add_child(dot)

	var bar := TextureRect.new()
	bar.texture = PartyBarTexture
	bar.texture_filter = 1
	bar.expand_mode = 1
	bar.stretch_mode = 5
	# Miroir horizontal côté adversaire seulement (même signal que les
	# emplacements vides à gauche, voir plus haut) : la pointe du trait doit
	# être tournée vers lui, pas dans le même sens que côté joueur.
	bar.flip_h = slots_from_right
	var bar_offset_x: float = ENEMY_BAR_OFFSET_X if slots_from_right else PLAYER_BAR_OFFSET_X
	bar.position = ROW_PADDING + Vector2(row_shift_x + bar_offset_x, ball_size)
	bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	row.add_child(bar)

# --- Séquence ---

func play() -> void:
	await _fade_to_black()
	await _split_open()
	_dialogue.visible = true   # seulement une fois le rideau totalement rouvert, voir _build_ui()
	await _slide_in_combatants()
	await _animate_counts()
	await _show_intro_text()
	await _send_out(false)   # l'adversaire envoie son premier Pokémon en premier, fidèle au vrai jeu
	await _send_out(true)
	# _dialogue est ajoutée à la racine du Viewport, pas comme enfant de ce
	# CanvasLayer (voir _build_ui()) — donc PAS libérée par le
	# intro.queue_free() de l'appelant (title_screen.gd). Sans ce nettoyage
	# explicite, elle restait dans l'arbre (visible=true) tout le combat qui
	# suit, invisible la plupart du temps derrière l'interface de
	# trainer_battle.gd mais visible en fin de compte dans le moindre
	# interstice non couvert (ex. entre la boîte des capacités et la fenêtre
	# d'action) — signalé par Gus.
	_dialogue.queue_free()

# Rien à animer ici : le rideau est déjà opaque dès _build_ui() (voir le
# commentaire là-bas). `fade_duration` reste un temps d'arrêt volontaire sur
# écran noir avant l'ouverture du rideau — utile pour les combats importants
# (durée allongée), mais aucun fondu d'opacité à proprement parler.
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

func _slide_in_combatants() -> void:
	_enemy_sprite.visible = true
	_enemy_shadow.visible = true
	_player_sprite.visible = true
	_player_shadow.visible = true

	# Départ hors-écran (adversaire à gauche, joueur à droite), même largeur
	# que la position finale, juste décalé d'un plein écran horizontalement.
	_set_rect(_enemy_sprite, _shifted(ENEMY_SPRITE_RECT, -1.0))
	_set_rect(_enemy_shadow, _shifted(ENEMY_SHADOW_RECT, -1.0))
	_set_rect(_player_sprite, _shifted(PLAYER_SPRITE_RECT, 1.0))
	_set_rect(_player_shadow, _shifted(PLAYER_SHADOW_RECT, 1.0))

	await _speed_lines.flash()

	var tw := create_tween()
	tw.set_parallel(true)
	_tween_horizontal(tw, _enemy_sprite, ENEMY_SPRITE_RECT)
	_tween_horizontal(tw, _enemy_shadow, ENEMY_SHADOW_RECT)
	_tween_horizontal(tw, _player_sprite, PLAYER_SPRITE_RECT)
	_tween_horizontal(tw, _player_shadow, PLAYER_SHADOW_RECT)
	await tw.finished

func _shifted(rect: Rect2, delta_x: float) -> Rect2:
	var r := rect
	r.position.x += delta_x
	return r

func _tween_horizontal(tw: Tween, c: Control, target: Rect2, duration: float = SLIDE_DURATION) -> void:
	tw.tween_property(c, "anchor_left", target.position.x, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "anchor_right", target.position.x + target.size.x, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_counts() -> void:
	_enemy_count.visible = true
	_player_count.visible = true
	_add_count_dots(_enemy_count, enemy_party.size(), true)
	_add_count_dots(_player_count, player_party.size())

	# Les 2 rangées de 6 apparaissent emplacement par emplacement, en
	# parallèle entre elles (adversaire et joueur ensemble) plutôt qu'une
	# rangée après l'autre — vides comme pleins, comme dans le vrai jeu.
	# Adversaire dans l'ordre inverse (droite vers gauche, voir Gus — cohérent
	# avec ses emplacements vides à gauche/pleins à droite) ; joueur inchangé
	# (gauche vers droite).
	for i in range(PARTY_SLOTS):
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_enemy_count.get_child(PARTY_SLOTS - 1 - i), "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_player_count.get_child(i), "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished

# Réutilise la boîte de dialogue déjà affichée (vide depuis _build_ui) —
# say() gère lui-même l'attente de l'appui sur la touche d'action.
func _show_intro_text() -> void:
	var lines: Array[String] = ["Un combat est lancé par %s !" % enemy_trainer_name]
	# force_arrow=true : la boîte se ferme après cette ligne, mais l'envoi
	# des Pokémon enchaîne juste après — pas la fin de ce qu'il se passe,
	# voir say() dans dialogue_box.gd.
	_dialogue.say(lines, -1, 0.0, true)
	await _dialogue.finished

# --- Phase 2 : envoi du 1er Pokémon d'un camp ---

func _send_out(is_player: bool) -> void:
	var party: Array = player_party if is_player else enemy_party
	if party.is_empty():
		return
	var entry: Dictionary = party[0]
	var species_key: String = String(entry["species"])
	var level: int = int(entry["level"])
	var species_name: String = String(SpeciesData.SPECIES[species_key]["name"])
	# PV max (Pokémon fraîchement envoyé = toujours à pleine vie) — la carte
	# de l'intro n'affichait jusque-là aucun texte de PV, contrairement à
	# celle de trainer_battle.tscn, d'où un "XX/YY" qui semblait apparaître
	# après coup au moment de la bascule entre les deux écrans (signalé par
	# Gus). Le sexe vient de `entry` (déjà tiré au sort une fois pour toutes
	# par TrainerData.roll_genders(), voir title_screen.gd) — PAS retiré ici,
	# sinon l'intro et trainer_battle.gd pourraient afficher 2 sexes
	# différents pour le même Pokémon. Le moveset ([]) n'a aucune importance,
	# BattlePokemon.create() ne sert ici qu'à calculer max_hp.
	var gender: String = String(entry.get("gender", ""))
	var max_hp: int = BattlePokemon.create(species_key, level, [], gender).max_hp

	var trainer_sprite: TextureRect = _player_sprite if is_player else _enemy_sprite
	var count_row: Control = _player_count if is_player else _enemy_count
	var pokemon_rect: Rect2 = PLAYER_POKEMON_RECT if is_player else ENEMY_SPRITE_RECT
	# card_rect : position/direction de sortie de la rangée de Poké Ball
	# (inchangée, déjà validée). final_card_rect : où la carte nom/niveau/PV
	# atterrit ensuite — différent uniquement côté joueur (voir
	# PLAYER_CARD_RECT).
	var card_rect: Rect2 = PLAYER_COUNT_RECT if is_player else ENEMY_COUNT_RECT
	var final_card_rect: Rect2 = PLAYER_CARD_RECT if is_player else ENEMY_COUNT_RECT

	# Chaque élément sort vers l'extérieur, dans la direction de son propre
	# côté d'écran (le dresseur adverse part à droite, son compteur à gauche —
	# fidèle à la description : ce n'est pas "les deux pareil", chacun part à
	# l'opposé du centre depuis sa position actuelle).
	var sprite_exit_dx: float = 1.0 if _rect_center_x(pokemon_rect) > 0.5 else -1.0
	var card_exit_dx: float = 1.0 if _rect_center_x(card_rect) > 0.5 else -1.0

	var text: String
	if is_player:
		text = "Vas-y, %s !" % species_name
	else:
		text = "%s est envoyé par %s !" % [species_name, enemy_trainer_name]
	var lines: Array[String] = [text]
	_dialogue.say(lines)
	# Pas d'attente d'appui joueur ici (contrairement à _show_intro_text) :
	# l'animation d'envoi enchaîne dès que le texte a fini de s'afficher,
	# page_typed suffit — finished n'arrive qu'après un appui pour fermer.
	await _dialogue.page_typed
	# `active = false` juste après : la boîte reste affichée (visible=true,
	# inchangé) mais n'écoute plus ui_accept pendant toute l'animation
	# d'envoi qui suit. Sans ça, un appui pendant l'animation atteint
	# dialogue_box.gd::_unhandled_input(), qui considère la file déjà vide
	# (une seule ligne, déjà affichée) et ferme la boîte immédiatement —
	# signalé par Gus (la boîte pouvait disparaître avant la fin de
	# l'animation).
	_dialogue.active = false

	# La plateforme ne bouge JAMAIS ici (ni pendant la sortie du dresseur, ni
	# après) — elle reste fixe et affichée en continu depuis la phase 1 (voir
	# _slide_in_combatants()), seuls le sprite du dresseur et son compteur
	# de Pokémon quittent le terrain.
	var exit_tw := create_tween()
	exit_tw.set_parallel(true)
	_tween_horizontal(exit_tw, trainer_sprite, _shifted(pokemon_rect, sprite_exit_dx), SEND_OUT_SLIDE_DURATION)
	_tween_horizontal(exit_tw, count_row, _shifted(card_rect, card_exit_dx), SEND_OUT_SLIDE_DURATION)
	await exit_tw.finished
	trainer_sprite.visible = false
	count_row.visible = false

	# Icône centrée sur l'emplacement du Pokémon (POKEBALL_SIZE fixe), pas
	# étirée pour remplir tout le rectangle — pokemon_rect couvre ~30% de
	# l'écran (même rect que le sprite final), une Poké Ball n'a pas à être
	# aussi grosse.
	var ball := TextureRect.new()
	ball.texture = PokeballTexture
	ball.texture_filter = 1
	ball.expand_mode = 1
	ball.stretch_mode = 5
	_root.add_child(ball)
	var ball_offset_y: float = ENEMY_BALL_OFFSET_Y if not is_player else 0.0
	_place_centered(ball, pokemon_rect, POKEBALL_SIZE, ball_offset_y)
	ball.pivot_offset = Vector2(POKEBALL_SIZE, POKEBALL_SIZE) * 0.5
	ball.scale = Vector2.ZERO
	var ball_in := create_tween()
	ball_in.tween_property(ball, "scale", Vector2.ONE, POKEBALL_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await ball_in.finished
	await get_tree().create_timer(BALL_CLOSED_HOLD).timeout

	# La balle s'ouvre vraiment ici (sprite "ouverte", 2e des 3 frames de
	# graphics/interface/ball/poke.png — la 3e est vide, le vrai jeu ne
	# montre plus la balle une fois ouverte) pile au moment des étoiles/du
	# flash, avant de disparaître.
	ball.texture = PokeballOpenTexture
	_spawn_pokeball_sparkles(pokemon_rect)
	_speed_lines.flash(POKEBALL_FLASH_DURATION)   # non attendu ici, tourne en fond
	var ball_out := create_tween()
	ball_out.tween_property(ball, "scale", Vector2.ZERO, POKEBALL_POP_DURATION)

	# Court délai avant de montrer le Pokémon : laisse l'ouverture de la
	# balle réellement visible un instant (elle disparaissait complètement
	# sous le Pokémon sinon), sans revenir au temps mort d'avant (qui
	# attendait la fin complète du flash ET de la disparition de la balle).
	await get_tree().create_timer(POKEMON_APPEAR_DELAY).timeout
	ball.queue_free()

	# Le Pokémon (sprite couleur + silhouette blanche par-dessus, pas une
	# simple teinte — un modulate multiplicatif ne peut qu'assombrir/teinter,
	# jamais aplatir en blanc uni les zones sombres comme les contours noirs,
	# d'où le rendu "rougeâtre" d'avant).
	trainer_sprite.texture = _load_pokemon_texture(species_key, is_player)
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

	# Petit fondu d'entrée (pas juste scale/visible d'un coup) avant le
	# fondu de sortie qui révèle le sprite normal — sinon la silhouette
	# "pop" d'un bloc, signalé par Gus.
	# TRANS_SINE + EASE_IN_OUT sur les 2 étapes (pas la valeur par défaut,
	# linéaire, qui rendait la transition mécanique) pour une entrée/sortie
	# plus douce, cohérente entre elles.
	var appear := create_tween()
	appear.tween_property(silhouette, "modulate:a", 1.0, SILHOUETTE_FADE_IN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await appear.finished

	var reveal := create_tween()
	reveal.tween_property(silhouette, "modulate:a", 0.0, POKEMON_REVEAL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal.finished
	silhouette.queue_free()

	# Carte nom/niveau/PV : apparaît sur place (fondu), directement à son
	# emplacement final. Un glissement depuis hors-écran (comme les autres
	# éléments) donnait un rendu bizarre ici : PanelContainer redimensionne
	# son contenu en continu pendant que anchor_left/anchor_right bougent,
	# ce qui fait paraître la carte "étirée" un instant avant de se stabiliser.
	var card := _make_nameplate(species_name, level, max_hp, gender, is_player)
	_set_rect(card, final_card_rect)
	card.modulate.a = 0.0
	var card_tw := create_tween()
	card_tw.tween_property(card, "modulate:a", 1.0, 0.4)
	await card_tw.finished

# Éclats qui partent en éventail depuis le centre de `rect` (point d'ouverture
# de la Poké Ball) puis s'effacent — non-attendu par l'appelant (tourne en
# parallèle du flash de _speed_lines), voir _send_out().
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

func _load_pokemon_texture(species_key: String, is_player: bool) -> Texture2D:
	var suffix := "back" if is_player else "front"
	var path := "res://assets/pokemon/%s/%s.png" % [species_key, suffix]
	if ResourceLoader.exists(path):
		return load(path)
	return null

# Shader minimal : remplace chaque pixel visible du sprite par du blanc uni,
# en ne gardant que sa forme (canal alpha) — un modulate multiplicatif ne
# peut que teinter/assombrir les couleurs existantes, jamais aplatir les
# zones sombres (contours noirs, ombres) en blanc, d'où le besoin d'un vrai
# shader pour la silhouette "lumineuse" du Pokémon à sa sortie de balle.
func _make_silhouette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

# Carte nom/niveau/PV — même recette que
# scenes/ui/trainer_battle.tscn::EnemyHealthBox/PlayerHealthBox (couleurs,
# marges, police), construite ici en code pour rester cohérente avec le
# reste du composant ; la barre de PV démarre pleine (le Pokémon vient d'être
# envoyé, aucun dégât encore possible à ce stade).
# Symbole ♂/♀ (U+2642/U+2640) — déjà présent dans dialogue_latin.fnt (chars
# 9794/9792, vérifié), pas besoin d'extraire un nouvel asset depuis
# kanto-pipeline. Couleur façon vrai jeu (bleu mâle / rose femelle), séparé
# du nom (pas juste concaténé dans le texte, sinon impossible à colorer
# différemment) avec un petit espace avant, pas collé — "none" (espèce sans
# sexe) n'ajoute rien du tout.
func _add_gender_label(parent: HBoxContainer, gender: String) -> void:
	if gender != "male" and gender != "female":
		return
	var label := Label.new()
	label.text = " ♂" if gender == "male" else " ♀"
	label.add_theme_font_override("font", DialogueFont)
	label.add_theme_font_size_override("font_size", 24)
	# Le shader "silhouette" (celui du Pokémon à sa sortie de balle) rendait
	# le symbole quasi invisible sur un Label — le rendu de texte de Godot ne
	# passe pas par le même chemin qu'un simple TextureRect, `TEXTURE` dans
	# le shader ne récupère pas l'atlas de glyphes comme espéré. Retour à
	# font_color, avec des couleurs volontairement vives/saturées (pas
	# pastel) : le glyphe garde un contour gris foncé qui reste sombre une
	# fois teinté, une couleur vive limite ce résidu à un simple liseré au
	# lieu de noyer tout le symbole.
	label.add_theme_color_override("font_color", GENDER_MALE_COLOR if gender == "male" else GENDER_FEMALE_COLOR)
	parent.add_child(label)

func _make_nameplate(pokemon_name: String, level: int, max_hp: int, gender: String, show_exp_bar: bool = false) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 0.870588, 1)
	style.set_border_width_all(3)
	style.border_color = Color(0.12549, 0.223529, 0, 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style)
	_root.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	# name_label n'occupe QUE la largeur de son texte (pas SIZE_EXPAND_FILL,
	# sinon le symbole de sexe placé juste après se retrouverait collé au
	# niveau à droite plutôt qu'à côté du nom) — c'est le spacer plus bas qui
	# pousse le niveau à droite.
	var name_label := Label.new()
	name_label.text = pokemon_name
	name_label.add_theme_font_override("font", DialogueFont)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(name_label)

	_add_gender_label(name_row, gender)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(spacer)

	var level_label := Label.new()
	level_label.text = "N.%d" % level
	level_label.add_theme_font_override("font", DialogueFont)
	level_label.add_theme_font_size_override("font_size", 24)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(level_label)

	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(0, 12)
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

	# Texte "PV actuels/PV max" — affiché des deux côtés (voir Gus : demandé
	# aussi pour l'adversaire, contrairement au vrai jeu qui ne montre que la
	# barre côté adversaire). Pokémon fraîchement envoyé = toujours à pleine
	# vie.
	var hp_text := Label.new()
	hp_text.text = "%d/%d" % [max_hp, max_hp]
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_text.add_theme_font_override("font", DialogueFont)
	hp_text.add_theme_font_size_override("font_size", 18)
	hp_text.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(hp_text)

	# Barre d'XP : jamais affichée côté adversaire dans le vrai jeu, seulement
	# sur la carte du joueur. Vide pour l'instant (voir Gus) : pas de vraie
	# progression d'XP suivie pour cette équipe prêtée/éphémère
	# (trainer_data.gd::PLAYER_LOAN_TEAM n'a aucun champ xp) — à brancher sur
	# de vraies données le jour où une équipe joueur persistante existera.
	# Dans la carte elle-même (pas dans une ombre décalée façon vrai jeu :
	# tenté, mais trop capricieux à positionner correctement pour le gain
	# visuel, voir Gus — cette version simple fonctionne bien).
	if show_exp_bar:
		var exp_bg := ColorRect.new()
		exp_bg.custom_minimum_size = Vector2(0, 5)
		exp_bg.color = Color(0.321569, 0.415686, 0.352941, 1)
		vbox.add_child(exp_bg)

		var exp_fill := ColorRect.new()
		exp_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		exp_fill.anchor_right = 0.0
		exp_fill.offset_left = 2.0
		exp_fill.offset_top = 1.0
		exp_fill.offset_right = 0.0
		exp_fill.offset_bottom = -1.0
		exp_fill.color = Color(0.286275, 0.784314, 0.882353, 1)
		exp_bg.add_child(exp_fill)

	return box
