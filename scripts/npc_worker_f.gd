extends "res://scripts/npc.gd"

# Louise : accueil de Kanto. Reprend la conversation à l'arrivée du joueur
# (juste après le formulaire de l'écran noir, voir intro.gd), évoque les
# 2 classes sans demander de choisir tout de suite, puis renvoie vers Anselme
# pour le détail (voir npc_worker_m.gd). Elle reprend la parole en tout
# dernier, une fois que le joueur a un partenaire, pour le vrai choix de
# classe (ask_final_class_choice(), appelée par safari_entrance_gate.gd).

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const ClassChoiceScene := preload("res://scenes/ui/class_choice.tscn")

const INTRO_LINES: Array[String] = [
	"Bien, %s. C'est noté.",
	"Le voyage a dû être long.",
	"Les cours, c'est du passé pour toi maintenant. À 18 ans, il est temps de trouver sa voie.",
	"Il y en a deux, à Kanto : Compétiteur et Chercheur.",
	"Je pourrais t'en dire plus, mais franchement, je ne suis pas la mieux placée pour ça.",
	"Va voir Anselme, en face. Il va s'occuper de toi.",
]

# Réutilisé aussi par safari_entrance_gate.gd::on_gate_blocked() si le joueur
# essaie de sortir avant d'avoir parlé à Anselme.
const WAITING_FOR_ANSELME: Array[String] = [
	"Va voir Anselme, en face. Il va s'occuper de toi.",
]

const WAITING_FOR_PARTNER: Array[String] = [
	"Va d'abord attraper ton premier partenaire au Parc Safari.",
]

const FINAL_QUESTION: Array[String] = [
	"Alors, cette fois c'est décidé ?",
]

const CHERCHEUR_UNAVAILABLE: Array[String] = [
	"Je suis désolé, cette classe n'est pas encore disponible. Grodolphe doit bosser dessus.",
]

const COMPETITEUR_CONFIRM: Array[String] = [
	"Super, tu es maintenant un compétiteur.",
]

func _ready() -> void:
	super()
	if not PlayerData.orientation_given:
		call_deferred("_start_auto_intro")

func get_lines() -> Array[String]:
	if not PlayerData.orientation_given:
		return []   # la séquence auto se déclenche toute seule
	if not PlayerData.intro_complete:
		return WAITING_FOR_ANSELME
	if PlayerData.starter_species.is_empty():
		return WAITING_FOR_PARTNER
	if PlayerData.chosen_class.is_empty():
		return []   # géré par ask_final_class_choice(), pas une simple ligne
	return ["Bonne chance dans ta nouvelle carrière, %s !" % PlayerData.player_name]

func _start_auto_intro() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.is_busy = true
	var lines := INTRO_LINES.duplicate()
	lines[0] = lines[0] % PlayerData.player_name
	await _say(lines)
	PlayerData.orientation_given = true
	if player:
		player.is_busy = false
		player.interact_cooldown = 0.2

# Appelée par safari_entrance_gate.gd une fois que le joueur a son partenaire,
# juste après le choix (enchaînement direct, pas besoin de revenir parler à
# Louise manuellement).
func ask_final_class_choice() -> void:
	await _ask_and_choose()

func _ask_and_choose() -> void:
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(FINAL_QUESTION)
	await dialogue.page_typed
	dialogue.active = false

	var choice := ClassChoiceScene.instantiate()
	get_tree().current_scene.add_child(choice)
	var result: String = await choice.choice_made
	choice.queue_free()
	dialogue.queue_free()

	match result:
		"repeat":
			await _ask_and_choose()
		"chercheur":
			await _say(CHERCHEUR_UNAVAILABLE)
			await _ask_and_choose()
		"competiteur":
			PlayerData.chosen_class = "competiteur"
			await _say(COMPETITEUR_CONFIRM)

func _say(lines: Array[String]) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()
