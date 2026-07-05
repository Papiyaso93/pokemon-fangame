extends "res://scripts/npc.gd"

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const ClassChoiceScene := preload("res://scenes/ui/class_choice.tscn")

const INTRO_LINES: Array[String] = [
	"Merci pour ces informations.",
	"Maintenant que tu as 18 ans et que tu as obtenu tous tes diplômes, tu vas pouvoir choisir ta future classe.",
]

const CLASS_EXPLANATION: Array[String] = [
	"Il existe deux voies possibles ici à Kanto.",
	"Le Compétiteur vit de la compétition Pokémon. Ses revenus viennent des matchs officiels : arènes, compétitions, adversaires réputés. Son objectif : devenir Champion de la Ligue.",
	"Le Chercheur travaille sur le terrain pour le laboratoire du Professeur Chen, à la découverte de ce que personne n'a encore documenté. Il est rémunéré pour ses missions de recherche. Son objectif : percer les mystères de Kanto et explorer des zones inconnues.",
	"Alors, quelle carrière t'intéresse le plus ?",
]

const CHERCHEUR_UNAVAILABLE: Array[String] = [
	"Je suis désolé, cette classe n'est pas encore disponible. Grodolphe doit bosser dessus.",
]

const COMPETITEUR_CONFIRM: Array[String] = [
	"Super, tu es maintenant un compétiteur.",
]

# Répétées si on reparle à worker_f, ou si on essaie de sortir avant d'avoir vu worker_m.
const NEXT_STEP_REMINDER: Array[String] = [
	"Pour commencer ta carrière, il va te falloir un Pokémon.",
	"Va voir mon collègue, il t'expliquera comment procéder.",
]

func _ready() -> void:
	super()
	if PlayerData.chosen_class.is_empty():
		call_deferred("_start_auto_intro")

func get_lines() -> Array[String]:
	if PlayerData.chosen_class.is_empty():
		return []   # la séquence auto se déclenche toute seule, pas d'interaction manuelle
	if not PlayerData.intro_complete:
		return NEXT_STEP_REMINDER
	return ["Bonne chance dans ta nouvelle carrière, %s !" % PlayerData.player_name]

func _start_auto_intro() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.is_busy = true
	await _say(INTRO_LINES)
	await _explain_and_choose()
	if player:
		player.is_busy = false
		player.interact_cooldown = 0.2   # évite que la touche qui ferme le dernier dialogue relance une interaction

func _explain_and_choose() -> void:
	await _say(CLASS_EXPLANATION)
	await _show_choice()

func _show_choice() -> void:
	var choice := ClassChoiceScene.instantiate()
	get_tree().current_scene.add_child(choice)
	var result: String = await choice.choice_made
	choice.queue_free()
	match result:
		"repeat":
			await _explain_and_choose()
		"chercheur":
			await _say(CHERCHEUR_UNAVAILABLE)
			await _show_choice()
		"competiteur":
			PlayerData.chosen_class = "competiteur"
			await _say(COMPETITEUR_CONFIRM + NEXT_STEP_REMINDER)

func _say(lines: Array[String]) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()
