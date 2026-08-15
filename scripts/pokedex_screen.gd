extends CanvasLayer

signal closed

# Pokédex (test, cf. HANDOFF.md) — v1 volontairement simple : liste triée par
# n° de Dex national + fiche détail (sprite, catégorie, taille/poids,
# description). Pas de cri, pas de page Zone, pas de recherche par catégorie/
# tri alternatif pour l'instant (décision de Gus, on construit d'abord la
# base). Accessible depuis le Sac (test), poche Objets Clés — pas encore un
# vrai objet possédé, juste une entrée fixe en attendant de définir à quel
# moment le joueur l'obtient réellement.

const BlankTexture := preload("res://assets/ui/choice_arrow_blank.png")
const ArrowTexture := preload("res://assets/ui/choice_arrow.png")

# Contrairement aux jeux d'origine, le Pokédex recense déjà toutes les
# espèces de Kanto dès le départ (voir game-design.md) — sauf les
# légendaires et les fossiles, qui restent "???" tant qu'on ne les a pas
# rencontrés pour de vrai (les fossiles ne sont d'ailleurs pas présents dans
# le Parc Safari). Liste en dur : species_data.gd est généré depuis
# kanto-pipeline (voir son en-tête, "ne pas éditer à la main"), donc pas de
# champ is_legendary/is_fossil à lire dedans — ces 10 espèces sont fixes et
# connues pour Kanto, pas besoin d'un vrai champ de données pour ça.
const HIDDEN_UNTIL_SEEN: Array[String] = [
	"articuno", "zapdos", "moltres", "mewtwo", "mew",
	"omanyte", "omastar", "kabuto", "kabutops", "aerodactyl",
]

