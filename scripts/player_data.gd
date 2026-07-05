extends Node

# Autoload : infos du personnage choisies à la création. Lu par player.gd
# pour appliquer le bon spritesheet, et par les dialogues pour le nom.

const NAME_MAX_LENGTH := 7   # fidèle FRLG (PLAYER_NAME_LENGTH)

# Les 4 apparences disponibles (vrais sprites overworld FRLG/RS), 2 par genre.
const APPEARANCES := {
	"male": ["red_normal", "rs_brendan"],
	"female": ["green_normal", "rs_may"],
}

var gender := "male"        # "male" / "female"
var player_name := "Red"
var appearance := "red_normal"   # nom de fichier (sans extension) dans assets/characters/
