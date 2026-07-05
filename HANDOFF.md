# Handoff — Pokémon Fangame Godot 4.7

## Utilisateur
Gus (guillaumecastro9@gmail.com, GitHub **Papiyaso93**). Code avec un agent IA ; game
design avec un ami. Parle français, préfère des réponses courtes et directes.
Dépôt : **github.com/Papiyaso93/pokemon-fangame** (branche `main`). Voir `game-design.md`
pour la narration (classes, pivot Team Rocket).

---

## ▶▶▶ PROCHAINE SESSION — état exact et prochaines étapes

**Ce qui marche de bout en bout, testé** : écran noir → dialogue → création perso (genre/nom/
apparence) → spawn dans `safari_entrance` → `worker_f` (confirmation → explication classes →
choix Compétiteur/Chercheur en boucle) → verrou de sortie → Zone Safari → marche dans les
hautes herbes → rencontre Rattata (placeholder) → capture avec vraie formule FRLG → retour à
l'entrée (volontaire ou forcé si 0 balls) → choix du partenaire parmi les captures, ou Rattata
de secours si bredouille → `PlayerData.starter_species` rempli.

**Dans l'ordre logique des prochaines étapes :**
1. **`npc_worker_m.gd` est un placeholder** — il se contente d'annoncer que l'étape n'est pas
   développée et de mettre `intro_complete = true`. Il faut maintenant lui faire dire quelque
   chose de cohérent avec `PlayerData.starter_species` (déjà rempli à ce moment !) — par ex.
   confirmer/présenter le partenaire choisi, transition vers la suite du jeu.
2. **Appliquer l'apparence choisie au joueur** — jamais fait. `player.tscn` charge en dur
   `red_normal.png` ; il faut lire `PlayerData.appearance` et charger le bon spritesheet parmi
   les 4 (même format 144×32/9 frames, donc juste changer la texture source des `AtlasTexture`).
3. **Roster réel de la Zone Safari** (gros chantier de contenu, pas du code) : Gus veut les
   « bébés » Pokémon de la 1ère génération (Pichu au lieu de Pikachu, Toudoudou au lieu de
   Rondoudou, etc. — seules certaines espèces ont un bébé, sinon garder la forme de base gen 1),
   avec un taux d'apparition et un taux de capture par espèce/zone (4 sous-zones : center/east/
   north/west). Remplace le Rattata unique codé en dur dans `scripts/encounter.gd`. **Ne PAS
   improviser seul cette liste** — c'est une décision de game design à prendre avec l'ami de Gus.
4. **Fidélité de la formule de capture** : actuellement un seul jet de probabilité
   (`odds/255`) au lieu de la simulation exacte à 4 « secousses » du jeu original. Formule
   complète vérifiée dans pret `src/battle_script_commands.c` (`Cmd_handleballthrow`) — need
   `Sqrt(Sqrt(16711680/odds))` puis 4 tirages successifs. Amélioration de fidélité, pas urgent.
5. **Appât / caillou** (bait/rock) — mécanique réelle du Parc Safari absente pour l'instant
   (un seul type de lancer possible). Note amusante vérifiée dans le code : dans le jeu
   original, l'appât **diminue** la capture (mais aussi la fuite) et le caillou **l'augmente**
   (mais aussi la fuite) — contre-intuitif mais réel (`HandleAction_ThrowBait/ThrowRock`,
   pret `src/battle_main.c`).
6. **Animation d'apparition du Pokémon sauvage** (transition d'écran façon vrai jeu) — demandée
   par Gus, cosmétique, pas urgente.
7. Classe **Chercheur** indisponible ("Grodolphe doit bosser dessus") — v2 selon `game-design.md`.

**Fichiers clés Zone Safari** : `scripts/safari_state.gd` (autoload `SafariState` : `active`,
`balls`, `caught`), `scripts/encounter.gd`+`scenes/ui/encounter.tscn` (écran de capture),
`scripts/partner_choice.gd`+`scenes/ui/partner_choice.tscn` (choix final), logique de retour
dans `scripts/safari_entrance_gate.gd::_handle_return_from_safari()`, détection herbes dans
`player.gd` (`_is_grass`, `pending_encounter_check`, `ENCOUNTER_CHANCE=0.10`).

---

