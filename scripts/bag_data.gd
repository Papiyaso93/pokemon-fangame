class_name BagData
extends RefCounted

# 5 poches pleinement cyclables (décision de Gus, 09/07/2026) : contrairement
# au vrai jeu où Trousse à CT et Sacoche à Baies sont des sous-écrans ouverts
# via un objet clé (cf. HANDOFF.md), on les traite ici comme 2 onglets de
# plus, pas de sous-menu séparé — plus simple, pas de problème identifié.

const POCKETS := [
	{"key": "items", "label": "Objets"},
	{"key": "key_items", "label": "Objets Rares"},
	{"key": "poke_balls", "label": "Poké Balls"},
	{"key": "tms_hms", "label": "CT & CS"},
	{"key": "berries", "label": "Baies"},
]
