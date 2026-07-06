extends CanvasLayer

# Fenêtre de choix seule (les options, rien d'autre) — la question elle-même
# s'affiche dans une boîte de dialogue classique tenue ouverte par l'appelant
# (voir safari_entrance_gate.gd), fidèle au même principe que class_choice.gd.
#
# Liste défilante si trop de captures pour tenir dans une hauteur raisonnable
# (signalé par Gus : la fenêtre débordait carrément de l'écran avec beaucoup
# de captures). Défilement natif Godot (molette/glisser) plutôt que des
# boutons flèche ou une pagination "voir plus" — pas de clic supplémentaire
# pour comparer toutes les captures. Petites flèches haut/bas clignotantes en
# indice visuel (même asset que la flèche "suite" de dialogue_box.gd),
# affichées seulement s'il y a du contenu cache dans cette direction.

signal chosen(species: String)

const ArrowTexture := preload("res://assets/ui/choice_arrow.png")
const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const SCROLL_ARROW_TEXTURES := [
	preload("res://assets/ui/down_arrow_3.png"),
	preload("res://assets/ui/down_arrow_4.png"),
]

# Marges pour caler la fenêtre juste au-dessus de la boîte de dialogue
# (offset_top=-168 dans dialogue_box.tscn), même bord droit qu'elle (24px).
const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 172.0
const ARROW_BLINK := 0.3
const MAX_LIST_HEIGHT := 200.0   # au-delà, la liste défile (~5 lignes visibles)

@onready var window: PanelContainer = $Root/Window
@onready var scroll: ScrollContainer = $Root/Window/VBox/Scroll
@onready var buttons_box: VBoxContainer = $Root/Window/VBox/Scroll/Buttons
@onready var up_arrow: TextureRect = $Root/Window/VBox/UpArrow
@onready var down_arrow: TextureRect = $Root/Window/VBox/DownArrow

var arrow_frame := 0
var arrow_timer := 0.0
var scrollable := false   # true si la liste dépasse MAX_LIST_HEIGHT

func _ready() -> void:
	# Caché tant que _place_window() n'a pas calculé sa position définitive —
	# sinon la fenêtre apparaît une frame en haut à gauche (position par
	# défaut) avant de "sauter" à sa place, un flash bref mais visible.
	window.visible = false
	up_arrow.visible = false
	down_arrow.visible = false
	scroll.get_v_scroll_bar().value_changed.connect(_update_arrows)

func setup(species_list: Array[String]) -> void:
	for species in species_list:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 0)
		btn.text = species
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = false
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = BlankTexture
		btn.mouse_entered.connect(func(): btn.icon = ArrowTexture)
		btn.mouse_exited.connect(func(): btn.icon = BlankTexture)
		btn.pressed.connect(func(): chosen.emit(species))
		buttons_box.add_child(btn)
	await get_tree().process_frame
	var natural_height: float = buttons_box.get_combined_minimum_size().y
	scrollable = natural_height > MAX_LIST_HEIGHT
	scroll.custom_minimum_size.y = minf(natural_height, MAX_LIST_HEIGHT)
	# Les flèches ne réservent de la place que si la liste défile vraiment —
	# sinon `visible` reste figé à false posé dans _ready() (pas de bascule
	# plus tard, donc pas de redimensionnement surprise de la fenêtre).
	up_arrow.visible = scrollable
	down_arrow.visible = scrollable
	await get_tree().process_frame
	_place_window()
	_update_arrows(0.0)
	window.visible = true

# Taille la fenêtre à son contenu (PanelContainer ne le fait pas tout seul
# hors d'un Container parent) et la cale en haut à droite de la boîte de
# dialogue plutôt qu'au centre de l'écran.
func _place_window() -> void:
	var min_size := window.get_combined_minimum_size()
	window.size = min_size
	var viewport_size := get_viewport().get_visible_rect().size
	window.position = Vector2(
		viewport_size.x - MARGIN_RIGHT - min_size.x,
		viewport_size.y - MARGIN_BOTTOM - min_size.y,
	)

# Une fois affichées, les flèches restent dans la mise en page (évite tout
# redimensionnement de la fenêtre pendant le défilement) — seule leur
# opacité change selon qu'il reste du contenu caché dans cette direction.
func _update_arrows(_value: float) -> void:
	if not scrollable:
		return
	var bar := scroll.get_v_scroll_bar()
	up_arrow.modulate.a = 1.0 if bar.value > 0.0 else 0.0
	down_arrow.modulate.a = 1.0 if bar.value < bar.max_value - bar.page - 1.0 else 0.0

func _process(delta: float) -> void:
	if not scrollable:
		return
	arrow_timer += delta
	if arrow_timer >= ARROW_BLINK:
		arrow_timer = 0.0
		arrow_frame = 1 - arrow_frame
		up_arrow.texture = SCROLL_ARROW_TEXTURES[arrow_frame]
		down_arrow.texture = SCROLL_ARROW_TEXTURES[arrow_frame]
