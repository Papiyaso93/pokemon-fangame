extends "res://scripts/npc.gd"

# Camille : guide Chercheur, maison de repos de la Zone 1 (safari_rest_house_center).
# Dialogues d'ouverture validés le 12/07/2026 (voir acte1-parc-safari.md).
# Le vrai enchaînement (Pokédex remis en jeu, traque du Minidraco chromatique,
# capture) n'est pas encore implémenté — juste les répliques pour l'instant.

const LINES: Array[String] = [
	"Ah, te voilà. Anselme m'a prévenu.",
	"Chercheur, c'est un métier de patience et d'observation. Tu vas voir, c'est très différent de foncer dans le tas.",
	"Tiens, prends ça : un Pokédex. Il recense déjà toutes les espèces de Kanto, ou presque. Tu le trouveras dans les objets importants de ton sac, et bientôt directement avec la touche 1.",
	"D'ailleurs, ça tombe bien : on vient de recevoir un Pokémon un peu particulier, et il s'est échappé dans cette zone avant qu'on ait pu bien l'observer.",
	"Tu veux bien aller y jeter un œil ? Cherche du côté des hautes herbes, il ne doit pas être bien loin.",
]

const AFTER: Array[String] = [
	"Vas-y, jette un œil du côté des hautes herbes.",
]

func get_lines() -> Array[String]:
	if not PlayerData.camille_zone1_done:
		PlayerData.camille_zone1_done = true
		return LINES
	return AFTER
