class_name SpeedLinesFX
extends Control

# Rafale de traits obliques blancs (façon "vitesse") jouée brièvement à
# l'arrivée d'un dresseur/Pokémon sur le terrain. Composant générique, pas
# spécifique à un combat en particulier — réutilisable pour toutes les
# arrivées en jeu (dresseur zone 3, futurs combats, envoi de Pokémon...).

const LINE_COUNT := 10
const LINE_COLOR := Color(1, 1, 1, 0.85)

func _draw() -> void:
	var w := size.x
	var h := size.y
	for i in range(LINE_COUNT):
		var t := float(i) / float(LINE_COUNT - 1)
		var x: float = lerp(-w * 0.2, w * 1.2, t)
		draw_line(Vector2(x, 0.0), Vector2(x - h * 0.35, h), LINE_COLOR, 3.0)

# Flash bref (apparition rapide puis disparition) — pas une boucle, juste un
# aller-retour d'opacité sur toute la durée passée.
func flash(duration: float = 0.25) -> void:
	visible = true
	modulate.a = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, duration * 0.35)
	tw.tween_property(self, "modulate:a", 0.0, duration * 0.65)
	await tw.finished
	visible = false
