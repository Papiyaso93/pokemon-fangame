extends CharacterBody2D

# Déplacement fidèle FRLG (case par case, 60 px/s, tap-to-turn) + transitions
# entre maps quand on franchit un bord connecté.
const SPEED := 60.0
const BIKE_SPEED := 240.0   # vélo : x4, plus fidèle au Vélo Turbo des jeux d'origine (x2 se sentait trop timide)
const JUMP_SPEED := 120.0   # rebord : saut de 2 cases, plus rapide qu'un pas normal
const TILE_SIZE := 16
const TURN_TIME := 0.1

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const EncounterScene := preload("res://scenes/ui/encounter.tscn")
const BattleTransitionScene := preload("res://scenes/ui/battle_transition.tscn")
const LocationBannerScene := preload("res://scenes/ui/location_banner.tscn")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")
const YesNoChoiceScene := preload("res://scenes/ui/yes_no_choice.tscn")
const ENCOUNTER_CHANCE := 0.10   # par pas dans les hautes herbes (valeur ajustable)

# Directions opposées, utilisé pour valider la réciprocité d'une connexion
# avant de charger une carte voisine en mode fluide (voir _load_world()).
const OPPOSITE_DIR := {"up": "down", "down": "up", "left": "right", "right": "left"}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

enum { NOT_MOVING, TURNING, MOVING }
var state := NOT_MOVING
var is_moving := false
var is_busy := false   # true pendant un dialogue : ignore déplacement/interaction
var move_target := Vector2.ZERO
var facing := "south"     # south / north / west / east
var turn_timer := 0.0

var map_size := Vector2i(1000, 1000)
var connections: Array = []
var ledges: Array = []
var grass: Array = []
var warps: Array = []
var elevation: Array = []
var water: Array = []
var is_surfing := false
var pending_encounter_check := false
var pending_repel_expired_notice := false   # voir _consume_repel_step()
var current_speed := SPEED
var is_jumping := false
var jump_total_dist := 0.0
const JUMP_ARC_HEIGHT := 6.0   # pixels, arc visuel du saut de rebord

var origin_map_name := ""      # nom de la carte de cette scène (celle avec Player/Camera)
var current_map_name := ""     # nom de la carte "effective" sous les pieds du joueur
var last_banner_name := ""     # dernier nom FRANÇAIS affiché (évite les doublons entre
								# cartes scindées en plusieurs scènes, ex. route21_north/south)
var show_map_name := true      # fidèle FRLG (map.json: show_map_name) : false pour les
								# intérieurs (MAP_TYPE_INDOOR) — pas de bandeau à l'entrée.

# Toutes les cartes chargées en recouvrement (origine incluse, en zones[0]) :
# {name, rect (Rect2 monde, coords locales à cette scène), size (Vector2i,
# tuiles), ledges, grass, warps (tuiles locales à cette carte), connections}.
# Peuplé par _load_world() en suivant les connexions de proche en proche
# (BFS), pas juste les voisins immédiats — voir HANDOFF.md.
var zones: Array = []

func _ready() -> void:
	add_to_group("player")
	_apply_appearance()
	_read_map_meta()
	_update_safari_state()
	# Arrivée via une transition : on se place au bon endroit de la nouvelle map.
	if Transitions.pending:
		facing = Transitions.facing
		if Transitions.direct:
			position = Vector2(Transitions.direct_tile) * TILE_SIZE
		else:
			position = Vector2(_entry_tile(Transitions.from_dir, Transitions.cross)) * TILE_SIZE
		Transitions.pending = false
	move_target = position
	# Vélo persisté (PlayerData, contrairement à is_surfing qui repart toujours
	# à false vu que rien ne le sauvegarde) : il faut réappliquer le bon sprite
	# à chaque arrivée sur une nouvelle scène, sinon l'apparence reste "normale"
	# jusqu'au prochain aller-retour dans le sac.
	_update_movement_sprite()

	origin_map_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	current_map_name = origin_map_name
	# Différé : l'arbre de scène est encore en cours de construction pendant
	# ce _ready() (change_scene_to_file en cours), on ne peut pas encore lui
	# ajouter/retirer des nœuds à ce moment précis.
	call_deferred("_load_world")
	if show_map_name:
		call_deferred("_show_location_banner", current_map_name)

# Le spritesheet en dur dans player.tscn est red_normal ; les 4 apparences
# (voir PlayerData.APPEARANCES) partagent le même format 144×32/9 frames,
# donc il suffit de changer la texture source de chaque AtlasTexture.
func _apply_appearance() -> void:
	var path := "res://assets/characters/%s.png" % PlayerData.appearance
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var sf: SpriteFrames = anim.sprite_frames
	for anim_name in sf.get_animation_names():
		for i in range(sf.get_frame_count(anim_name)):
			var frame_tex := sf.get_frame_texture(anim_name, i)
			if frame_tex is AtlasTexture:
				(frame_tex as AtlasTexture).atlas = tex
	_prepare_surf_sprite_frames()
	_prepare_bike_sprite_frames()
	_prepare_fishing_sprite_frames()