## ⚠️ PIÈGE GODOT — UI ajoutée dynamiquement à une map = toujours `CanvasLayer`
Bug vécu et résolu en session : `encounter.tscn` (racine `Control` nu, ajouté via
`get_tree().current_scene.add_child(...)` sous une map dont la racine est un `Node2D`)
se retrouvait avec une **taille résolue de (0,0)** — nœud présent dans l'arbre, `visible=true`,
mais rien ne s'affichait (même pas le fond semi-transparent). Cause : un `Control` avec des
ancres en % (`anchor_right/bottom=1.0`) a besoin d'un **parent `Control`/`Viewport`** pour
calculer sa taille ; sous un `Node2D` nu, ça peut échouer silencieusement.
**Fix qui marche à coup sûr** : mettre un `CanvasLayer` en racine de la scène UI (comme
`dialogue_box.tscn`, jamais bugué), avec un `Control` enfant pour les ancres/contenu.
Déjà appliqué à `encounter.tscn` et `partner_choice.tscn`. **`character_creation.tscn` et
`class_choice.tscn` utilisent encore un `Control` nu en racine** — ils fonctionnent
empiriquement (testés avec succès), mais si un bug d'affichage similaire apparaît dessus un
jour, appliquer le même correctif `CanvasLayer`.
**Méthode de diagnostic qui a marché** : onglet "Distant" du panneau Scène pendant que le jeu
tourne (bloqué) → sélectionner le nœud suspect → Inspecteur → section "Transform" → si `Size`
= (0,0), c'est ce bug.

## 📋 TODO — non urgent, à faire plus tard

