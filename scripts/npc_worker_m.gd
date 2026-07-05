extends "res://scripts/npc.gd"

func get_lines() -> Array[String]:
	if PlayerData.chosen_class.is_empty():
		return ["Va d'abord voir ma collègue."]
	if not PlayerData.intro_complete:
		PlayerData.intro_complete = true
		# PLACEHOLDER : la remise du premier Pokémon n'est pas encore développée.
		return [
			"Ah, te voilà ! Un Compétiteur qui débute a besoin de son premier Pokémon.",
			"(Cette étape arrive dans une prochaine mise à jour — tu peux déjà circuler librement !)",
		]
	return ["Bonne chance, %s !" % PlayerData.player_name]