# Sprites de Surf réels (vrai jeu FRLG). Contrairement à ce qu'on pourrait
# croire, l'image "posée" red_surf.png/green_surf.png n'est PAS celle utilisée
# pour le déplacement (vérifié dans object_event_graphics_info.h : elle n'est
# référencée nulle part) — c'est red_surf_run.png/green_surf_run.png, au même
# format que le sprite normal (16 px de large). Et là où le sprite normal a un
# cycle de marche à 4 frames, le Surf n'a qu'UNE seule pose fixe par
# direction (object_event_anims.h::sAnim_SurfFaceSouth/North/West — East =
# West retourné, comme le sprite normal) : indices 0=sud, 1=nord, 2=ouest de
# red_surf_run.png. N'existe que pour red_normal/green_normal (Brendan/May
# viennent de Rubis/Saphir, pas dans notre décompilation FireRed/LeafGreen) :
# ces 2 apparences gardent leur sprite normal en attendant, voir HANDOFF.md/
# conversation du 13/07/2026.
const SURF_TEXTURE := {"red_normal": "red_surf_run", "green_normal": "green_surf_run"}
var normal_sprite_frames: SpriteFrames
var surf_sprite_frames: SpriteFrames = null

func _prepare_surf_sprite_frames() -> void:
	if normal_sprite_frames == null:
		normal_sprite_frames = anim.sprite_frames
	var surf_name: String = SURF_TEXTURE.get(PlayerData.appearance, "")
	surf_sprite_frames = null
	if surf_name.is_empty():
		return
	var surf_path := "res://assets/characters/%s.png" % surf_name
	if not ResourceLoader.exists(surf_path):
		return
	surf_sprite_frames = _build_directional_pose_frames(load(surf_path))

# Vélo (zone 2, Camille — voir acte1-parc-safari.md) : même situation que le
# Surf, sprites réels FRLG (red_bike.png/green_bike.png) seulement pour
# red_normal/green_normal, pas pour Brendan/May. Même hypothèse de layout que
# le Surf (3 poses fixes sud/nord/ouest, 16 px chacune) tant que non vérifiée
# visuellement en jeu — à ajuster si la pose affichée ne correspond pas.
const BIKE_TEXTURE := {"red_normal": "red_bike", "green_normal": "green_bike"}
var bike_sprite_frames: SpriteFrames = null

func _prepare_bike_sprite_frames() -> void:
	if normal_sprite_frames == null:
		normal_sprite_frames = anim.sprite_frames
	var bike_name: String = BIKE_TEXTURE.get(PlayerData.appearance, "")
	bike_sprite_frames = null
	if bike_name.is_empty():
		return
	var bike_path := "res://assets/characters/%s.png" % bike_name
	if not ResourceLoader.exists(bike_path):
		return
	bike_sprite_frames = _build_directional_pose_frames(load(bike_path), 32)

# Canne à pêche (voir acte1-parc-safari.md, _start_fishing()) : sprites réels
# FRLG (red_fish.png/green_fish.png, 32 px/frame comme le Vélo), seulement
# red_normal/green_normal. Contrairement à Surf/Vélo, on a un vrai petit cycle
# d'animation (lancer de ligne, attente, touche) — voir _build_fishing_sprite_
# frames() pour le détail des frames, copié depuis object_event_anims.h
# (sAnimTable_RedGreenFish) pour rester fidèle aux timings d'origine.
const FISH_TEXTURE := {"red_normal": "red_fish", "green_normal": "green_fish"}
var fish_sprite_frames: SpriteFrames = null

func _prepare_fishing_sprite_frames() -> void:
	if normal_sprite_frames == null:
		normal_sprite_frames = anim.sprite_frames
	var fish_name: String = FISH_TEXTURE.get(PlayerData.appearance, "")
	fish_sprite_frames = null
	if fish_name.is_empty():
		return
	var fish_path := "res://assets/characters/%s.png" % fish_name
	if not ResourceLoader.exists(fish_path):
		return
	fish_sprite_frames = _build_fishing_sprite_frames(load(fish_path))

# 4 frames par direction (west=0-3, north=4-7, south=8-11, est = ouest
# retourné comme partout ailleurs) : 0=canne rangée, 1-2=lancer en cours,
# 3=canne tenue en l'air (attente/ferrage). Timings en ticks à 60 IPS, copiés
# tels quels de sAnim_TakeOutRod*/PutAwayRod*/HookedPokemon* pour rester
# fidèle au vrai jeu plutôt que d'inventer des durées.
func _build_fishing_sprite_frames(tex: Texture2D) -> SpriteFrames:
	var frame_tex: Array[AtlasTexture] = []
	for i in range(12):
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 32, 0, 32, 32)
		frame_tex.append(a)

	var sf := SpriteFrames.new()
	var bases := {"west": 0, "north": 4, "south": 8}
	for dir: String in bases:
		var base: int = bases[dir]

		var cast_name: String = "cast_" + dir
		sf.add_animation(cast_name)
		sf.set_animation_speed(cast_name, 60.0)
		sf.set_animation_loop(cast_name, false)
		for i in range(4):
			sf.add_frame(cast_name, frame_tex[base + i], 4)

		var idle_name: String = "idle_rod_" + dir
		sf.add_animation(idle_name)
		sf.set_animation_speed(idle_name, 60.0)
		sf.add_frame(idle_name, frame_tex[base + 3], 1)

		# sAnim_HookedPokemon* : 2 allers-retours puis pause longue avant de
		# reboucler (ANIMCMD_LOOP(1) = 1 répétition en plus, puis 30 ticks
		# d'arrêt sur la dernière frame avant de repartir du début).
		var bite_name: String = "bite_" + dir
		sf.add_animation(bite_name)
		sf.set_animation_speed(bite_name, 60.0)
		sf.add_frame(bite_name, frame_tex[base + 2], 6)
		sf.add_frame(bite_name, frame_tex[base + 3], 6)
		sf.add_frame(bite_name, frame_tex[base + 2], 6)
		sf.add_frame(bite_name, frame_tex[base + 3], 6)
		sf.add_frame(bite_name, frame_tex[base + 3], 30)

		var putaway_name: String = "putaway_" + dir
		sf.add_animation(putaway_name)
		sf.set_animation_speed(putaway_name, 60.0)
		sf.set_animation_loop(putaway_name, false)
		sf.add_frame(putaway_name, frame_tex[base + 3], 4)
		sf.add_frame(putaway_name, frame_tex[base + 2], 6)
		sf.add_frame(putaway_name, frame_tex[base + 1], 6)
		sf.add_frame(putaway_name, frame_tex[base + 0], 6)
	return sf

