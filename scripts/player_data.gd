extends Node

# Autoload : infos du personnage choisies à la création. Lu par player.gd
# pour appliquer le bon spritesheet, et par les dialogues pour le nom.

const NAME_MAX_LENGTH := 12   # le vrai jeu limite à 7 (contrainte GBA/encodage), mais on n'a
                               # pas cette contrainte sur PC, donc on est plus permissif

# Les 4 apparences disponibles (vrais sprites overworld FRLG/RS), 2 par genre.
const APPEARANCES := {
	"male": ["red_normal", "rs_brendan"],
	"female": ["green_normal", "rs_may"],
}

var gender := "male"        # "male" / "female"
var player_name := "Red"
var appearance := "red_normal"   # nom de fichier (sans extension) dans assets/characters/
var orientation_given := false   # true une fois que Louise a fait son discours d'accueil
var chosen_class := ""      # "" tant que non choisi ; "competiteur" (chercheur pas encore dispo).
                             # Choisi en tout dernier maintenant (après la visite du Parc Safari),
                             # pas à l'arrivée.
var intro_complete := false # true une fois qu'on a parlé à Anselme (débloque la porte nord)
var starter_species := ""   # premier partenaire choisi au Parc Safari (débloque la porte sud)

# Pokédex (test, cf. HANDOFF.md) : clés SpeciesData.SPECIES (ex. "bulbasaur"),
# pas les noms français affichés. "Capturé" implique "Vu" mais les deux
# tableaux sont tenus à jour séparément (fidèle au vrai jeu, 2 drapeaux
# distincts par espèce).
var pokedex_seen: Array[String] = []
var pokedex_caught: Array[String] = []

# Acte 1 (voir acte1-parc-safari.md) : progression du parcours guidé dans le
# Parc Safari. Chaque case à true une fois qu'on a parlé au PNJ concerné dans
# la maison de repos correspondante — sert aussi à débloquer l'accès à la
# zone suivante (voir scripts/safari_zone_gate.gd).
var camille_zone1_done := false
var camille_zone2_done := false
var yohan_zone3_done := false
var yohan_zone4_done := false

# Objets clés donnés pendant les zones du Parc Safari (test, voir
# acte1-parc-safari.md — récompenses définitives à retravailler plus tard).
var has_fishing_rod := false   # Anselme, PARK_HANDOFF (beat 3b)
var has_surf := false          # Yohan, zone 4

# "surf" ou "rod" : lequel utiliser en faisant face à l'eau quand on a les
# deux objets à la fois (voir scripts/player.gd::_try_interact). Choisi
# depuis le sac (scripts/bag.gd, boutons Surf/Canne) — sans ça, un seul des
# deux serait jamais utilisable une fois qu'on possède l'autre.
var preferred_water_tool := "surf"

# true une fois qu'Anselme a remis la canne à pêche + les Safari Balls et
# débloqué les rencontres sauvages dans le parc (PARK_HANDOFF, beat 3b —
# voir scripts/npc_anselme_park.gd). Source de vérité persistée pour
# SafariState.hunting_unlocked (lui n'est pas sauvegardé, voir save_manager.gd).
var park_handoff_done := false
