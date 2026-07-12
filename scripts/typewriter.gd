class_name Typewriter
extends RefCounted

# Effet machine à écrire partagé entre dialogue_box.gd et encounter.gd — avant
# ce refactor, chacun avait sa propre implémentation (boucle
# `await create_timer` par caractère côté encounter.gd, accumulation dans
# _process côté dialogue_box.gd) avec un CHAR_DELAY dupliqué à tenir
# manuellement synchronisé entre les deux fichiers. Piloté par update(delta),
# à appeler depuis le _process() de l'appelant.

signal completed

const CHAR_DELAY := 0.02   # secondes entre chaque caractère

var label: Label
var text := ""
var revealed := 0
var typing := false
var _char_timer := 0.0

func _init(target_label: Label) -> void:
	label = target_label

func start(new_text: String, prefix_len: int = 0) -> void:
	text = new_text
	revealed = clampi(prefix_len, 0, text.length())
	typing = true
	_char_timer = 0.0
	label.text = text.substr(0, revealed)

# Affiche le texte en entier immédiatement (appui du joueur pendant la frappe).
func skip() -> void:
	if not typing:
		return
	revealed = text.length()
	label.text = text
	typing = false
	completed.emit()

func update(delta: float) -> void:
	if not typing:
		return
	_char_timer += delta
	while _char_timer >= CHAR_DELAY and revealed < text.length():
		_char_timer -= CHAR_DELAY
		revealed += 1
		label.text = text.substr(0, revealed)
	if revealed >= text.length():
		typing = false
		completed.emit()