# 3 poses fixes seulement (sud/nord/ouest) — pas de cycle de marche, fidèle à
# sAnimTable_RedGreenSurf (face ET déplacement utilisent la même pose unique
# par direction dans le vrai jeu). Réutilisé pour le Vélo aussi, mais avec une
# largeur de frame différente (32 px, pas 16) : red_bike.png/green_bike.png
# font 288 px de large comme red_normal.png (144 px, 9 frames de 16 px) mais
# en 2x plus large — signe que ses frames sont deux fois plus larges (9
# frames de 32 px), pas deux fois plus nombreuses (constaté visuellement,
# 13/07/2026 : le sprite Vélo apparaissait coupé en deux avec des frames de
# 16 px).
func _build_directional_pose_frames(tex: Texture2D, frame_width: int = 16) -> SpriteFrames:
	var at: Array[AtlasTexture] = []
	for i in range(3):
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * frame_width, 0, frame_width, 32)
		at.append(a)
	var sf := SpriteFrames.new()
	for anim_name in ["face_south", "walk_south"]:
		sf.add_animation(anim_name); sf.set_animation_speed(anim_name, 5.0)
		sf.add_frame(anim_name, at[0])
	for anim_name in ["face_north", "walk_north"]:
		sf.add_animation(anim_name); sf.set_animation_speed(anim_name, 5.0)
		sf.add_frame(anim_name, at[1])
	for anim_name in ["face_west", "walk_west"]:
		sf.add_animation(anim_name); sf.set_animation_speed(anim_name, 5.0)
		sf.add_frame(anim_name, at[2])
	return sf

# Bascule le sprite affiché selon l'état de déplacement actuel (Surf > Vélo >
# normal), appelée à chaque changement de l'un des deux. Ne change rien si
# aucun sprite dédié n'existe pour l'apparence actuelle (Brendan/May).
func _update_movement_sprite() -> void:
	if is_surfing and surf_sprite_frames != null:
		anim.sprite_frames = surf_sprite_frames
	elif PlayerData.is_biking and bike_sprite_frames != null:
		anim.sprite_frames = bike_sprite_frames
	else:
		anim.sprite_frames = normal_sprite_frames
	_play("face" if state != MOVING else "walk")

func _read_map_meta() -> void:
	var root := get_parent()
	if root and root.has_meta("map_size"):
		map_size = root.get_meta("map_size")
	if root and root.has_meta("connections"):
		connections = root.get_meta("connections")
	if root and root.has_meta("ledges"):
		ledges = root.get_meta("ledges")
	if root and root.has_meta("grass"):
		grass = root.get_meta("grass")
	if root and root.has_meta("warps"):
		warps = root.get_meta("warps")
	if root and root.has_meta("show_map_name"):
		show_map_name = root.get_meta("show_map_name")
	if root and root.has_meta("elevation"):
		elevation = root.get_meta("elevation")
	if root and root.has_meta("water"):
		water = root.get_meta("water")

