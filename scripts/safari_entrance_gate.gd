extends Node2D

# Verrouille les sorties de safari_entrance : porte nord (vers le Parc
# Safari) bloquée tant que le joueur n'a pas parlé à Anselme ; porte sud
# (vers l'extérieur) bloquée tant qu'en plus il n'a pas de partenaire. Voir
# player.gd (point d'extension gate_check/on_gate_blocked) et
# npc_worker_f.gd/npc_worker_m.gd.

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const PartnerChoiceScene := preload("res://scenes/ui/partner_choice.tscn")
const ExclamationTexture := preload("res://assets/ui/exclamation.png")
const OPPOSITE := {"south": "north", "north": "south", "east": "west", "west": "east"}

func _ready() -> void:
	if SafariState.active:
		if SafariState.balls <= 0:
			call_deferred("_handle_return_from_safari")
		else:
			call_deferred("_ask_if_finished")

# Retour volontaire (il reste des Safari Balls) : Anselme demande si la
# session est terminée avant d'enchaîner sur le choix du partenaire.
func _ask_if_finished() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.is_busy = true
	var anselme := get_node_or_null("worker_m")
	var finished_session := true
	if anselme:
		finished_session = await anselme.ask_session_finished()
	if finished_session:
		await _handle_return_from_safari()
	else:
		await _turn_and_return_to_park(player)

# Le joueur se retourne et repart directement dans le Parc Safari (sa session
# ne change pas : mêmes Safari Balls restantes, mêmes captures en cours).
func _turn_and_return_to_park(player: Node) -> void:
	if player:
		player.facing = "north"
		player._play("face")
	await get_tree().create_timer(0.4).timeout
	await ScreenFade.fade_out()
	Transitions.pending = true
	Transitions.direct = true
	Transitions.direct_tile = Vector2i(26, 30)
	Transitions.facing = "north"
	get_tree().change_scene_to_file("res://scenes/maps/safari_zone_center.tscn")

# Choix du partenaire (retour volontaire "Oui", ou retour forcé faute de
# Safari Ball) puis, une fois le partenaire choisi, enchaîne directement sur
# le vrai choix de classe chez Louise.
func _handle_return_from_safari() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.is_busy = true

	if SafariState.caught.is_empty():
		var dialogue := DialogueBoxScene.instantiate()
		get_tree().current_scene.add_child(dialogue)
		var lines: Array[String] = [
			"Tu n'as attrapé aucun Pokémon cette fois-ci...",
			"Tiens, prends ce Rattata pour ne pas repartir bredouille !",
		]
		dialogue.say(lines)
		await dialogue.finished
		dialogue.queue_free()
		PlayerData.starter_species = "Rattata"
	else:
		# La question reste affichée dans sa boîte de dialogue (juste tapée puis
		# désactivée, pas fermée) pendant que la fenêtre de choix (les options
		# seules) s'affiche à côté, même principe que npc_worker_f.gd.
		var dialogue := DialogueBoxScene.instantiate()
		get_tree().current_scene.add_child(dialogue)
		var question: Array[String] = ["Lequel choisis-tu comme partenaire ?"]
		dialogue.say(question)
		await dialogue.page_typed
		dialogue.active = false

		var choice := PartnerChoiceScene.instantiate()
		get_tree().current_scene.add_child(choice)
		choice.setup(SafariState.caught)
		var species: String = await choice.chosen
		choice.queue_free()
		dialogue.queue_free()
		PlayerData.starter_species = species

	SafariState.leave()

	if not PlayerData.starter_species.is_empty() and PlayerData.chosen_class.is_empty():
		var louise := get_node_or_null("worker_f")
		if louise:
			await louise.ask_final_class_choice()

	if player:
		player.is_busy = false

func gate_check(warp: Dictionary) -> bool:
	var target := String(warp.get("target", ""))
	if target == "safari_zone_center":
		return PlayerData.intro_complete
	return PlayerData.intro_complete and not PlayerData.starter_species.is_empty()

func on_gate_blocked(warp: Dictionary, player: Node) -> void:
	player.is_busy = true
	player.facing = OPPOSITE.get(player.facing, player.facing)
	player._play("face")
	_show_exclamation(player)

	var lines: Array[String]
	if not PlayerData.intro_complete:
		var louise := get_node_or_null("worker_f")
		lines = louise.get_lines() if louise else ["Va d'abord voir Anselme."]
	else:
		lines = ["Rejoins Camille dans la maison de la zone 1 du parc."]

	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()
	player.is_busy = false

# Petit point d'exclamation qui rebondit brièvement au-dessus du joueur
# (demandé par Gus), pour bien montrer que quelque chose l'interpelle avant
# même que le dialogue ne s'affiche.
func _show_exclamation(player: Node) -> void:
	var icon := Sprite2D.new()
	icon.texture = ExclamationTexture
	icon.scale = Vector2(1.3, 1.3)
	# Le sprite du joueur est décalé de +8 en x (voir player.tscn, AnimatedSprite2D
	# position=(8,0)) pour se centrer sur la tuile depuis l'origine en haut à
	# gauche — l'icône doit suivre le même décalage pour être vraiment centrée.
	icon.position = Vector2(8, -28)
	player.add_child(icon)
	var tw := create_tween()
	tw.tween_property(icon, "position:y", icon.position.y - 4, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "position:y", icon.position.y, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.6).timeout
	icon.queue_free()
