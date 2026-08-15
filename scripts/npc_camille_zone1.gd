extends "res://scripts/npc.gd"

# Camille : guide Chercheur, maison de repos de la Zone 1 (safari_rest_house_center).
# Dialogues révisés le 15/07/2026 (voir la conversation de conception associée
# à acte1-parc-safari.md) : remise du Pokédex puis lancement de la quête du
# Minidraco (scripts/minidraco_quest.gd). Utilise custom_talk() (voir
# player.gd::_talk_to()) plutôt qu'un simple get_lines() : il faut une vraie
# pause après la remise du Pokédex (réservée au son d'objet obtenu, une fois
# les sons convertis) et un bandeau "nouvelle quête" au milieu de la
# conversation, ce qu'un enchaînement de lignes classique ne permet pas.

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const LocationBannerScene := preload("res://scenes/ui/location_banner.tscn")

const AFTER: Array[String] = [
	"Prends ton temps, Minidraco ne doit pas être bien loin.",
]

# Gardé pour compatibilité avec la base npc.gd — plus utilisé comme chemin
# principal, voir custom_talk() ci-dessous (point d'extension de player.gd).
func get_lines() -> Array[String]:
	return AFTER

func custom_talk(player: Node, _player_tile: Vector2i) -> void:
	if PlayerData.camille_zone1_done:
		await _say(player, AFTER)
		return

	await _say(player, ["Ah, te voilà. Anselme m'a prévenu de ton arrivée."])

	await _say(player, [
		"Le travail de Chercheur, c'est passer du temps sur le terrain : observer les Pokémon, noter leur comportement, essayer de comprendre comment ils vivent.",
		"Et de temps en temps, on tombe sur une espèce qu'on connaît encore très mal, parfois même sur quelque chose d'inédit.",
	])

	# Même boîte de dialogue du début à la fin (voir dialogue_box.gd::say()) :
	# la flèche reste masquée et les entrées ignorées pendant 0.6s après la
	# 1re ligne (index 0), le temps réservé au son d'objet obtenu une fois
	# les sons convertis — pas de fermeture/réouverture de boîte.
	await _say_with_pause(player, [
		"Tiens, voilà pour toi : un Pokédex.",
		"Aujourd'hui, on connaît déjà presque toutes les espèces de Kanto. Mais certaines restent mal documentées, faute d'avoir été assez observées, et d'autres sont encore complètement inconnues.",
		"Compléter ces fiches, les vérifier, les partager avec les autres dresseurs, ça aussi, ça fait partie du travail de Chercheur.",
	], 0, 0.6)

	await _say(player, ["Je vais te donner ta première quête."])

	await _say(player, [
		"On a récupéré un Minidraco récemment, et il s'est échappé quelque part dans le parc avant qu'on ait pu bien l'étudier.",
		"J'aurais bien besoin d'un coup de main pour le retrouver.",
	])

	PlayerData.camille_zone1_done = true

	# Bandeau non bloquant (comme les bandeaux de nom de carte, voir
	# player.gd::_show_location_banner()) : on n'attend pas qu'il se
	# referme pour enchaîner sur la suite de la conversation.
	var banner := LocationBannerScene.instantiate()
	player.get_tree().current_scene.add_child(banner)
	banner.show_name("Nouvelle quête : Le Pokémon échappé")

	await _say(player, ["Tu peux suivre tes quêtes en cours à tout moment depuis le menu pause."])

	await _say(player, [
		"Bon, je te laisse chercher. Si jamais tu as du mal à le retrouver, regarde donc sa fiche dans le Pokédex : ça pourra te donner une piste.",
		"Continue d'avancer dans le parc. Julien, un autre assistant du Pr Chen, t'attend du côté de la zone 2.",
	])

func _say(player: Node, lines: Array[String]) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()

func _say_with_pause(player: Node, lines: Array[String], pause_after: int, pause_for: float) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines, pause_after, pause_for)
	await dialogue.finished
	dialogue.queue_free()