### Boîte de dialogue — fidélité visuelle complète
- **Police fidèle FRLG** : le vrai asset est `graphics/fonts/latin_normal.png` (pret) — contient
  bien tous les accents français. MAIS : largeur variable par caractère (table
  `sFontNormalLatinGlyphWidths` dans pret `src/text.c`) + encodage propre à Pokémon (pas
  l'ASCII standard, table de correspondance caractère→tuile à trouver dans le même fichier).
  Construire une vraie `BitmapFont` Godot fidèle demande de décoder ces deux tables — pas un
  simple import d'image. Chercher aussi `latin_small.png` (police plus petite, autre contexte).
- **Bordure de dialogue fidèle** : `assets/ui/textbox_std.png` (déjà utilisé actuellement) vient
  de `graphics/text_window/std.png` dans pret, qui **n'est référencé par aucun `INCBIN` dans le
  code source** — probablement pas le bon asset. Le vrai fichier chargé pour les dialogues
  overworld est `graphics/text_window/menu_message.png` (`gMenuMessageWindow_Gfx`, chargé via
  `LoadBgTiles` dans pret `src/text_window.c`) — bordure ondulée bleu/blanc, la vraie identité
  visuelle Pokémon. C'est un **fragment de tuiles** (48×24px, 6×3 tuiles de 8px) à réassembler
  selon la logique de `WindowFunc_DrawDialogueFrame` (pret `src/new_menu_helpers.c` ligne ~520),
  pas une image toute faite — nécessite de comprendre l'agencement des tuiles dans ce code avant
  de reconstruire un `NinePatchRect`/atlas Godot correct.

### Fait cette session (pour référence)
- ✅ Texte progressif (effet machine à écrire) + appui touche = affichage instantané du reste.
- ✅ Flèche de continuation quand il reste du texte à afficher — vrai asset trouvé dans pret :
  `graphics/fonts/down_arrow_3.png` / `down_arrow_4.png` (animation 2 frames).
- ✅ Confirmé : FRLG n'affiche **pas** de nom de personnage dans la boîte de dialogue standard
  (aucune étiquette de nom pour les PNJ) — pas la peine de l'ajouter.

---

## ▶▶ ÉTAT DE L'INTRO — fonctionnelle de bout en bout

Séquence complète et testée : écran noir (dialogue) → création de personnage (genre/nom 7
caractères/apparence) → spawn dans `safari_entrance` → `worker_f` enchaîne automatiquement
(confirmation → explication des 2 classes → choix Compétiteur/Chercheur/Peux-tu répéter ?) →
sorties verrouillées tant que `worker_m` n'a pas été vu (placeholder) → déverrouillage complet.
`main_scene` = `scenes/intro/intro.tscn`.

Fichiers clés :
- `scripts/intro.gd`, `scenes/intro/intro.tscn` : dialogue d'ouverture + lancement création.
- `scripts/character_creation.gd` + `scenes/ui/character_creation.tscn` : genre/nom/apparence.
- `scripts/player_data.gd` (autoload `PlayerData`) : `gender`, `player_name`, `appearance`,
  `chosen_class` (""/"competiteur"), `intro_complete` (bool, débloque les sorties).
- `scripts/npc.gd` (+ `scenes/npc/npc.tscn`) : PNJ statique réutilisable, sprite réel
  (`sprite_name` export), `facing`, méthode virtuelle `get_lines()`. Portée d'interaction du
  joueur = **2 cases** dans la direction du regard (permet de parler par-dessus un comptoir).
- `scripts/npc_worker_f.gd` : logique complète de la séquence auto (voir constantes en tête
  de fichier pour le texte). `scripts/npc_worker_m.gd` : placeholder, met `intro_complete=true`.
- `scripts/safari_entrance_gate.gd` : verrou générique de sorties, attaché à la racine de
  `safari_entrance.tscn`. Le point d'extension `gate_check()`/`on_gate_blocked()` existe
  maintenant dans `player.gd` — réutilisable pour d'autres maps scriptées à l'avenir.
- **`safari_office` et `safari_entrance` sont HORS de la liste auto-régénérée**
  (`scripts/import_map.gd`) car ils contiennent des PNJ/scripts ajoutés à la main via
  `scripts/setup_safari_entrance_npcs.gd` et `scripts/setup_safari_entrance_gate.gd`.
  **⚠️ Piège vécu 2 fois cette session** : si `safari_entrance` est remis dans cette liste
  (même temporairement pour un fix) et qu'on relance `import_map.gd`, les PNJ/le verrou sont
  perdus — il faut relancer les deux scripts `setup_*` juste après. Si on modifie leurs
  positions, éditer AUSSI les coordonnées dans `setup_safari_entrance_npcs.gd` lui-même (pas
  seulement dans le `.tscn`), sinon un futur re-run écrase le fix.

### Reste à faire
Voir la section **« PROCHAINE SESSION »** tout en haut du document — liste à jour et détaillée.

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
- **Rebords (ledges)** : comportement metatile extrait dans `build_godot.py` (attr bits 0-8,
  cf. pret `src/fieldmap.c`), constantes `MB_JUMP_EAST/WEST/NORTH/SOUTH` (`0x38-0x3B`,
  `include/constants/metatile_behaviors.h`). Saut = 2 cases, sens unique, **JUMP_SPEED=120**
  (16 frames pour 2 cases = même durée qu'1 case en marche normale — vérifié dans
  `event_object_movement.c`, `MovementAction_Jump2*`). Arc visuel sinusoïdal 6px
  (`JUMP_ARC_HEIGHT`) sur `anim.position.y` pendant le saut, pas sur la position réelle.

---

## État actuel
- ✅ **Kanto classique complet en extérieur** : 12 villes + 31 routes générées et jouables
  (`generated/*.json` + `.png`, `scenes/maps/*.tscn`). Îles Sevii et prototypes exclus (hors
  scope, cf. `game-design.md`). Liste exacte dans `build_godot.py` (dict `MAPS`) et
  `import_map.gd` (const `MAPS`) — TOUJOURS mettre à jour les DEUX en parallèle.
- ✅ **Joueur ISO** : déplacement, animations, tap-to-turn, collisions, **rebords/ledges**
  (saut 2 cases à sens unique + arc visuel — voir section Joueur).
- ✅ **Kanto extérieur entièrement navigable à pied** (transitions de bord + warps ponctuels).
  Limitation connue : `change_scene` = « téléport », pas de défilement continu (TODO seamless).
- ✅ **5 grottes génériques** (Diglett, Mt Sélénite, Souterrain, Écume, Route Victoria) :
  petite pièce 9×11 réutilisée telle quelle (vraies tuiles cave FRLG extraites de Mt Moon),
  chacune avec 2 portes reliant les vrais points de passage obligatoires de Kanto (voir
  `kanto-pipeline/build_cave.py`, dict `CAVES`). **Simplification volontaire** : pas de vrai
  layout de donjon, juste entrée/sortie. Azurine (post-jeu, optionnelle) non faite.
- ✅ **Forêt de Jade + les 4 portes de Safrania** : warp **direct** route↔ville, sans bâtiment
  intermédiaire (le petit bâtiment-porte du vrai jeu est sauté, invisible pour le joueur).
- ❌ **Aucun intérieur réel** (maisons, Centres, arènes, labo, étages de grottes…) — prévu en
  tout dernier, comme convenu.

## Pipeline générique (comment ajouter des maps)
`build_godot.py` (dict `MAPS` nom-pret → nom-godot) et `import_map.gd` (const `MAPS`, même
noms godot) génèrent n'importe quelle map pret. Pour en ajouter : ajouter le nom aux DEUX
listes, relancer `python3 build_godot.py` (génère les JSON/PNG dans `generated/`), puis dans
Godot ouvrir `import_map.gd` → Fichier → Exécuter (génère/régénère les `.tscn`).

**Deux mécanismes de transition, ne pas les confondre :**
- **Connexions de bord** (`connections` en métadonnées racine, `{dir, offset, target}`) :
  pour les maps qui se touchent directement dans les données pret (`map.json` → `connections`).
  Automatique dès que la map cible existe.
- **Warps ponctuels** (`warps` en métadonnées racine, `{x, y, target, tx, ty, face?}`) :
  pour les portes/grottes/bâtiments — téléportation à une coordonnée précise, indépendante
  des bords. Système dans `player.gd` (`_warp_at`) + `scripts/transitions.gd` (autoload
  `Transitions`, champ `direct` + `direct_tile`). Défini à la main dans `WARP_OVERRIDES`
  (`build_godot.py`) pour les routes/villes, ou généré par `build_cave.py` pour les grottes.

**⚠️ Piège vécu plusieurs fois** : `connections` existant dans les données pret ne veut PAS
dire que le passage est réellement praticable — un vrai bâtiment ou une montagne peut occuper
la bordure et bloquer physiquement le passage même si la donnée dit « connecté » (ex. Victory
Road, portes de Safrania). **Toujours vérifier la collision réelle** (bits 10-11 de `map.bin`)
à l'endroit exact avant de conclure qu'un passage est ouvert. Idem pour toute coordonnée
d'atterrissage inventée (ex. « +1 case au sud de la porte ») : **vérifier sa collision** avant
de l'utiliser — plusieurs fois une case voisine tombait dans le bâtiment/mur (voir historique
de session : bugs Forêt de Jade nord + portes Safrania 5/6).

