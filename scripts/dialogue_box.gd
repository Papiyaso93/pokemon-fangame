extends CanvasLayer

# Boîte de dialogue réutilisable (overworld + intro). Affiche une file de
# lignes de texte, effet machine à écrire (fidèle FRLG), avance à l'appui sur
# "ui_accept" (Entrée / Espace / A) — un appui pendant l'écriture affiche le
# reste du texte instantanément ; un appui une fois complet passe à la ligne
# suivante. Flèche de continuation (vrais sprites FRLG) tant qu'il reste du
# texte à afficher.

signal finished
signal page_typed   # émis quand le texte de la page en cours a fini de s'afficher

const ARROW_BLINK := 0.3   # secondes entre les 2 frames de la flèche

@onready var panel: NinePatchRect = $Panel
@onready var label: Label = $Panel/Label
@onready var arrow: TextureRect = $Panel/Arrow

const MAX_LINES_PER_PAGE := 2   # fidèle FRLG : jamais plus de 2 lignes affichées à la fois

var queue: Array[String] = []
var active := false

var pages: Array[String] = []
var page_idx := 0

# Pause forcée après une ligne précise de la file (ex. remise d'un objet,
# le temps de laisser jouer un son/une anim) : la flèche de continuation
# reste masquée et les entrées sont ignorées tant que la pause n'est pas
# écoulée — même boîte de dialogue du début à la fin, pas de fermeture/
# réouverture. Index dans la file passée à say(), pas dans les pages.
var pause_after_index := -1
var pause_seconds := 0.0
var current_index := -1
var is_paused := false

var typewriter: Typewriter

var arrow_frame := 0
var arrow_timer := 0.0
const ARROW_TEXTURES := [
	preload("res://assets/ui/down_arrow_3.png"),
	preload("res://assets/ui/down_arrow_4.png"),
]

func _ready() -> void:
	visible = false
	arrow.visible = false
	typewriter = Typewriter.new(label)
	typewriter.completed.connect(_on_page_typed)

func say(lines: Array[String], pause_after: int = -1, pause_for: float = 0.0) -> void:
	queue = lines.duplicate()
	active = true
	visible = true
	current_index = -1
	pause_after_index = pause_after
	pause_seconds = pause_for
	_show_next()

func _show_next() -> void:
	arrow.visible = false
	if queue.is_empty():
		active = false
		visible = false
		finished.emit()
		return
	current_index += 1
	pages = _paginate(String(queue.pop_front()))
	page_idx = 0
	_show_page()

func _show_page() -> void:
	# Fenêtre glissante (voir _paginate) : à partir de la 2e page, la 1re ligne
	# de la page courante est toujours la dernière ligne déjà affichée à la
	# page précédente. On l'affiche instantanément (pas de retype, jamais de
	# boîte vide) et on n'anime que la ligne réellement nouvelle.
	var prefix_len := 0
	if page_idx > 0:
		var first_line := pages[page_idx].split("\n")[0]
		prefix_len = first_line.length() + 1   # +1 pour le \n déjà "acquis"
	typewriter.start(pages[page_idx], prefix_len)

func _on_page_typed() -> void:
	var is_last_page_of_item := page_idx + 1 >= pages.size()
	if is_last_page_of_item and current_index == pause_after_index and pause_seconds > 0.0:
		is_paused = true
		await get_tree().create_timer(pause_seconds).timeout
		is_paused = false
	arrow.visible = page_idx + 1 < pages.size() or not queue.is_empty()
	page_typed.emit()

# Découpe le texte en pages d'au maximum MAX_LINES_PER_PAGE lignes, selon la
# largeur réelle du Label et de la police en cours — pour que le joueur voie
# toujours au plus 2 lignes à la fois, le reste apparaissant à l'appui sur le
# bouton d'action (comme dans le vrai jeu), au lieu de déborder de la boîte.
func _paginate(text: String) -> Array[String]:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var max_width := label.size.x
	var lines: Array[String] = []
	var current_line := ""
	for word in text.split(" "):
		var candidate := word if current_line.is_empty() else current_line + " " + word
		var w := font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > max_width and not current_line.is_empty():
			lines.append(current_line)
			current_line = word
		else:
			current_line = candidate
	if not current_line.is_empty():
		lines.append(current_line)
	if lines.is_empty():
		lines.append("")

	# Fenêtre glissante d'une ligne (fidèle FRLG) : la page suivante garde la
	# dernière ligne affichée et ajoute la suivante, plutôt que de repartir
	# de zéro par paires de lignes indépendantes.
	var result: Array[String] = []
	var i := 0
	while true:
		var end := mini(i + MAX_LINES_PER_PAGE, lines.size())
		result.append("\n".join(lines.slice(i, end)))
		if end >= lines.size():
			break
		i += 1
	return result

func _process(delta: float) -> void:
	if typewriter.typing:
		typewriter.update(delta)
	elif arrow.visible:
		arrow_timer += delta
		if arrow_timer >= ARROW_BLINK:
			arrow_timer = 0.0
			arrow_frame = 1 - arrow_frame
			arrow.texture = ARROW_TEXTURES[arrow_frame]

func _unhandled_input(event: InputEvent) -> void:
	if not active or is_paused:
		return
	if event.is_action_pressed("ui_accept"):
		if typewriter.typing:
			typewriter.skip()
		elif page_idx + 1 < pages.size():
			page_idx += 1
			_show_page()
		else:
			_show_next()
		get_viewport().set_input_as_handled()
