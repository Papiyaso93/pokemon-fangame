extends Node

# Autoload : raccourcis clavier pour utiliser des objets directement depuis
# le jeu, sans passer par le sac (voir scenes/ui/options_menu.tscn). 4 slots
# fixes (item_shortcut_1..4, définis dans project.godot avec les touches
# 1/2/3/4 par défaut) — seul l'objet assigné à chaque slot et la touche
# elle-même sont reconfigurables, pas les touches de déplacement/validation/
# annulation (décidé le 13/07/2026, hors scope pour l'instant).
#
# Persisté à part de SaveManager : une touche assignée est une préférence
# d'installation, pas une donnée de partie en cours.

const SETTINGS_PATH := "user://keybindings.json"
const SLOT_COUNT := 4

# Objets assignables à un raccourci : clé interne -> libellé affiché dans
# l'écran Options. "" = aucun objet assigné à ce slot. Uniquement les objets
# rares (décidé le 13/07/2026) : les consommables (Répulsif...) ne se
# raccourcissent pas, seulement les objets qu'on garde et ressort souvent.
# Liste ouverte, à étendre à mesure que de nouveaux objets rares existent.
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

# Objet assigné à chaque raccourci (index 0-3) — aucun par défaut, c'est au
# joueur de choisir depuis l'écran Options.
var slot_items: Array[String] = ["", "", "", ""]

func _ready() -> void:
	_load()

func action_name(slot: int) -> String:
	return "item_shortcut_%d" % (slot + 1)

# Libellé humain de la touche actuellement assignée à un slot (pour l'écran
# Options), ex. "1", "F", "Échap"... "(aucune)" si jamais assignée (ne devrait
# pas arriver en pratique, chaque slot a une touche par défaut).
func key_label(slot: int) -> String:
	var events := InputMap.action_get_events(action_name(slot))
	for event in events:
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	return "(aucune)"

func _physical_keycode(slot: int) -> int:
	var events := InputMap.action_get_events(action_name(slot))
	for event in events:
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return 0

# Vérifie qu'une touche candidate peut être assignée à ce slot ; retourne un
# message d'erreur (vide si c'est bon). Appelé par options_menu.gd avant de
# valider une capture de touche.
func validate_new_key(slot: int, physical_keycode: int) -> String:
	if physical_keycode in RESERVED_KEYCODES:
		return "Cette touche sert déjà à se déplacer, valider ou annuler."
	for i in range(SLOT_COUNT):
		if i != slot and _physical_keycode(i) == physical_keycode:
			return "Cette touche est déjà assignée à un autre raccourci."
	return ""

func rebind(slot: int, physical_keycode: int) -> void:
	_apply_binding(slot, physical_keycode)
	_save()

func _apply_binding(slot: int, physical_keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_erase_events(action_name(slot))
	InputMap.action_add_event(action_name(slot), event)

# Un objet ne peut être assigné qu'à un seul raccourci à la fois : l'assigner
# à un nouveau slot le retire de l'ancien (pas de doublon silencieux).
func assign_item(slot: int, item_key: String) -> void:
	if item_key != "":
		for i in range(SLOT_COUNT):
			if i != slot and slot_items[i] == item_key:
				slot_items[i] = ""
	slot_items[slot] = item_key
	_save()

func _load() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var items: Array = parsed.get("slot_items", [])
	for i in range(mini(SLOT_COUNT, items.size())):
		var item_key := String(items[i])
		# Objet devenu invalide entre-temps (ex. Répulsif, plus assignable
		# depuis le 13/07/2026) : on libère le slot plutôt que de garder une
		# clé fantôme.
		slot_items[i] = item_key if ITEMS.has(item_key) else ""
	var codes: Array = parsed.get("physical_keycodes", [])
	for i in range(mini(SLOT_COUNT, codes.size())):
		var code := int(codes[i])
		if code != 0:
			_apply_binding(i, code)

func _save() -> void:
	var codes := []
	for i in range(SLOT_COUNT):
		codes.append(_physical_keycode(i))
	var data := {
		"slot_items": slot_items,
		"physical_keycodes": codes,
	}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
