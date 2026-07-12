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