# ── Transitions fluides (voir HANDOFF.md) ──────────────────────────────────
# Au lieu de recharger la scène en franchissant un bord connecté, on charge
# TOUTES les cartes transitivement connectées par des connexions de bord
# réciproques (de proche en proche, pas juste les voisins immédiats) : leurs
# calques Below/Above/Collision sont extraits de leur scène et rattachés
# directement dans la scène courante, positionnés au bon endroit — le joueur
# continue simplement sa marche, sans écran noir. Le Player/Camera de chaque
# carte voisine (générés par import_map.gd) ne servent à rien ici et sont
# jetés. Les cartes qui n'ont AUCUNE connexion réciproque valide (Safrania,
# accessible uniquement par portes gardées ; Forêt de Jade et Zone Safari,
# uniquement par passages internes — fidèle au vrai jeu) restent en dehors de
# ce système et gardent l'ancien comportement de téléportation.
func _load_world() -> void:
	var root := get_parent()
	var origin_zone := {
		"name": origin_map_name,
		"rect": Rect2(Vector2.ZERO, Vector2(map_size) * TILE_SIZE),
		"size": map_size,
		"ledges": ledges,
		"grass": grass,
		"warps": warps,
		"connections": connections,
		"elevation": elevation,
		"water": water,
	}
	zones = [origin_zone]
	var queue: Array = [origin_zone]
	while not queue.is_empty():
		var cur: Dictionary = queue.pop_front()
		for c in cur.connections:
			var target := String(c.get("target", ""))
			if target == "" or _zone_by_name(target) != null:
				continue
			var dname := String(c.get("dir", ""))
			var off := int(c.get("offset", 0))
			var path := "res://scenes/maps/%s.tscn" % target
			if not ResourceLoader.exists(path):
				continue
			var node := (load(path) as PackedScene).instantiate()
			var n_size: Vector2i = node.get_meta("map_size", Vector2i.ZERO)
			var n_connections: Array = node.get_meta("connections", [])
			if not _has_reciprocal_connection(n_connections, cur.name, dname, off):
				node.queue_free()
				continue
			var world_off := _compute_offset(cur.rect, n_size, dname, off)
			var zone := {
				"name": target,
				"rect": Rect2(world_off, Vector2(n_size) * TILE_SIZE),
				"size": n_size,
				"ledges": node.get_meta("ledges", []),
				"grass": node.get_meta("grass", []),
				"warps": node.get_meta("warps", []),
				"connections": n_connections,
				"elevation": node.get_meta("elevation", []),
				"water": node.get_meta("water", []),
			}
			_attach_layers(root, node, world_off)
			zones.append(zone)
			queue.append(zone)
	_load_border_fillers(root)
	_update_camera_bounds()
	# Si l'arrivée s'est faite par un warp (fondu déclenché avant le
	# change_scene_to_file), on révèle l'écran maintenant que le monde est
	# construit. Sans effet si aucun fondu n'était en cours (déjà à alpha 0).
	await ScreenFade.fade_in()

# Une connexion cur -> target (direction dname, offset off) n'est utilisée
# pour la fluidité que si target la confirme en sens inverse (même distance,
# offset opposé). Filtre les données de connexion "orphelines" trouvées dans
# les cartes pret (ex. saffron_city déclare des connexions vers route5-8 qui
# ne sont reciproquées nulle part — ces routes ne rejoignent en réalité que
# saffron_city_connection, la vraie Safrania n'étant accessible que par portes
# gardées ; cf. HANDOFF.md).
func _has_reciprocal_connection(n_connections: Array, from_name: String, dname: String, off: int) -> bool:
	var opp: String = OPPOSITE_DIR.get(dname, "")
	for c2 in n_connections:
		if String(c2.get("target", "")) == from_name and String(c2.get("dir", "")) == opp \
				and int(c2.get("offset", 0)) == -off:
			return true
	return false

# Même calcul que celui utilisé par _entry_tile()/_try_transition() pour une
# simple case d'arrivée, généralisé pour placer toute une carte dans l'espace
# local de la scène courante, à partir du rectangle (déjà placé) de la carte
# qui déclare la connexion — pas forcément l'origine, une carte peut être
# rattachée en chaîne à une autre carte déjà rattachée.
func _compute_offset(from_rect: Rect2, n_size: Vector2i, dname: String, off: int) -> Vector2:
	match dname:
		"up":
			return Vector2(from_rect.position.x + off * TILE_SIZE, from_rect.position.y - n_size.y * TILE_SIZE)
		"down":
			return Vector2(from_rect.position.x + off * TILE_SIZE, from_rect.position.y + from_rect.size.y)
		"left":
			return Vector2(from_rect.position.x - n_size.x * TILE_SIZE, from_rect.position.y + off * TILE_SIZE)
		_:
			return Vector2(from_rect.position.x + from_rect.size.x, from_rect.position.y + off * TILE_SIZE)

# Pose les patchs décoratifs (BorderFillers.PATCHES) par-dessus les zones
# grises aux jonctions de cartes mal jointes — voir scripts/border_fillers.gd.
# Purement visuel, aucune collision : le joueur ne peut de toute façon pas
# marcher au-delà des zones réellement chargées (_is_within_loaded_world),
# donc pas besoin de bloquer physiquement ces patchs.
func _load_border_fillers(root: Node2D) -> void:
	for zone in zones:
		for patch in BorderFillers.PATCHES.get(zone.name, []):
			var scene := load(String(patch.scene)) as PackedScene
			if scene == null:
				continue
			var inst := scene.instantiate()
			inst.position = zone.rect.position + Vector2(patch.offset) * TILE_SIZE
			root.add_child(inst)
			root.move_child(inst, 0)   # sous le joueur, comme "Below"

func _attach_layers(root: Node2D, node: Node, world_off: Vector2) -> void:
	for layer_name in ["Below", "Above", "Collision"]:
		var n := node.get_node_or_null(layer_name)
		if n == null:
			continue
		node.remove_child(n)
		n.position += world_off
		n.owner = null
		root.add_child(n)
		if layer_name == "Below":
			root.move_child(n, 0)   # doit rester derrière le joueur
	node.queue_free()   # Player/Camera de la carte voisine : inutiles ici

func _zone_by_name(zone_name: String):
	for z in zones:
		if z.name == zone_name:
			return z
	return null

