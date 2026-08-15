extends "res://scripts/npc.gd"

# Julien : second assistant du Pr Chen, maison de repos de la Zone 2
# (safari_rest_house_east). Distinct de Camille (zone 1, npc_camille_zone1.gd) :
# Julien travaille plutôt sur les ruines/fossiles que sur les Pokémon vivants
# (voir acte1-parc-safari.md). Utilise custom_talk() comme camille_zone1.gd :
# don du vélo avec pause réservée au son d'objet obtenu, puis quête du puzzle
# de fragments (scripts/fragments_puzzle.gd), proposée via un choix Oui/Non
# à chaque conversation suivante tant qu'elle n'est pas résolue.

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const LocationBannerScene := preload("res://scenes/ui/location_banner.tscn")
const YesNoChoiceScene := preload("res://scenes/ui/yes_no_choice.tscn")
const FragmentsPuzzleScene := preload("res://scenes/ui/fragments_puzzle.tscn")

const AFTER_SOLVED: Array[String] = [
	"Merci encore pour ce coup de main sur les fragments. Grâce à toi, on sait enfin à quoi s'attendre.",
]

const REVEAL_LINES: Array[String] = [
	"Bravo, enfin complet ! Un genre de grand reptile ailé, si on en croit la silhouette.",
	"On dirait bien qu'on peut l'appeler Ptéra.",
	"C'est la première fois qu'on a une trace aussi nette de cette espèce. Bien joué.",
]

# Fin de la 1re conversation : présente le choix (faire le puzzle maintenant,
# ou continuer directement) plutôt que de pousser vers la zone 3 sans
# alternative, puisque les 2 options sont réellement ouvertes à ce stade.
const INTRO_NEXT_STEPS_LINES: Array[String] = [
	"À toi de voir : tu peux tenter les fragments tout de suite, ou continuer directement vers la zone 3.",
	"Tu y trouveras Yohan, un Topdresseur, qui pourra t'en apprendre plus sur l'autre facette, celle du Compétiteur.",
]

# Fin de la conversation qui suit la résolution du puzzle : le rappel du menu
# Quêtes est toujours affiché, mais la relance vers Yohan ne l'est que si le
# joueur ne lui a pas encore parlé (voir _solved_followup_lines()) — inutile
# de la répéter une fois la zone 3 déjà visitée.
const SOLVED_QUEST_LOG_LINE := "Au fait : tu peux suivre tes quêtes en cours, et voir celles déjà terminées, à tout moment depuis le menu pause."
const SOLVED_EXPLORE_LINE := "Continue d'explorer le parc, la suite t'attend."

# Gardé pour compatibilité avec la base npc.gd — plus utilisé comme chemin
# principal, voir custom_talk() ci-dessous (point d'extension de player.gd).
func get_lines() -> Array[String]:
	return AFTER_SOLVED

func custom_talk(player: Node, _player_tile: Vector2i) -> void:
	if not PlayerData.julien_zone2_intro_done:
		await _intro_and_bike(player)
		return

	if PlayerData.julien_fragments_solved:
		await _say(player, AFTER_SOLVED)
		return

	await _offer_puzzle(player)

func _intro_and_bike(player: Node) -> void:
	await _say(player, [
		"Ah, te voilà, Camille m'a prévenu.",
		"Moi c'est Julien. Je travaille avec lui pour le compte du Professeur Chen, mais plutôt du côté des vieilles pierres que des Pokémon vivants.",
	])

	# Même boîte du début à la fin (voir dialogue_box.gd::say()) : la flèche
	# reste masquée et les entrées ignorées pendant 0.6s après la 1re ligne
	# (index 0), le temps réservé au son d'objet obtenu une fois les sons
	# convertis — pas de fermeture/réouverture de boîte. Même pattern que le
	# don du Pokédex, voir npc_camille_zone1.gd.
	await _say_with_pause(player, [
		"Tiens, avant qu'on parle de tout ça, prends ça : un vélo.",
		"En plus d'être un moyen de transport écologique, ça te sera bien utile : la région est plus grande qu'elle en a l'air, et tout faire à pied prendrait un temps fou.",
	], 0, 0.6)
	PlayerData.has_bike = true

	await _say(player, [
		"Le travail de Chercheur, ça peut prendre plein de formes : observer des Pokémon sur le terrain, comme Camille, ou creuser des pistes plus anciennes, ruines, fossiles, vieux documents. Tout ce qui demande de la patience pour comprendre ce qu'on a sous les yeux.",
		"Certaines missions sont vraiment complexes, mais passionnantes, tu verras.",
	])

	await _say(player, [
		"Justement, j'ai quelque chose sous la main. Rien de bien compliqué, mais ça te donnera un aperçu.",
		"Je n'ai pas le temps de m'en occuper moi-même, je suis en plein sur autre chose. Si ça t'intéresse, reviens me voir.",
	])

	PlayerData.julien_zone2_intro_done = true

	# Bandeau non bloquant (comme les bandeaux de nom de carte, voir
	# player.gd::_show_location_banner()) : on n'attend pas qu'il se referme
	# pour enchaîner sur la suite de la conversation (ici, la conversation
	# s'arrête simplement après, voir camille_zone1.gd pour le même principe).
	var banner := LocationBannerScene.instantiate()
	player.get_tree().current_scene.add_child(banner)
	banner.show_name("Nouvelle quête : Les fragments des ruines")

	# La zone 3 est déjà accessible dès cette 1re conversation (voir
	# safari_zone_gate.gd, condition julien_zone2_intro_done) : sans ça, le
	# joueur pourrait s'y rendre avant même que Julien en ait parlé.
	await _say(player, INTRO_NEXT_STEPS_LINES)

func _offer_puzzle(player: Node) -> void:
	# La boîte de dialogue doit rester affichée pendant que le choix Oui/Non
	# apparaît par-dessus (les 2 en même temps) — même pattern que
	# player.gd::_start_surfing() : on attend juste page_typed (pas finished),
	# on fige la boîte (active = false) sans la libérer, puis on ne la libère
	# qu'une fois le choix récupéré.
	var dialogue := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(dialogue)
	var ask_lines: Array[String] = ["Alors, ça te dit de t'y mettre maintenant ?"]
	dialogue.say(ask_lines)
	await dialogue.page_typed
	dialogue.active = false

	var choice := YesNoChoiceScene.instantiate()
	player.get_tree().current_scene.add_child(choice)
	var confirmed: bool = await choice.chosen
	choice.queue_free()
	dialogue.queue_free()

	if not confirmed:
		await _say(player, ["Pas de souci, reviens quand tu veux."])
		return

	# fragments_puzzle.gd se ferme lui-même (queue_free) dans tous les cas :
	# en cas de sortie anticipée (Échap) comme en cas de réussite (après son
	# propre fondu de sortie, voir fragments_puzzle.gd::_play_success_sequence()).
	var puzzle := FragmentsPuzzleScene.instantiate()
	player.get_tree().current_scene.add_child(puzzle)
	var solved: bool = await puzzle.finished
	if not solved:
		return

	# L'écran est encore noir (fondu de sortie déjà joué côté puzzle) : on
	# refond avant d'enchaîner sur la révélation, pour un retour fluide à la
	# conversation sans repasser par le joueur.
	await ScreenFade.fade_in()
	await _say(player, REVEAL_LINES)
	await _say(player, _solved_followup_lines())

func _solved_followup_lines() -> Array[String]:
	var lines: Array[String] = [SOLVED_QUEST_LOG_LINE]
	if not PlayerData.yohan_zone3_done:
		lines.append(SOLVED_EXPLORE_LINE)
	return lines

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