# Catégories ("Pokémon Graine", etc.) traduites à la main, même principe que
# les descriptions (species_data.gd généré depuis kanto-pipeline, en
# anglais, pas de source française trouvée dans le pipeline).
const CATEGORIES_FR: Dictionary = {
	"bulbasaur": "Graine",
	"ivysaur": "Graine",
	"venusaur": "Graine",
	"charmander": "Lézard",
	"charmeleon": "Flamme",
	"charizard": "Flamme",
	"squirtle": "Petite Tortue",
	"wartortle": "Tortue",
	"blastoise": "Coquillage",
	"caterpie": "Ver",
	"metapod": "Cocon",
	"butterfree": "Papillon",
	"weedle": "Insecte Poilu",
	"kakuna": "Cocon",
	"beedrill": "Abeille Venin",
	"pidgey": "Petit Oiseau",
	"pidgeotto": "Oiseau",
	"pidgeot": "Oiseau",
	"rattata": "Souris",
	"raticate": "Souris",
	"spearow": "Petit Oiseau",
	"fearow": "Bec",
	"ekans": "Serpent",
	"arbok": "Cobra",
	"pikachu": "Souris",
	"raichu": "Souris",
	"sandshrew": "Souris",
	"sandslash": "Souris",
	"nidoran_f": "Piquant Venin",
	"nidorina": "Piquant Venin",
	"nidoqueen": "Perceuse",
	"nidoran_m": "Piquant Venin",
	"nidorino": "Piquant Venin",
	"nidoking": "Perceuse",
	"clefairy": "Fée",
	"clefable": "Fée",
	"vulpix": "Renard",
	"ninetales": "Renard",
	"jigglypuff": "Ballon",
	"wigglytuff": "Ballon",
	"zubat": "Chauve-souris",
	"golbat": "Chauve-souris",
	"oddish": "Herbe",
	"gloom": "Herbe",
	"vileplume": "Fleur",
	"paras": "Champignon",
	"parasect": "Champignon",
	"venonat": "Insecte",
	"venomoth": "Papillon Venin",
	"diglett": "Taupe",
	"dugtrio": "Taupe",
	"meowth": "Chat Griffu",
	"persian": "Chat Classe",
	"psyduck": "Canard",
	"golduck": "Canard",
	"mankey": "Singe Porcin",
	"primeape": "Singe Porcin",
	"growlithe": "Chiot",
	"arcanine": "Légendaire",
	"poliwag": "Têtard",
	"poliwhirl": "Têtard",
	"poliwrath": "Têtard",
	"abra": "Psy",
	"kadabra": "Psy",
	"alakazam": "Psy",
	"machop": "Superpuissance",
	"machoke": "Superpuissance",
	"machamp": "Superpuissance",
	"bellsprout": "Fleur",
	"weepinbell": "Gobe-mouche",
	"victreebel": "Gobe-mouche",
	"tentacool": "Méduse",
	"tentacruel": "Méduse",
	"geodude": "Roche",
	"graveler": "Roche",
	"golem": "Mégatonne",
	"ponyta": "Cheval de Feu",
	"rapidash": "Cheval de Feu",
	"slowpoke": "Ahuri",
	"slowbro": "Bernard-l'Ermite",
	"magnemite": "Aimant",
	"magneton": "Aimant",
	"farfetchd": "Canard Sauvage",
	"doduo": "Oiseau Jumeau",
	"dodrio": "Oiseau Triple",
	"seel": "Otarie",
	"dewgong": "Otarie",
	"grimer": "Boue",
	"muk": "Boue",
	"shellder": "Bivalve",
	"cloyster": "Bivalve",
	"gastly": "Gaz",
	"haunter": "Gaz",
	"gengar": "Ombre",
	"onix": "Serpent de Roche",
	"drowzee": "Hypnose",
	"hypno": "Hypnose",
	"krabby": "Crabe des Rivières",
	"kingler": "Pince",
	"voltorb": "Boule",
	"electrode": "Boule",
	"exeggcute": "Œuf",
	"exeggutor": "Noix de Coco",
	"cubone": "Solitaire",
	"marowak": "Gardien d'Os",
	"hitmonlee": "Coup de Pied",
	"hitmonchan": "Coup de Poing",
	"lickitung": "Léchage",
	"koffing": "Gaz Toxique",
	"weezing": "Gaz Toxique",
	"rhyhorn": "Piquants",
	"rhydon": "Perceuse",
	"chansey": "Œuf",
	"tangela": "Liane",
	"kangaskhan": "Parent",
	"horsea": "Dragon",
	"seadra": "Dragon",
	"goldeen": "Poisson Rouge",
	"seaking": "Poisson Rouge",
	"staryu": "Forme d'Étoile",
	"starmie": "Mystérieux",
	"mr_mime": "Barrière",
	"scyther": "Mante",
	"jynx": "Forme Humaine",
	"electabuzz": "Électrique",
	"magmar": "Cracheur de Feu",
	"pinsir": "Cerf-volant",
	"tauros": "Taureau Sauvage",
	"magikarp": "Poisson",
	"gyarados": "Atroce",
	"lapras": "Transport",
	"ditto": "Métamorphe",
	"eevee": "Évolution",
	"vaporeon": "Jet de Bulles",
	"jolteon": "Éclair",
	"flareon": "Flamme",
	"porygon": "Virtuel",
	"omanyte": "Spirale",
	"omastar": "Spirale",
	"kabuto": "Coquillage",
	"kabutops": "Coquillage",
	"aerodactyl": "Fossile",
	"snorlax": "Dormeur",
	"articuno": "Gel",
	"zapdos": "Électrique",
	"moltres": "Flamme",
	"dratini": "Dragon",
	"dragonair": "Dragon",
	"dragonite": "Dragon",
	"mewtwo": "Génétique",
	"mew": "Nouvelle Espèce",
}

@onready var stats_label: Label = $Root/Center/Window/VBox/StatsLabel
@onready var list_page: Control = $Root/Center/Window/VBox/ListPage
@onready var rows_box: VBoxContainer = $Root/Center/Window/VBox/ListPage/Scroll/Buttons
@onready var detail_page: Control = $Root/Center/Window/VBox/DetailPage
@onready var detail_sprite: TextureRect = $Root/Center/Window/VBox/DetailPage/HBox/Sprite
@onready var detail_title: Label = $Root/Center/Window/VBox/DetailPage/HBox/Info/Title
@onready var detail_category: Label = $Root/Center/Window/VBox/DetailPage/HBox/Info/Category
@onready var detail_size: Label = $Root/Center/Window/VBox/DetailPage/HBox/Info/Size
@onready var detail_description: Label = $Root/Center/Window/VBox/DetailPage/Description
@onready var hint: Label = $Root/Center/Window/VBox/Hint