# Zone (dict) contenant ce point (coords locales à cette scène), ou null si
# hors de tout ce qui est chargé.
func _zone_at_pixel(p: Vector2):
	for z in zones:
		if z.rect.has_point(p):
			return z
	return null

func _update_camera_bounds() -> void:
	var cam := $Camera2D
	var bounds: Rect2 = zones[0].rect
	for z in zones:
		bounds = bounds.merge(z.rect)
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.position.x + bounds.size.x)
	cam.limit_bottom = int(bounds.position.y + bounds.size.y)

# Vrai si la case visée est dans une carte déjà chargée (origine ou voisine
# rattachée) — donc pas besoin de transition/téléportation.
func _is_within_loaded_world(tgt: Vector2i) -> bool:
	return _zone_at_pixel(Vector2(tgt) * TILE_SIZE) != null

# Appelé après chaque pas terminé : détecte si le joueur vient de passer sous
# les pieds d'une autre carte chargée (ou d'y revenir), pour le bandeau de nom
# de lieu.
func _update_current_zone() -> void:
	var zone = _zone_at_pixel(position)
	var new_name: String = zone.name if zone != null else origin_map_name
	if new_name != current_map_name:
		current_map_name = new_name
		# Certaines cartes sont scindées en plusieurs scènes (ex. route21_north/
		# route21_south) mais partagent le même nom affiché en français : ne
		# montrer le bandeau que si le nom affiché change réellement, pas juste
		# l'id de scène interne.
		if MapNames.get_french_name(current_map_name) != last_banner_name:
			_show_location_banner(current_map_name)

func _show_location_banner(scene_id: String) -> void:
	last_banner_name = MapNames.get_french_name(scene_id)
	var banner := LocationBannerScene.instantiate()
	get_tree().current_scene.add_child(banner)
	banner.show_name(last_banner_name)

# Démarre une nouvelle visite (balls/captures à zéro) seulement à la première
# entrée dans une des 4 maps de la Zone Safari. La sortie (et le choix du
# partenaire) est gérée par safari_entrance_gate.gd.
func _update_safari_state() -> void:
	var scene_name := get_tree().current_scene.scene_file_path.get_file().get_basename()
	if scene_name in SafariState.SAFARI_MAPS and not SafariState.active:
		SafariState.enter()

# Convertit une case (coords locales à cette scène) en case locale à la zone
# qui la contient, ou null si hors de tout ce qui est chargé.
func _zone_and_local_tile(tile: Vector2i) -> Array:
	var zone = _zone_at_pixel(Vector2(tile) * TILE_SIZE)
	if zone == null:
		return [null, Vector2i.ZERO]
	var local: Vector2i = tile - Vector2i(zone.rect.position / TILE_SIZE)
	return [zone, local]

# Case de hautes herbes ? (Zone Safari — voir SafariState.active pour l'activation)
# Cherche dans la zone (origine ou voisine chargée) qui contient cette case.
func _is_grass(tile: Vector2i) -> bool:
	var res := _zone_and_local_tile(tile)
	var zone = res[0]
	if zone == null:
		return false
	var local: Vector2i = res[1]
	var size: Vector2i = zone.size
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return false
	var idx := local.y * size.x + local.x
	var arr: Array = zone.grass
	return idx >= 0 and idx < arr.size() and bool(arr[idx])

# Case d'eau surfable/pêchable (fidèle FRLG, voir build_godot.py) ?
func _is_water(tile: Vector2i) -> bool:
	var res := _zone_and_local_tile(tile)
	var zone = res[0]
	if zone == null:
		return false
	var local: Vector2i = res[1]
	var size: Vector2i = zone.size
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return false
	var idx := local.y * size.x + local.x
	var arr: Array = zone.get("water", [])
	return idx >= 0 and idx < arr.size() and bool(arr[idx])

# Élévation d'une case (0 si zone/case introuvable ou hors tableau — traité
# comme "passe-partout", cf. _elevation_blocks()).
func _elevation_at(tile: Vector2i) -> int:
	var res := _zone_and_local_tile(tile)
	var zone = res[0]
	if zone == null:
		return 0
	var local: Vector2i = res[1]
	var size: Vector2i = zone.size
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return 0
	var idx := local.y * size.x + local.x
	var arr: Array = zone.get("elevation", [])
	return int(arr[idx]) if idx >= 0 and idx < arr.size() else 0

