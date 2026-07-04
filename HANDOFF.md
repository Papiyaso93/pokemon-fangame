# Handoff — Pokémon Fangame Godot 4.7

## Utilisateur
Gus (guillaumecastro9@gmail.com, GitHub **Papiyaso93**). Code avec un agent IA ; game
design avec un ami. Parle français, préfère des réponses courtes et directes.
Dépôt : **github.com/Papiyaso93/pokemon-fangame** (branche `main`). Voir `game-design.md`
pour la narration (classes, pivot Team Rocket).

---

## ⚡ Architecture : pipeline pret → Godot (LE point clé)

On ne construit **plus** les maps à la main. Un convertisseur lit les données de la
décompilation FireRed (**pret/pokefirered**) et génère les scènes Godot automatiquement,
**pixel-perfect** : terrain, bâtiments, collisions, connexions. Une map = une commande.
(Décision prise après avoir constaté que le hand-placing de ~60 maps + intérieurs était
intenable, et que les données pret contiennent déjà layout + collision + calques + liens.)

### Fichiers du pipeline — `kanto-pipeline/`
- `pokefirered/` : clone de la décompilation. **Gitignoré (72 Mo)** — à re-cloner :
  `git clone --depth 1 https://github.com/pret/pokefirered` dans `kanto-pipeline/`.
- `render_map.py` : moteur de rendu metatile → image (validé ; réutilisé par les autres).
- `build_godot.py` : pour une map, génère 2 atlas (`_below.png`/`_above.png`) + un JSON
  (grille, collision, connexions) dans `generated/`. **⚠️ Codé en dur pour `pallet_town`
  dans `__main__` — à PARAMÉTRER par nom de map (+ mapping du secondary tileset).**
- `build_atlas.py` : script de validation (rendu des couches séparées).

### Côté Godot
- `scripts/import_map.gd` : EditorScript (Fichier → Exécuter) qui lit `generated/<map>.json`
  + atlas et **assemble** `scenes/maps/<map>.tscn`. **⚠️ Codé en dur `NAME="pallet_town"`
  et spawn tile (11,13) — à PARAMÉTRER.**
- Structure de scène générée :
  `Node2D > Below (TileMapLayer) > Player > Above (TileMapLayer) > Collision (TileMapLayer)`.
  Player entre Below et Above pour la perspective. `Collision` invisible (physics layer,
  1 tuile rouge translucide placée sur les cases solides) ; réafficher son œil pour debug.

### Format FRLG (constantes dans pret `include/fieldmap.h`, `src/fieldmap.c`)
- `map.bin` : 1 bloc = uint16 LE = metatile_id (bits 0-9) | collision (bits 10-11) | élévation (12-15).
- `metatiles.bin` : 1 metatile = 8 tuiles × uint16 (4 bas + 4 haut) ; tuile = tile_id (0-9) | flipX(10) | flipY(11) | palette(12-15).
- `metatile_attributes.bin` : uint32/metatile ; **layer type = bits 29-30** (0=NORMAL, 1=COVERED, 2=SPLIT).
  NORMAL/SPLIT → moitié haute AU-DESSUS du joueur ; COVERED → tout en dessous.
- NUM_METATILES_PRIMARY=640, NUM_TILES_PRIMARY=640, NUM_PALS_PRIMARY=7.
  tuile < 640 → primaire, sinon secondaire (id-640). Palettes 0-6 primaire, 7+ secondaire. Index 0 = transparent.
- Dimensions + tilesets par map : `data/layouts/layouts.json`. Connexions / warps / NPCs : `data/maps/<Map>/map.json`.

---

## Joueur (ISO FRLG)
- Sprite : `assets/characters/red_normal.png` (extrait de pret
  `graphics/object_events/pics/people/red_normal.png`, fond rendu transparent).
  9 frames 16×32 : **0=bas, 1=haut, 2=gauche (debout)** ; 3-4 = pas bas ; 5-6 = pas haut ;
  7-8 = pas gauche ; **droite = gauche `flip_h`**.
- `scenes/player/player.tscn` : AnimatedSprite2D (anims `face_south/north/west`,
  `walk_south`=[3,0,4,0], `walk_north`=[5,1,6,1], `walk_west`=[7,2,8,2] à 7.5 fps),
  CollisionShape2D (14×14 à (8,8)), Camera2D (zoom 3, position (8,16)).
- `scripts/player.gd` : déplacement case par case, **SPEED=60** (1 tuile / 16 frames),
  **tap-to-turn** (TURN_TIME=0.1 ; pression brève = pivot sur place sans avancer),
  collision via `test_move`, caméra bornée aux limites de la map (posées par `import_map.gd`).
  Logique fidèle à pret `field_player_avatar.c` (`CheckMovementInputNotOnBike`).

---

## État actuel
- ✅ **Bourg Palette** généré et jouable (`scenes/maps/pallet_town.tscn` = `main_scene`).
- ✅ **Joueur ISO** : déplacement, animations, tap-to-turn, bloqué par les collisions.
- ❌ Aucune autre map. **Aucun intérieur** (plan validé : TOUS les extérieurs d'abord —
  routes, villes, grottes — intérieurs à la toute fin).
- ❌ **Aucune transition** entre maps.

---

## ▶ Prochaine étape : Route 1 + transitions
Données Route 1 déjà relevées : `LAYOUT_ROUTE1`, **24 × 40**, tilesets `general` + `pallet_town`.
Connexions : **up → Viridian City (offset -12)**, **down → Pallet Town (offset 0)**.

1. **Paramétrer** `build_godot.py` (argument nom de map + mapping du secondary tileset) et
   `import_map.gd` (NAME + spawn) pour générer n'importe quelle map, pas seulement Bourg Palette.
2. **Générer Route 1** → `scenes/maps/route1.tscn`.
3. **Système de transitions** : détecter quand le joueur franchit un bord de map ayant une
   connexion → charger la map connectée + repositionner le joueur au bord opposé (en tenant
   compte de l'`offset`). Stocker les connexions dans la scène générée (ex. métadonnées sur
   le nœud racine) + un `MapManager` (autoload) pour le swap de scène et la caméra.
   Objectif : marcher vers le nord depuis Bourg Palette → arriver naturellement sur Route 1,
   et inversement. C'est le point que Gus veut voir marcher de façon fluide.

Ensuite : généraliser à tout Kanto (boucle sur les layouts), puis les intérieurs.

---

## Gotchas Godot
- Fichier modifié en externe : Godot garde en cache → **Scène → « Recharger la scène
  sauvegardée »**, ou fermer sans enregistrer + rouvrir, ou **redémarrer Godot** (le plus
  sûr pour vider le cache scripts/scènes).
- PNG modifié en externe : cliquer dans la fenêtre Godot (réimport auto au focus).
- Régénérer une map écrase `scenes/maps/<map>.tscn` (l'uid change ; `main_scene` est
  référencé par **chemin** dans `project.godot`, donc rien ne casse).
- Ne **jamais** committer `kanto-pipeline/pokefirered/` (gitignoré).
