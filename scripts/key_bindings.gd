extends Node

# Autoload : raccourcis clavier pour utiliser un objet rare directement
# depuis le jeu, sans passer par le sac (voir scenes/ui/options_menu.tscn).
# 4 slots fixes (item_shortcut_1..4, définis dans project.godot avec les
# touches 1/2/3/4 par défaut) — seul l'objet assigné à chaque slot et la
# touche elle-même sont reconfigurables, pas les touches de déplacement/
# validation/annulation (décidé le 13/07/2026, hors scope pour l'instant).
#
# Fait partie de la sauvegarde (PlayerData.shortcut_slot_items/
# shortcut_keycodes, voir save_manager.gd) — PAS une préférence
# d'installation : une nouvelle partie repart sans rien assigné, chaque
# partie sauvegardée garde les siens (décidé le 13/07/2026, correction d'un
# premier essai qui persistait tout le temps via un fichier à part).

const SLOT_COUNT := 4

# Objets assignables à un raccourci : clé interne -> libellé affiché dans
# l'écran Options. "" = aucun objet assigné à ce slot. Uniquement les objets
# rares : les consommables (Répulsif...) ne se raccourcissent pas, seulement
# les objets qu'on garde et ressort souvent. Liste ouverte, à étendre à
# mesure que de nouveaux objets rares existent.
const ITEMS := {
	"": "(aucun)",
	"pokedex": "Pokédex",
	"surf": "Planche de Surf",
	"rod": "Canne à pêche",
	"bike": "Vélo",
	"map": "Carte",
}

# Touches déjà utilisées ailleurs (déplacement/validation/annulation) —
# refusées pour un raccourci objet afin d'éviter tout conflit.
const RESERVED_KEYCODES := [
	KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE,
]

const DEFAULT_KEYCODES: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]

# Lecture seule pour les appelants externes (options_menu.gd, bag.gd) : les
# Array étant passés par référence, ceci reflète directement
# PlayerData.shortcut_slot_items sans le dupliquer.
var slot_items: Array[String]:
	get:
		return PlayerData.shortcut_slot_items

func _ready() -> void:
	apply_from_player_data()

func action_name(slot: int) -> String:
	return "item_shortcut_%d" % (slot + 1)

# Libellé humain de la touche actuellement assignée à un slot (pour l'écran
# Options), ex. "1", "F", "Échap"... Utilise `keycode` (touche localisée selon
# la disposition clavier active), pas `physical_keycode` (toujours la position
# QWERTY, quelle que soit la disposition réelle — vécu : "Z" en AZERTY
# capturait/affichait "W", la lettre à la même position en QWERTY).
func key_label(slot: int) -> String:
	var events := InputMap.action_get_events(action_name(slot))
	for event in events:
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).keycode)
	return "(aucune)"

func _keycode(slot: int) -> int:
	var events := InputMap.action_get_events(action_name(slot))
	for event in events:
		if event is InputEventKey:
			return (event as InputEventKey).keycode
	return 0

# Vérifie qu'une touche candidate peut être assignée à ce slot ; retourne un
# message d'erreur (vide si c'est bon). Appelé par options_menu.gd avant de
# valider une capture de touche.
func validate_new_key(slot: int, keycode: int) -> String:
	if keycode in RESERVED_KEYCODES:
		return "Cette touche sert déjà à se déplacer, valider ou annuler."
	for i in range(SLOT_COUNT):
		if i != slot and _keycode(i) == keycode:
			return "Cette touche est déjà assignée à un autre raccourci."
	return ""

func rebind(slot: int, keycode: int) -> void:
	_apply_binding(slot, keycode)
	PlayerData.shortcut_keycodes[slot] = keycode

func _apply_binding(slot: int, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_erase_events(action_name(slot))
	InputMap.action_add_event(action_name(slot), event)

# Un objet qu'on ne possède pas encore ne doit pas apparaître dans la liste
# de choix de l'écran Options (voir options_menu.gd::_pick_item()) — "" reste
# toujours proposé pour pouvoir libérer un slot.
func is_item_available(item_key: String) -> bool:
	match item_key:
		"": return true
		"pokedex": return PlayerData.camille_zone1_done
		"surf": return PlayerData.has_surf
		"rod": return PlayerData.has_fishing_rod
		"bike": return PlayerData.has_bike
		"map": return true   # pas encore de vrai flag narratif, voir bag.gd
		_: return false

# Un objet ne peut être assigné qu'à un seul raccourci à la fois : l'assigner
# à un nouveau slot le retire de l'ancien (pas de doublon silencieux).
func assign_item(slot: int, item_key: String) -> void:
	if item_key != "":
		for i in range(SLOT_COUNT):
			if i != slot and PlayerData.shortcut_slot_items[i] == item_key:
				PlayerData.shortcut_slot_items[i] = ""
	PlayerData.shortcut_slot_items[slot] = item_key

# Réapplique l'InputMap depuis l'état de PlayerData — à appeler après un
# chargement de partie (voir save_manager.gd) ou au démarrage du jeu.
# Nettoie au passage un objet devenu invalide entre-temps (ex. un ancien
# Répulsif persisté avant que les raccourcis ne se limitent aux objets
# rares) plutôt que de garder une clé fantôme.
func apply_from_player_data() -> void:
	for i in range(SLOT_COUNT):
		if not ITEMS.has(PlayerData.shortcut_slot_items[i]):
			PlayerData.shortcut_slot_items[i] = ""
	for i in range(SLOT_COUNT):
		var code: int = PlayerData.shortcut_keycodes[i] if i < PlayerData.shortcut_keycodes.size() else 0
		if code == 0:
			code = DEFAULT_KEYCODES[i]
		_apply_binding(i, code)

# Nouvelle partie (voir title_screen.gd::_on_new_game_chosen()) : aucun objet
# assigné, touches remises à 1/2/3/4.
func reset_to_defaults() -> void:
	PlayerData.shortcut_slot_items = ["", "", "", ""]
	PlayerData.shortcut_keycodes = DEFAULT_KEYCODES.duplicate()
	apply_from_player_data()