var sorted_keys: Array[String] = []
var row_buttons: Dictionary = {}   # clé espèce -> Button, pour rendre le focus au retour de la fiche
var first_known_button: Button = null
var last_opened_key := ""

func _ready() -> void:
	for key in SpeciesData.SPECIES:
		sorted_keys.append(key)
	sorted_keys.sort_custom(func(a, b): return SpeciesData.SPECIES[a]["dex_number"] < SpeciesData.SPECIES[b]["dex_number"])
	_build_list()
	_update_stats()
	detail_page.visible = false
	list_page.visible = true
	hint.text = "Échap : revenir"
	if first_known_button:
		first_known_button.grab_focus()

func _update_stats() -> void:
	stats_label.text = "Vu : %d   Capturé : %d   /   %d" % [
		PlayerData.pokedex_seen.size(), PlayerData.pokedex_caught.size(), sorted_keys.size(),
	]

func _build_list() -> void:
	for key in sorted_keys:
		var sp: Dictionary = SpeciesData.SPECIES[key]
		var seen: bool = key in PlayerData.pokedex_seen
		var caught: bool = key in PlayerData.pokedex_caught
		var known: bool = seen or key not in HIDDEN_UNTIL_SEEN
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 0)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = false
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Icône posée sur TOUTES les lignes (même les "???" désactivées) :
		# sinon la colonne réservée à la flèche ne s'applique qu'aux lignes
		# connues, ce qui décale leur texte par rapport aux "???" (vu en jeu).
		btn.icon = BlankTexture
		if known:
			var suffix := " (vu)" if (seen and not caught) else ""
			btn.text = "N°%03d — %s%s" % [sp["dex_number"], sp["name"], suffix]
		else:
			btn.text = "N°%03d — ???" % sp["dex_number"]
			btn.disabled = true
			btn.modulate.a = 0.5
		if known:
			# Même principe que partout ailleurs (sac, menu pause...) : le survol
			# souris déplace le focus clavier, les flèches naviguent entre les
			# boutons focusables automatiquement (comportement natif Godot), et
			# le ScrollContainer suit le focus tout seul.
			btn.mouse_entered.connect(func(): btn.grab_focus())
			btn.focus_entered.connect(func(): btn.icon = ArrowTexture)
			btn.focus_exited.connect(func(): btn.icon = BlankTexture)
			btn.pressed.connect(_show_detail.bind(key))
			row_buttons[key] = btn
			if first_known_button == null:
				first_known_button = btn
		rows_box.add_child(btn)

func _show_detail(key: String) -> void:
	last_opened_key = key
	var sp: Dictionary = SpeciesData.SPECIES[key]
	detail_sprite.texture = load("res://assets/pokemon/%s/front.png" % key)
	detail_title.text = "N°%03d %s" % [sp["dex_number"], sp["name"]]
	detail_category.text = "Pokémon %s" % String(CATEGORIES_FR.get(key, sp["category"]))
	detail_size.text = "%.1f m   /   %.1f kg" % [sp["height_dm"] / 10.0, sp["weight_hg"] / 10.0]
	detail_description.text = sp["description"]
	stats_label.visible = false
	list_page.visible = false
	detail_page.visible = true
	hint.text = "Échap : revenir"

func _close_detail() -> void:
	detail_page.visible = false
	list_page.visible = true
	stats_label.visible = true
	hint.text = "Échap : revenir"
	# Rend le focus sur la fiche qu'on vient de quitter plutôt que de le
	# perdre complètement (sinon les flèches ne font plus rien au retour).
	if row_buttons.has(last_opened_key):
		row_buttons[last_opened_key].grab_focus()
	elif first_known_button:
		first_known_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if detail_page.visible:
		_close_detail()
	else:
		closed.emit()
		queue_free()