# Fidèle FRLG : deux cases adjacentes d'élévations différentes et non nulles
# sont infranchissables (falaise), même sans collision propre sur les tuiles
# elles-mêmes. Élévation 0 = "passe-partout" (ponts, cases neutres).
func _elevation_blocks(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	# L'eau a sa propre élévation (zones de courant), sans rapport avec les
	# niveaux de falaise — la frontière eau/terre est déjà gérée par la
	# règle dédiée au Surf (voir water_blocks), pas par celle-ci.
	if _is_water(from_tile) or _is_water(to_tile):
		return false
	var e_from := _elevation_at(from_tile)
	var e_to := _elevation_at(to_tile)
	return e_from != 0 and e_to != 0 and e_from != e_to

# Warp ponctuel sur cette case (porte, entrée de grotte...), ou null si aucun.
func _warp_at(tile: Vector2i) -> Dictionary:
	var res := _zone_and_local_tile(tile)
	var zone = res[0]
	if zone == null:
		return {}
	var local: Vector2i = res[1]
	for w in zone.warps:
		if int(w.get("x", -1)) == local.x and int(w.get("y", -1)) == local.y:
			return w
	return {}

# Direction du rebord sur cette case ("down"/"up"/"left"/"right"), ou "" si aucun.
func _ledge_dir_at(tile: Vector2i) -> String:
	var res := _zone_and_local_tile(tile)
	var zone = res[0]
	if zone == null:
		return ""
	var local: Vector2i = res[1]
	var size: Vector2i = zone.size
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return ""
	var idx := local.y * size.x + local.x
	var arr: Array = zone.ledges
	if idx < 0 or idx >= arr.size():
		return ""
	return String(arr[idx])

func _entry_tile(from_dir: String, cross: int) -> Vector2i:
	match from_dir:
		"up":   return Vector2i(cross, map_size.y - 1)   # sorti par le haut -> entre en bas
		"down": return Vector2i(cross, 0)                # sorti par le bas -> entre en haut
		"left": return Vector2i(map_size.x - 1, cross)   # entre à droite
		_:      return Vector2i(0, cross)                # entre à gauche

var interact_cooldown := 0.0   # évite de ré-ouvrir un dialogue avec la touche qui vient de le fermer

func _physics_process(delta: float) -> void:
	if interact_cooldown > 0.0:
		interact_cooldown -= delta
	if is_busy:
		return
	if is_moving == false and turn_timer <= 0.0 and interact_cooldown <= 0.0 and Input.is_action_just_pressed("ui_cancel"):
		_open_pause_menu()
		return
	if is_moving == false and turn_timer <= 0.0 and interact_cooldown <= 0.0 and Input.is_action_just_pressed("ui_accept"):
		_try_interact()
		return
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

func _facing_offset(f: String) -> Vector2i:
	match f:
		"south": return Vector2i(0, 1)
		"north": return Vector2i(0, -1)
		"west":  return Vector2i(-1, 0)
		_:       return Vector2i(1, 0)

const INTERACT_RANGE := 2   # portée en cases (permet de parler par-dessus un comptoir)

func _try_interact() -> void:
	var cur := Vector2i(roundi(position.x / TILE_SIZE), roundi(position.y / TILE_SIZE))
	var offset := _facing_offset(facing)
	var npcs := get_tree().get_nodes_in_group("npc")
	for dist in range(1, INTERACT_RANGE + 1):
		var target_tile := cur + offset * dist
		for npc in npcs:
			if npc.tile() == target_tile:
				_talk_to(npc, cur)
				return
	# Rien à qui parler : essaie la Canne à pêche/le Surf si on fait face à
	# l'eau. Si on a les deux, PlayerData.preferred_water_tool tranche (choisi
	# depuis le sac, scripts/bag.gd) — sinon celui qu'on possède gagne.
	if not is_surfing and _is_water(cur + offset):
		if PlayerData.has_surf and PlayerData.has_fishing_rod:
			if PlayerData.preferred_water_tool == "rod":
				_start_fishing()
			else:
				_start_surfing()
		elif PlayerData.has_surf:
			_start_surfing()
		elif PlayerData.has_fishing_rod:
			_start_fishing()

func _talk_to(npc: Node, player_tile: Vector2i) -> void:
	if npc.has_method("face_toward"):
		npc.face_toward(player_tile)
	var lines: Array[String] = npc.get_lines()
	if lines.is_empty():
		return
	is_busy = true
	is_moving = false
	_play("face")
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.finished.connect(func():
		dialogue.queue_free()
		is_busy = false
		interact_cooldown = 0.2
	)
	dialogue.say(lines)

func _open_pause_menu() -> void:
	is_busy = true
	var menu := PauseMenuScene.instantiate()
	get_tree().current_scene.add_child(menu)
	menu.closed.connect(func():
		menu.queue_free()
		is_busy = false
		interact_cooldown = 0.2
	)

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

	# Bord de map franchi ? -> transition si connexion vers une scène existante,
	# sauf si une carte voisine est déjà chargée en recouvrement à cet endroit
	# (transition fluide, voir _load_neighbor_overlays) : dans ce cas on laisse
	# le joueur continuer normalement, ses tuiles sont déjà là.
	var cur := Vector2i(roundi(position.x / TILE_SIZE), roundi(position.y / TILE_SIZE))
	var tgt := cur + Vector2i(int(dir.x), int(dir.y))
	if not _is_within_loaded_world(tgt):
		_try_transition(dir, cur)
		return

	# Warp ponctuel (porte, entrée de grotte) : téléportation à coord précise.
	var warp := _warp_at(tgt)
	if not warp.is_empty():
		var root := get_parent()
		# Point d'extension : la map peut verrouiller certains warps (ex. scène
		# scriptée) en implémentant gate_check()/on_gate_blocked().
		if root and root.has_method("gate_check") and not root.gate_check(warp):
			if root.has_method("on_gate_blocked"):
				root.on_gate_blocked(warp, self)
			return
		var target := String(warp.get("target", ""))
		var path := "res://scenes/maps/%s.tscn" % target
		if ResourceLoader.exists(path):
			is_busy = true
			# Descente automatique du Vélo en empruntant un warp vers un vrai
			# bâtiment/une grotte — pas de vélo en intérieur, même logique
			# silencieuse que le Surf qui descend automatiquement sur terre ferme.
			# Exception : les 4 zones du Parc Safari se traversent aussi via des
			# warps (pas des connexions de bord de carte comme les routes), mais
			# restent des zones EXTÉRIEURES — on y reste à vélo.
			if target not in SafariState.SAFARI_MAPS:
				PlayerData.is_biking = false
			Transitions.pending = true
			Transitions.direct = true
			Transitions.facing = String(warp.get("face", facing))
			Transitions.direct_tile = Vector2i(int(warp.get("tx", 0)), int(warp.get("ty", 0)))
			await ScreenFade.fade_out()
			get_tree().change_scene_to_file(path)
			return

	# Rebord franchissable dans ce sens : saut de 2 cases (fidèle à FRLG),
	# on ignore la collision du rebord lui-même.
	var dname := _dir_name(dir)
	if _ledge_dir_at(tgt) == dname:
		current_speed = JUMP_SPEED
		is_jumping = true
		jump_total_dist = TILE_SIZE * 2
		move_target = position + dir * TILE_SIZE * 2
		is_moving = true
		pending_encounter_check = false
		_consume_repel_step()
		_play("walk")
		return

	var water_blocks := _is_water(tgt) and not is_surfing   # eau interdite sans Surf ; jamais bloqué pour débarquer
	var motion := dir * TILE_SIZE
	if test_move(global_transform, motion) or _elevation_blocks(cur, tgt) or water_blocks:
		_play("face")            # bloqué : face à l'obstacle, sans avancer
	else:
		current_speed = BIKE_SPEED if (PlayerData.is_biking and not is_surfing) else SPEED
		is_jumping = false
		move_target = position + motion
		is_moving = true
		pending_encounter_check = SafariState.active and SafariState.hunting_unlocked and PlayerData.repel_steps_remaining <= 0 and _is_grass(tgt)
		_consume_repel_step()
		_play("walk")

# Décompte du Répulsif (voir PlayerData.repel_steps_remaining) : 1 pas
# consommé par case franchie, en herbe ou non, comme dans les jeux d'origine.
func _consume_repel_step() -> void:
	if PlayerData.repel_steps_remaining > 0:
		PlayerData.repel_steps_remaining -= 1
		if PlayerData.repel_steps_remaining == 0:
			pending_repel_expired_notice = true

func _try_transition(dir: Vector2, cur: Vector2i) -> void:
	var dname := _dir_name(dir)
	for c in connections:
		if String(c.get("dir")) == dname:
			var target := String(c.get("target", ""))
			var path := "res://scenes/maps/%s.tscn" % target
			if ResourceLoader.exists(path):
				var off := int(c.get("offset", 0))
				is_busy = true
				Transitions.pending = true
				Transitions.direct = false
				Transitions.from_dir = dname
				Transitions.facing = facing
				if dname == "up" or dname == "down":
					Transitions.cross = int(cur.x - off)
				else:
					Transitions.cross = int(cur.y - off)
				await ScreenFade.fade_out()
				get_tree().change_scene_to_file(path)
				return
	_play("face")   # pas de connexion utilisable : mur

func _move_toward_target(delta: float) -> void:
	var diff := move_target - position
	var step := current_speed * delta
	if diff.length() <= step:
		position = move_target
		is_moving = false
		if is_jumping:
			is_jumping = false
			anim.position.y = 0.0
		if zones.size() > 1:
			_update_current_zone()
		# Fidèle FRLG : on descend automatiquement de l'eau dès qu'on pose le
		# pied sur une case praticable à sec (pas de confirmation nécessaire).
		if is_surfing and not _is_water(Vector2i(roundi(position.x / TILE_SIZE), roundi(position.y / TILE_SIZE))):
			is_surfing = false
			_update_movement_sprite()
		if pending_encounter_check:
			pending_encounter_check = false
			if randf() < ENCOUNTER_CHANCE:
				_start_encounter()
		if pending_repel_expired_notice:
			pending_repel_expired_notice = false
			_notify_repel_expired()
	else:
		position += diff.normalized() * step
	if is_jumping:
		var progress := 1.0 - (move_target - position).length() / jump_total_dist
		anim.position.y = -JUMP_ARC_HEIGHT * sin(progress * PI)

# Fidèle FRLG : message automatique dès que le Répulsif arrive à 0 pas
# restants, affiché une fois la case d'arrivée atteinte (voir
# _move_toward_target). Bloque le déplacement le temps du message, comme
# n'importe quelle autre boîte de dialogue.
func _notify_repel_expired() -> void:
	is_busy = true
	_play("face")
	await _say_line("Le Répulsif a cessé de faire effet !")
	is_busy = false

# Petite boîte de dialogue à une seule ligne, attend que le joueur la ferme.
func _say_line(text: String) -> void:
	var lines: Array[String] = [text]
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()

# Surf (test, voir acte1-parc-safari.md) : confirmation Oui/Non avant de se
# lancer (fidèle FRLG, évite un faux clic), la descente reste automatique dès
# qu'on retouche terre (voir _move_toward_target()). Vrai sprite FRLG
# (red_surf_run/green_surf_run) si disponible pour l'apparence actuelle,
# sinon le perso garde son apparence normale (Brendan/May, pas de sprite Surf
# dans notre décompilation FireRed/LeafGreen — voir _prepare_surf_sprite_frames()).
func _start_surfing() -> void:
	is_busy = true
	_play("face")

	var ask_lines: Array[String] = ["Il y a de l'eau devant toi. Tu veux surfer ?"]
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(ask_lines)
	await dialogue.page_typed
	dialogue.active = false
	var choice := YesNoChoiceScene.instantiate()
	get_tree().current_scene.add_child(choice)
	var confirmed: bool = await choice.chosen
	choice.queue_free()
	dialogue.queue_free()
	if not confirmed:
		is_busy = false
		interact_cooldown = 0.2
		return

	await _say_line("Tu montes sur la planche et te lances sur l'eau !")
	is_surfing = true
	_update_movement_sprite()

	# Fidèle FRLG : monter sur l'eau avance automatiquement d'une case (voir
	# object_event_anims.h::ANIM_GET_ON_OFF_POKEMON_*). On pilote le pas à la
	# main (is_busy bloque _physics_process, donc _move_toward_target() ne
	# serait jamais appelée sinon) plutôt que de repasser par le chemin normal
	# d'entrée utilisateur.
	current_speed = SPEED
	pending_encounter_check = false
	move_target = position + Vector2(_facing_offset(facing)) * TILE_SIZE
	is_moving = true
	_play("walk")
	while is_moving:
		await get_tree().process_frame
		_move_toward_target(get_process_delta_time())

	is_busy = false
	interact_cooldown = 0.2

# Canne à pêche (test, voir acte1-parc-safari.md) : lancer de ligne, attente,
# touche aléatoire, puis fenêtre courte pour ferrer avant que le poisson ne
# reparte — fidèle à la structure du vrai jeu (une seule canne pour
# l'instant, pas de distinction Vieille Canne/Canne Suprême).
const FISH_BITE_CHANCE := 0.5
const FISH_HOOK_WINDOW := 1.5   # secondes pour appuyer une fois la touche affichée

func _start_fishing() -> void:
	is_busy = true
	_play("face")
	var animated := fish_sprite_frames != null
	if animated:
		anim.sprite_frames = fish_sprite_frames
		_play("cast")
		await anim.animation_finished
		_play("idle_rod")

	await _say_line("Tu lances ta ligne à l'eau...")
	await get_tree().create_timer(randf_range(0.8, 1.6)).timeout
	if randf() >= FISH_BITE_CHANCE:
		await _say_line("Ce n'était rien...")
		await _end_fishing(animated)
		return

	if animated:
		_play("bite")
	await _say_line("Oh ! Une touche !")
	var hooked := false
	var remaining := FISH_HOOK_WINDOW
	while remaining > 0.0:
		if Input.is_action_just_pressed("ui_accept"):
			hooked = true
			break
		remaining -= get_process_delta_time()
		await get_tree().process_frame
	if not hooked:
		await _say_line("Zut, ça s'est échappé !")
		await _end_fishing(animated)
		return

	await _end_fishing(animated)
	_start_encounter()

# Range la canne (animation inverse du lancer) avant de rendre la main —
# seulement si un vrai sprite de pêche est actif (sinon rien à ranger, voir
# fish_sprite_frames). Remet ensuite le bon sprite (normal/Surf/Vélo).
func _end_fishing(animated: bool) -> void:
	if animated:
		_play("putaway")
		await anim.animation_finished
		_update_movement_sprite()
	is_busy = false
	interact_cooldown = 0.2

func _start_encounter() -> void:
	_play("face")
	is_busy = true
	var transition := BattleTransitionScene.instantiate()
	get_tree().current_scene.add_child(transition)
	await transition.play_close()
	var encounter := EncounterScene.instantiate()
	get_tree().current_scene.add_child(encounter)
	await transition.play_open()
	transition.queue_free()
	await encounter.play_entrance()
	await encounter.finished

	# Simple fondu noir (comme une entrée de bâtiment via ScreenFade), pas le
	# rideau flash+fermeture de l'entrée en combat — demandé par Gus, le rideau
	# de combat faisait trop pour un simple retour sur la map.
	await ScreenFade.fade_out()
	encounter.queue_free()
	await ScreenFade.fade_in()

	if SafariState.balls <= 0:
		var dialogue := DialogueBoxScene.instantiate()
		get_tree().current_scene.add_child(dialogue)
		var lines: Array[String] = ["Tu n'as plus de Safari Balls ! On te raccompagne à l'entrée."]
		dialogue.say(lines)
		await dialogue.finished
		dialogue.queue_free()
		Transitions.pending = true
		Transitions.direct = true
		Transitions.facing = "south"
		Transitions.direct_tile = Vector2i(4, 2)   # atterrissage porte nord de safari_entrance
		await ScreenFade.fade_out()
		get_tree().change_scene_to_file("res://scenes/maps/safari_entrance.tscn")
		return
	is_busy = false
	interact_cooldown = 0.2

# East réutilise les frames "west" retournées horizontalement.
func _play(prefix: String) -> void:
	anim.flip_h = (facing == "east")
	var suffix := "west" if facing == "east" else facing
	anim.play(prefix + "_" + suffix)