## ▶ TODO — transitions SEAMLESS (défilement continu FRLG)
Le `change_scene` actuel fait un « téléport » (recharge la scène ; pas de continuité ; gris
au-delà du bord). La vraie façon FRLG à implémenter :
- **Joueur persistant** + un **gestionnaire de monde** qui charge la map courante ET ses
  **voisines** (instanciées à leur offset en pixels ; ex. Route 1 au-dessus de Pallet).
- Pas de rechargement : marche continue, caméra qui défile ; quand le joueur traverse dans une
  voisine, elle devient « courante », on charge SES voisines et on décharge les lointaines.
  Collision OK (chaque scène garde son calque Collision). Caméra : limites = boîte englobante
  des maps chargées. → Refonte : le joueur sort des scènes de map et devient persistant.

## Générer la suite de Kanto (token-efficient)
Ajouter les maps dans `MAPS` (les deux fichiers), générer en **batch** (plusieurs d'un coup),
pas une par une. Intérieurs à la toute fin.

---

## Gotchas Godot
- Fichier modifié en externe : Godot garde en cache → **Scène → « Recharger la scène
  sauvegardée »**, ou fermer sans enregistrer + rouvrir, ou **redémarrer Godot** (le plus
  sûr pour vider le cache scripts/scènes).
- PNG modifié en externe : cliquer dans la fenêtre Godot (réimport auto au focus).
- Régénérer une map écrase `scenes/maps/<map>.tscn` (l'uid change ; `main_scene` est
  référencé par **chemin** dans `project.godot`, donc rien ne casse).
- Ne **jamais** committer `kanto-pipeline/pokefirered/` (gitignoré).
