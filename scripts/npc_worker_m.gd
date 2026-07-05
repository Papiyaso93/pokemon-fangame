extends "res://scripts/npc.gd"

# Explique les règles du Parc Safari (parlé AVANT la visite : c'est cette
# discussion qui débloque la sortie via PlayerData.intro_complete, voir
# safari_entrance_gate.gd::gate_check()). PlayerData.starter_species n'est
# donc PAS encore rempli à ce moment-là — il ne le sera qu'au retour, via
# safari_entrance_gate.gd::_handle_return_from_safari().
const RULES_EXPLANATION: Array[String] = [
	"Bienvenue au Parc Safari ! Voici comment ça marche.",
	"Je te donne 30 Safari Balls. À l'intérieur, tu peux tenter de capturer n'importe quel Pokémon de base de Kanto que tu croises dans les hautes herbes.",
	"Une fois que tu auras fini d'explorer, ou si tu n'as plus de Safari Ball, reviens me voir ici.",
	"Tu pourras alors choisir, parmi tout ce que tu auras attrapé, lequel sera ton tout premier partenaire.",
	"Attention : si tu n'as plus de Safari Ball, tu seras automatiquement ramené ici, même en pleine exploration.",
	"Bonne chance, %s !",
]

func get_lines() -> Array[String]:
	if PlayerData.chosen_class.is_empty():
		return ["Va d'abord voir ma collègue."]
	if not PlayerData.intro_complete:
		PlayerData.intro_complete = true
		var lines := RULES_EXPLANATION.duplicate()
		lines[lines.size() - 1] = lines[lines.size() - 1] % PlayerData.player_name
		return lines
	if PlayerData.starter_species.is_empty():
		return ["Va attraper ton futur partenaire dans le Parc Safari !"]
	return ["Prends bien soin de ton %s, %s !" % [PlayerData.starter_species, PlayerData.player_name]]
