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
1. ✅ **FAIT** — `npc_worker_m.gd` développé. Rappel important : cette 1ère discussion a lieu
   **avant** la visite (c'est elle qui met `intro_complete = true` et débloque la sortie vers
   la Zone Safari, voir `gate_check()`), donc `PlayerData.starter_species` est encore vide à ce
   moment — le texte explique les règles (30 Safari Balls, capture libre des Pokémon de base de
   Kanto, retour pour choisir le partenaire, retour auto si 0 ball), pas un choix déjà fait.
   Une 2e réplique (starter_species rempli, après le retour) confirme le partenaire choisi.
2. ✅ **FAIT** — `player.gd::_apply_appearance()` (appelée dans `_ready()`) lit
   `PlayerData.appearance` et remplace la texture `atlas` de chaque `AtlasTexture` du
   `SpriteFrames` par le bon spritesheet parmi les 4 (même layout 144×32/9 frames que
   `red_normal.png`, donc pas besoin de reconstruire les régions). **À tester en jeu** :
   choisir chacune des 4 apparences à la création de perso et vérifier le sprite en overworld.
3. **Roster réel de la Zone Safari** (gros chantier de contenu, pas du code) : Gus veut les
   « bébés » Pokémon de la 1ère génération (Pichu au lieu de Pikachu, Toudoudou au lieu de
   Rondoudou, etc. — seules certaines espèces ont un bébé, sinon garder la forme de base gen 1),
   avec un taux d'apparition et un taux de capture par espèce/zone (4 sous-zones : center/east/
   north/west). Remplace le Rattata unique codé en dur dans `scripts/encounter.gd`. **Ne PAS
   improviser seul cette liste** — c'est une décision de game design à prendre avec l'ami de Gus.
   Seul point tranché pour l'instant : **niveau fixe 5** pour tous les Pokémon du Parc Safari
   (`SPECIES_LEVEL` dans `encounter.gd`), en attendant le vrai roster.
4. ✅ **FAIT** — Écran de capture entièrement refait pour coller au vrai jeu (voir détails dans
   la section dédiée ci-dessous) : fond pixel-perfect, boîte de stats (nom/sexe/niveau/PV),
   formule de capture à 4 secousses fidèle, appât/pierre, animation d'entrée.
5. ✅ **FAIT** — Menus de choix (`class_choice.tscn`, `partner_choice.tscn`) refaits au vrai
   style Pokémon (voir section dédiée ci-dessous) : fenêtre blanche à bordure bleu-gris
   (`assets/ui/std_window.png`, reconstruit depuis pret `graphics/text_window/std.png`), flèche
   `▶` (`assets/ui/choice_arrow.png`) qui apparaît devant l'option survolée au lieu de gros
   boutons sombres. Gus a validé le style sur aperçu avant implémentation (mockup montré avec
   l'outil visualize) — **si un autre menu de choix doit être créé plus tard, réutiliser ce
   même style** (`std_window.png` + `choice_arrow.png` + icône Button qui apparaît/disparaît au
   survol), ne pas repartir sur les boutons `ui_theme.tres` sombres d'origine.
6. Classe **Chercheur** indisponible ("Grodolphe doit bosser dessus") — v2 selon `game-design.md`.

### ✅ Menus de choix — style Pokémon réel (`class_choice.tscn`, `partner_choice.tscn`)
- **Fenêtre** : `assets/ui/std_window.png`, reconstruite depuis `graphics/text_window/std.png`
  (pret) — c'est un **vrai NinePatch tout fait** (grille 3×3 de tuiles 8px, contrairement à
  `menu_message.png` qui nécessitait un réassemblage) : couleur clé de transparence
  `(115,205,164)`, bordure bleu-gris `(98,115,123)`, anneau clair `(205,213,213)`, intérieur
  blanc. Utilisé via `PanelContainer` + `StyleBoxTexture` (**pas** `NinePatchRect` directement —
  `NinePatchRect` ne s'agrandit pas automatiquement autour de ses enfants, contrairement à
  `PanelContainer`/`StyleBoxTexture` qui est un vrai `Container` ; piège vécu cette session, les
  boutons débordaient hors de la fenêtre).
- **Flèche de sélection** : `assets/ui/choice_arrow.png` (petit triangle généré, pas un asset
  pret) assigné/retiré de `Button.icon` sur `mouse_entered`/`mouse_exited` (connecté en code dans
  `class_choice.gd`/`partner_choice.gd`), plutôt qu'un changement de couleur de fond — fidèle à
  la sélection par curseur du vrai jeu.
- **Police** : système par défaut de Godot (pas `dialogue_latin.fnt`) — voir piège police
  bitmap ci-dessus, même bug rencontré ici.
- **✅ Corrections post-retour Gus (taille + question qui reste affichée)** :
  - **Taille** : le 1er jet était bien trop gros (police 22, `PanelContainer` seul sous un
    `Control` racine sans `Container` parent → ne se dimensionne pas à son contenu, débordait
    hors de la fenêtre visible). Réduit la police à 18-20 et surtout **positionné/dimensionné en
    code** (`class_choice.gd::_place_window()`, appelé après un `await get_tree().process_frame`
    pour laisser le layout se calculer) : `window.size = window.get_combined_minimum_size()`
    puis positionné en haut à droite de la boîte de dialogue (marges 24px droite / 172px bas,
    calées sur les offsets de `dialogue_box.tscn`). `partner_choice.tscn` gardait déjà un
    `CenterContainer` (qui dimensionne correctement son enfant), donc juste la police à réduire.
  - **Question qui reste affichée pendant le choix** : `dialogue_box.gd` a un nouveau signal
    `page_typed` (émis quand une page finit de s'afficher, y compris si le joueur saute l'effet
    machine à écrire). `npc_worker_f.gd::_ask_and_choose()` affiche la question dans sa propre
    boîte de dialogue, attend `page_typed`, puis **désactive juste ses entrées**
    (`dialogue.active = false`, sans la fermer/`queue_free`) pendant que le menu de choix
    s'affiche à côté — la boîte reste visible avec le texte tapé, fidèle au vrai jeu. Elle n'est
    libérée qu'une fois un choix fait. **Pattern réutilisable** pour toute future boîte de choix
    accompagnée d'une question (chercher `page_typed`/`active = false` si besoin de refaire ça
    ailleurs).
- **✅ 2ème vague de retours Gus (bordure, largeur stable, alignement, partner_choice)** :
  - **Bordure** : remplace `assets/ui/std_window.png` par `assets/ui/dialogue_frame.png` (le
    cadre ondulé bleu/blanc de `dialogue_box.tscn`) pour les fenêtres de choix aussi — Gus voulait
    la cohérence visuelle avec la boîte de dialogue. `axis_stretch_horizontal=1` (répète la vague
    du haut/bas sans la déformer) MAIS **`axis_stretch_vertical=0` (étirer, pas répéter)** — en
    mode répétition (TILE) verticalement, une fenêtre plus haute que la hauteur native de l'asset
    (comme `partner_choice` avec plusieurs Pokémon) affichait un pincement/sablier disgracieux au
    milieu (le motif des bords latéraux ne boucle pas proprement). L'étirement lisse évite ce
    problème quelle que soit la hauteur de la fenêtre.
  - **Largeur stable au survol** : `Button.icon` passait de `null` à la flèche au survol, ce qui
    changeait la largeur minimale du bouton (donc de la fenêtre) selon l'option survolée.
    **Fix** : `assets/ui/choice_arrow_blank.png` (même taille que `choice_arrow.png`, transparent)
    assigné par défaut à la place de `null` ; seul le survol change l'icône entre
    `choice_arrow_blank`/`choice_arrow`, la place est donc toujours réservée.
  - **`partner_choice.tscn` restructuré** : ne contient plus que les boutons de choix (plus de
    `Prompt`/`Dim`/`CenterContainer`) — même principe que `class_choice.tscn`/`npc_worker_f.gd` :
    **la question doit être dans une vraie boîte de dialogue**, pas dans la fenêtre de choix.
    `safari_entrance_gate.gd::_handle_return_from_safari()` affiche maintenant "Lequel
    choisis-tu comme partenaire ?" via `dialogue_box.tscn` (attend `page_typed`, puis
    `active = false`), avant d'afficher `partner_choice` (options seules) positionnée en haut à
    droite via le même `_place_window()` que `class_choice.gd`. **Règle générale à retenir** :
    toute future fenêtre de choix doit suivre ce pattern — question dans une boîte de dialogue
    tenue ouverte, fenêtre à côté = uniquement les options, jamais les deux mélangés dans la
    même fenêtre.

### ✅ Écran de capture (`encounter.gd`/`encounter.tscn`) refait à l'identique du vrai jeu
Reconstruit cette session à partir des vraies données pret (background, formule de capture,
mécaniques Appât/Pierre, animation) — tout est vérifié par rendu headless Godot (voir méthode
plus bas), pas juste "ça compile".
- **Fond de combat pixel-perfect** : décodé depuis `graphics/battle_terrain/grass/terrain.bin`
  (pret) — format tilemap GBA standard **64 tuiles de large × 32 de haut** (pas 32×64, testé les
  deux et vérifié visuellement), tuile = tile_id (bits 0-9) | flipX(10) | flipY(11) |
  palette(12-15), comme `map.bin` mais indépendant de ce format-là. Seules les 7 premières lignes
  (56px) contiennent du vrai contenu (ciel rayé + monticules d'herbe) ; le reste (lignes 7-14)
  est transparent dans les données — le sol est en réalité une **couleur plate** (pas de texture),
  sur laquelle plusieurs itérations ont été nécessaires (voir corrections ci-dessous). Assemblé
  en `battle_bg_grass.png` (240×160 natif, écran GBA exact) direct dans `assets/ui/`, pas de
  prescale nécessaire (le `TextureRect` stretch déjà en place s'en charge).
  **2 corrections post-retours Gus** :
  1. 1ère tentative : sol en bandes vertes ré-échantillonnées depuis les monticules (tuile 65)
     — trop saturé, créait une coupure nette de couleur avec le ciel pâle du dessus, donnant
     l'impression que les monticules d'herbe étaient "coupés" à leur base.
  2. **Version actuelle** : sol en bandes très pâles `(230,255,230)`/`(222,246,222)` — les
     MÊMES tons que le ciel (tuiles 89/91), pas de vert saturé ni de bleu — pour un rendu
     uniforme du haut en bas de l'écran, fidèle à la demande de Gus ("tout devrait être
     uniforme, blanc") et cohérent avec la capture Leveinard fournie en référence.
  **Animation `anim.bin`/`anim.png` (herbe qui bouge) pas exploitée** — amélioration possible
  plus tard.
- **Sprite du dresseur vu de dos** : trouvé dans pret `graphics/trainers/back_pics/`
  (`red_back_pic.png`, `leaf_back_pic.png`, `ruby_sapphire_brendan_back_pic.png`,
  `ruby_sapphire_may_back_pic.png` — un par apparence, correspondance avec
  `PlayerData.APPEARANCES`). Chaque fichier source contient 5 frames 64×64 empilées
  verticalement (animation d'envoi de balle) ; seule la 1ère frame (pose statique) est utilisée
  pour l'instant, extraite dans `assets/characters/<appearance>_back.png`. Contrairement aux
  sprites overworld (fond noir = transparent par convention), ces fichiers ont une **vraie
  transparence PNG (tRNS)** déjà correcte après un simple `.convert('RGBA')` — pas besoin de
  color-keying manuel. `encounter.gd` charge le bon fichier selon `PlayerData.appearance` et
  affiche le joueur en bas à gauche avec sa propre ombre (réutilise `enemy_mon_shadow.png`).
  Non fait : l'animation de lancer de balle (les 4 autres frames), cosmétique, pour plus tard.
- **Boîte de stats du Pokémon sauvage** (nom/sexe/niveau/barre de PV, haut-gauche) : couleurs
  réelles sampleées depuis `graphics/battle_interface/healthbox_elements.png` (vert PV
  `(115,255,172)`, fond de barre `(82,106,90)`). **Pas de reconstruction tuile-par-tuile de la
  vraie silhouette du cadre** (le vrai `healthbox_singles_opponent.png` a un coin diagonal
  caractéristique, complexe à assembler — cf. `DrawHealthboxbank`/`GetHealthboxElementGfxPtr`
  dans pret `src/battle_interface.c`) — on réutilise le même style de boîte crème/vert foncé que
  la boîte Safari Balls (`CreamBoxStyle` dans `encounter.tscn`, maintenant alignée directement
  au-dessus de la boîte d'action — même largeur, même bord droit), compromis assumé pour rester
  dans un temps raisonnable. Barre de PV toujours à 100% (les Pokémon Safari ne sont jamais
  blessés).
- **Boîte de message + boîte d'action** : **2ème itération**. 1ère tentative : réutiliser
  `assets/ui/dialogue_frame.png` (le cadre ondulé de `dialogue_box.tscn`) — rejeté par Gus après
  captures de référence (vraie boîte de combat FRLG = fond **bleu marine** avec bordure **or**,
  PAS le cadre ondulé crème de l'overworld ; ce sont deux systèmes de fenêtres différents dans le
  vrai jeu). Reconstruit depuis le vrai asset `graphics/battle_interface/textbox.png` +
  `textbox.bin` (pret) — tilemap GBA standard, décodé en 64×32 tuiles (`CopyToBgTilemapBuffer`
  copie tout le tilemap d'un coup dans `src/battle_bg.c::LoadBattleTextboxAndBackground`, pas de
  logique d'assemblage dynamique comme pour `menu_message.png`). Couleurs réelles sampleées :
  fond marine `(41,82,106)`, bordure or `(205,172,74)`. Implémenté en `StyleBoxFlat`
  (`BottomBoxStyle`) plutôt qu'en asset tuile-par-tuile (compromis de temps, comme la boîte de
  stats). **Une seule boîte unifiée** (`BottomBox`) contenant message (gauche) + séparateur
  vertical + actions (droite), fidèle à la disposition réelle — avant on avait 2 boîtes
  séparées (`MessageBox`/`ActionBox`), ce n'était pas fidèle. Les actions sont du **texte brut**
  (pas de bouton avec bordure individuelle), fidèle au vrai jeu.
- **⚠️ Piège police bitmap (suite, et la théorie "fond sombre" est FAUSSE)** : le texte de
  `BottomBox` (fond bleu marine) affichait des **rectangles blancs pleins** derrière chaque mot
  avec `dialogue_latin.fnt`. Théorie initiale : problème de contraste sur fond sombre, invisible
  sur fond clair par coïncidence. **Cette théorie est fausse** — `class_choice.tscn` et
  `partner_choice.tscn` (menus refaits même session, voir plus bas), sur fond **blanc**, à
  `font_size=32` (natif, comme `dialogue_box.tscn` qui fonctionne), ont montré EXACTEMENT le même
  bug (rectangles **noirs** cette fois, derrière chaque mot). Donc : ni le fond sombre, ni la
  taille non-native, ni `Button` vs `Label` n'expliquent le bug à eux seuls — `dialogue_box.tscn`
  et `HealthBox`/`SafariBox` fonctionnent, mais `BottomBox`, `class_choice` et `partner_choice`
  échouent, sans variable commune identifiée qui distingue les deux groupes. **Cause réelle non
  trouvée après plusieurs tentatives.** **Contournement appliqué partout où ça a merdé** :
  utiliser la police système par défaut de Godot (ne pas mettre `theme_override_fonts/font` ni
  `Button/fonts/font` vers `dialogue_latin.fnt`) — fonctionne de manière fiable à chaque fois.
  **Ne PAS perdre de temps à re-débugger ça sans une piste nouvelle** ; si un jour on veut
  comprendre, tester d'abord sur une scène minimale isolée (un seul Label, rien d'autre) pour
  éliminer les variables une par une plutôt que de deviner.
- **Formule de capture fidèle à 4 secousses** (`_attempt_catch()`) : implémente exactement
  `Cmd_handleballthrow` (pret `src/battle_script_commands.c`) — si `odds > 254` capture
  garantie, sinon `shake_odds = Sqrt(Sqrt(16711680/odds))`, `threshold = 1048560/shake_odds`,
  4 tirages `Random() < threshold` successifs. Message d'échec varie selon le nombre de
  secousses réussies (0 à 3).
- **Appât et Pierre** (`_on_bait_pressed`/`_on_rock_pressed`/`_end_of_round`) : fidèle à
  `HandleAction_ThrowBait/ThrowRock` + `HandleAction_WatchesCarefully` + `Cmd_if_random_safari_flee`
  (pret `src/battle_main.c` et `src/battle_ai_script_commands.c`). Mécanique complète : un
  `catch_factor` (base = `catchRate*100/1275`) est divisé par 2 (min 3) par l'appât, multiplié
  par 2 (max 20) par la pierre ; un compteur (2-6 tours aléatoires, plafond 6) décompte à chaque
  tour et redonne le taux de base **uniquement pour la pierre** (l'appât ne revient PAS au taux
  de base une fois épuisé — bizarrerie confirmée du jeu original, assumée). Le taux de fuite est
  doublé (max 20) si pierre active, divisé par 4 (min 1) si appât actif, sinon taux de base ;
  jet de fuite = `taux*5` % à chaque tour. **Aucune vraie donnée `safariZoneFleeRate` par
  espèce pour l'instant** (placeholder `SPECIES_FLEE_RATE=30.0` dans `encounter.gd`) — à
  rebrancher avec le vrai roster (point 3).
- **Plateformes (rond clair sous chaque combattant)** : remplace l'ancienne `enemy_mon_shadow.png`
  (ombre grise, pas fidèle — Gus a fourni des captures de référence montrant un **grand ovale
  clair/blanc**, pas une ombre). Cherché l'asset réel dans pret sans succès garanti (pas trouvé
  de `platform.png`/`reflection.png` dédié dans `graphics/battle_interface` ou
  `graphics/battle_terrain` ; `graphics/oak_speech/platform.png` existe mais pour un tout autre
  contexte). **Compromis assumé** : `assets/ui/platform.png` généré par script (ellipse pâle,
  bord légèrement plus foncé, flou léger) plutôt qu'un asset pret exact — mais couvre maintenant
  **les deux** combattants (Pokémon sauvage ET joueur), pas juste le Pokémon comme avant.
- **Message d'apparition : dans l'écran de combat, après le rideau** (2ème itération — 1ère
  tentative : l'afficher par-dessus la carte AVANT le rideau, rejetée par Gus : le rideau doit
  déjà être ouvert et le Pokémon déjà visible quand le message apparaît). Flux final dans
  `encounter.gd::play_entrance()` : animation d'entrée → "Un X sauvage apparaît !" affiché dans
  `BottomBox` (boutons grisés) → attend un appui (`_wait_for_continue()`, poll sur
  `ui_accept` via `await get_tree().process_frame` en boucle) → passe à "Que faites-vous ?" et
  active les boutons. `player.gd::_start_encounter()` n'affiche plus rien avant le rideau.
- **Animation d'entrée** (`encounter.gd::play_entrance()`, appelée par `player.gd` juste après
  l'ouverture du rideau de `battle_transition.gd`) : sprite qui rebondit en échelle
  (`TRANS_BACK`/`EASE_OUT`), boîte de stats qui glisse depuis la gauche, boîte Safari Balls
  depuis la droite, plateformes + sprite dos du joueur qui apparaissent en fondu. Boutons
  d'action désactivés jusqu'à la fin de l'animation.
- **⚠️ Piège Godot découvert cette session — police bitmap (BMFont) qui "bave" en noir** :
  deux causes distinctes, les deux à surveiller si on retouche `dialogue_latin.fnt`/tout futur
  BMFont :
  1. Le `.fnt.import` a par défaut `scaling_mode=2` (MSDF) — **totalement inadapté** à une
     police bitmap brute (pas des données de champ de distance), ça corrompt le rendu. Mettre
     `scaling_mode=0` dans le fichier `.import` (pas d'option UI simple trouvée, édition directe
     du fichier + suppression du cache `.godot/imported/*.fontdata` + relancer l'éditeur en
     `--headless --quit` pour forcer le réimport).
  2. **Ne jamais teinter `font_color` avec une couleur sombre** sur ce genre de police bitmap
     pré-colorée (encre foncée + halo blanc déjà dans les pixels) : `font_color` multiplie TOUTE
     la texture du glyphe, donc une teinte sombre écrase aussi le halo blanc et transforme le
     texte en rectangles noirs pleins. **Toujours `font_color = Color(1,1,1,1)`** (blanc, pas de
     teinte) quel que soit le fond de la boîte — déjà noté pour `dialogue_box.tscn`, ça vaut pour
     **tout** usage de cette police (a fait la même erreur dans `encounter.tscn` avant de s'en
     souvenir).
- **Méthode de vérification utilisée** : scène `Node2D` temporaire + script qui instancie la
  scène UI à tester, appelle directement les fonctions de test (`_on_bait_pressed()` etc.) et
  sauvegarde des captures d'écran (`get_viewport().get_texture().get_image().save_png(...)`) à
  chaque étape clé, lancé via `/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/_tmp_xxx.tscn`
  (pas `--headless`, il faut le vrai rendu). Toujours nettoyer les fichiers `_tmp_*` (+ `.import`
  + `.uid`) après coup.

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
Déjà appliqué à `encounter.tscn`, `partner_choice.tscn`, et **`class_choice.tscn`** (ce
paragraphe prédisait exactement ce bug — Gus a signalé que la fenêtre de choix de classe restait
invisible en jeu réel alors qu'elle s'affichait bien dans mes tests isolés headless ; cause
probable : contexte réel différent — plusieurs CanvasLayers déjà actifs autour de la map — qui
faisait passer `class_choice` derrière quelque chose d'autre. Corrigé par le même remède
`CanvasLayer` racine + `Control` enfant, cf. `class_choice.gd`/`class_choice.tscn`).
**`character_creation.tscn` utilise encore un `Control` nu en racine** — fonctionne
empiriquement (testé avec succès), mais si un bug d'affichage similaire apparaît dessus un jour,
appliquer le même correctif `CanvasLayer`.
**Méthode de diagnostic qui a marché** : onglet "Distant" du panneau Scène pendant que le jeu
tourne (bloqué) → sélectionner le nœud suspect → Inspecteur → section "Transform" → si `Size`
= (0,0), c'est ce bug.

## 📋 TODO — non urgent, à faire plus tard

### ✅ Boîte de dialogue — fidélité visuelle complète (FAIT, session Zone Safari UI)
- **Police fidèle FRLG** : `assets/fonts/dialogue_latin.png` + `.fnt` (format BMFont, importé
  nativement par Godot comme `FontFile`). Reconstruite depuis `graphics/fonts/latin_normal.png`
  (pret) : cellules de 16×16px (512 glyphes, confirmé par la longueur de la table de largeurs),
  largeurs réelles décodées depuis `sFontNormalLatinGlyphWidths` (pret `src/text.c`), mapping
  caractère→glyphe depuis `charmap.txt` (pret, racine du repo pret) — **l'`id` de chaque `char`
  dans le `.fnt` est le codepoint Unicode réel** (pas le byte GBA interne, qui sert seulement à
  indexer la table de largeurs et l'image source). Prescale ×2 (32×32 par glyphe). Charset
  couvert : A-Z/a-z/0-9, ponctuation courante, tous les accents français usuels + ♂/♀. Utilisée
  dans `dialogue_box.tscn` (`theme_override_fonts/font`, taille 32, **`font_color` remis à blanc
  `(1,1,1,1)`** — le bitmap a déjà ses couleurs réelles (encre foncée + halo blanc), un tint
  sombre comme avant casserait le halo). Fond transparent = couleur `(144,200,255)` dans la
  source pret (converti en alpha 0).
- **Bordure de dialogue fidèle** : `assets/ui/dialogue_frame.png`, reconstruite tuile par tuile
  depuis `graphics/text_window/menu_message.png` (pret) selon l'algorithme exact de
  `WindowFunc_DrawDialogueFrame` (pret `src/new_menu_helpers.c` ~ligne 520, indices
  `DLG_WINDOW_BASE_TILE_NUM+0..13`, symétrie verticale haut/bas via `BG_TILE_V_FLIP`). Couleur
  extérieure `(115,205,164)` = transparence (convention pret), convertie en alpha 0. Asset
  prescalé ×3 (cohérent avec la hauteur fixe existante de la boîte : 144px = 48px natif × 3,
  donc **aucune distorsion verticale**). Utilisée dans `dialogue_box.tscn` en `NinePatchRect`
  (`patch_margin_left/right=48`, `top/bottom=24`, `axis_stretch_horizontal=1` pour que la vague
  se répète au lieu de s'étirer horizontalement). Vérifié par rendu headless Godot (voir méthode
  ci-dessous).
- **Non fait / scope pas couvert** : seule `dialogue_box.tscn` (boîte de discussion PNJ) a été
  refaite. Les autres fenêtres (menus `class_choice`, `partner_choice`, boîte d'action de
  `encounter.tscn`) utilisent encore `ui_theme.tres` / police par défaut Godot — même technique
  réutilisable si Gus veut la fidélité partout plus tard (police : recalculer un nouvel atlas si
  besoin d'un charset différent ; bordure : `graphics/text_window/std.png` est probablement
  l'asset pour ces fenêtres-menu simples, pas encore décodé).

**Méthode utile découverte cette session** : Godot est installé en CLI
(`/Applications/Godot.app/Contents/MacOS/Godot`). `--editor --headless --quit` force l'import
des nouveaux assets sans ouvrir l'UI. Une scène `Node2D` temporaire avec un script qui instancie
l'UI à tester, attend quelques frames/`await create_timer`, puis
`get_viewport().get_texture().get_image().save_png(...)` permet de **voir réellement le rendu**
sans dépendre de l'utilisateur — beaucoup plus fiable que deviner les valeurs d'enum Godot
(a détecté un bug réel : `TextureRect.stretch_mode=1` = `TILE`, pas `SCALE`, ce qui répétait le
fond de l'écran de capture au lieu de l'étirer). Toujours nettoyer les fichiers `_tmp_*` après.

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
  Transitions **seamless** (pas de téléportation/écran noir) sur **tout Kanto extérieur
  connecté par des bords** (37 zones chargées autour de n'importe quel point de spawn — voir
  section dédiée plus bas). Seules les cartes qui n'ont pas de connexion réciproque valide
  restent en téléportation classique (Safrania via ses portes, Forêt de Jade et les 4
  sous-zones de la Zone Safari via leurs warps internes) — comportement fidèle au vrai jeu,
  pas une limitation.
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

## ✅ Transitions SEAMLESS (défilement continu FRLG) — étendu à tout Kanto extérieur

**Historique de rollout** : d'abord construit et validé sur une seule paire de cartes
(`pallet_town` ↔ `route1`, avec une liste blanche `SEAMLESS_MAPS`) pour isoler les bugs. Une
fois le test concluant, généralisé en système à base de graphe (BFS) qui charge **toutes**
les zones accessibles par connexions de bord depuis la carte de spawn — `SEAMLESS_MAPS` a été
**supprimé**, il n'y a plus de liste à maintenir.

### Principe (différent de ce qui était prévu initialement)
Le plan d'origine envisageait un joueur persistant + un gestionnaire de monde séparé (gros
refactor). **Solution retenue, plus légère** : le joueur reste embarqué dans sa carte comme
avant (aucun changement de `import_map.gd`/architecture des scènes), mais au chargement, on
parcourt en largeur (BFS) le graphe des `connections` à partir de la carte d'origine : pour
chaque connexion découverte, on **extrait les calques Below/Above/Collision de la carte
voisine et on les rattache directement dans la scène courante**, positionnés au bon décalage —
le Player/Camera de la carte voisine (générés par `import_map.gd` dans son propre fichier
`.tscn`) ne servent à rien ici et sont jetés (`queue_free()`). Le joueur continue simplement sa
marche ; ses coordonnées locales deviennent négatives/hors bornes d'origine, ce qui est normal
et pris en charge.

### Détail technique (`player.gd`)
- `var zones: Array` remplace l'ancien `neighbor_zones` : chaque entrée est un dict
  `{name, rect, size, ledges, grass, warps, connections}` — `zones[0]` est toujours la carte
  d'origine. `rect` est en coordonnées monde/locales à la scène courante (`Rect2`).
- `_load_world()` (appelée via `call_deferred` depuis `_ready()` — **important**, voir piège
  ci-dessous) : BFS sur le graphe des connexions. Pour chaque zone déjà placée, instancie
  chaque carte cible non encore vue, valide la réciprocité (`_has_reciprocal_connection`),
  calcule son décalage **relatif à la zone courante** (pas toujours l'origine — nécessaire pour
  un placement récursif correct au-delà du 1er degré), l'attache (`_attach_layers`), puis
  l'ajoute à la file BFS. Termine par `_update_camera_bounds()`.
- `_has_reciprocal_connection(n_connections, from_name, dname, off)` : une connexion n'est
  suivie que si la carte cible possède, dans ses propres métadonnées, une connexion retour vers
  `from_name` avec la **direction opposée** et l'**offset négé** (`OPPOSITE_DIR` +
  `-off` — **piège découvert cette session** : les connexions réciproques ont des offsets
  opposés en signe, pas égaux, contre-intuitif mais confirmé par re-dérivation depuis la
  formule Bourg Palette ↔ Route 1 déjà validée). C'est ce filtre, appliqué génériquement, qui
  exclut correctement les cartes qui ne doivent PAS être en mode seamless — sans cas
  particulier codé en dur :
  - **Safrania** (`saffron_city`) : ses données `connections` sont identiques à celles de
    `saffron_city_connection` (partagées avec routes 5/6/7/8), mais seule
    `saffron_city_connection` est confirmée réciproquement par ces routes. Fidèle au vrai jeu :
    Safrania s'atteint uniquement via les portes gardées (warps), pas à pied par un bord.
  - **Forêt de Jade** et les **4 sous-zones de la Zone Safari** (center/east/north/west) :
    accessibles uniquement par warps internes, pas de connexion de bord réciproque — cohérent
    avec la géographie FRLG réelle.
- `_compute_offset(from_rect, n_size, dname, off)` : version généralisée du calcul de décalage
  (auparavant codée en dur relative à `map_size`/l'origine uniquement), maintenant relative à
  n'importe quel `rect` déjà placé :
  - `up` : `(from_rect.x + off*TILE, from_rect.y - n_size.y*TILE)`
  - `down` : `(from_rect.x + off*TILE, from_rect.y + from_rect.height)`
  - `left` : `(from_rect.x - n_size.x*TILE, from_rect.y + off*TILE)`
  - `right` : `(from_rect.x + from_rect.width, from_rect.y + off*TILE)`
- `_attach_layers(root, node, world_off)` : extrait `Below`/`Above`/`Collision` de la scène
  voisine instanciée, les repositionne, et les rattache à `root` (la carte courante) : `Below`
  inséré à l'index 0 (doit rester **derrière** le joueur), `Above`/`Collision` ajoutés
  normalement (après, donc **devant** le joueur pour `Above`).
- `_zone_at_pixel(p)` / `_zone_and_local_tile(tile)` : localisent une position monde dans la
  bonne zone (`Rect2.has_point`) et convertissent en coordonnée locale à cette zone —
  **`_zone_and_local_tile` doit avoir une annotation de retour `-> Array` explicite**, sinon
  erreur de compilation Godot (« Cannot infer the type ») sur les 3 sites d'appel.
- `_is_grass`, `_warp_at`, `_ledge_dir_at` : réécrits pour chercher dans la zone (n'importe
  laquelle des `zones`) qui contient la case visée, plus seulement la carte d'origine — corrige
  la limitation documentée lors du test à 2 cartes.
- `_is_within_loaded_world(tgt)` : `_zone_at_pixel(tgt) != null` — vrai dès que la case visée
  est dans une zone déjà chargée, peu importe laquelle.
- `_update_current_zone()` (appelée après chaque pas terminé si `zones.size() > 1`) : détecte
  la zone courante et déclenche le bandeau de nom de lieu si elle a changé.
- `_update_camera_bounds()` : union (`Rect2.merge`) de tous les rects de `zones`, appliquée aux
  limites de la `Camera2D` du joueur.

### Validé (test headless, 37 zones depuis Bourg Palette)
Chargement du monde : ~600ms pour 37 zones, rects géométriquement cohérents (aucun conflit de
placement, validé à la fois par un script Python de pré-validation et à l'exécution). Traversée
réelle testée sur 2 frontières chaînées (Bourg Palette → Route 1 → plus loin dans Route 1),
capture d'écran vérifiée : rendu continu, pas d'écran noir, bandeau "Bourg Palette" puis "Route
1" corrects.

### ⚠️ Pièges Godot rencontrés cette session (transitions seamless)
1. **`add_child`/`remove_child` direct dans `_ready()` → erreur "Parent node is busy"** :
   l'arbre de scène est encore en cours de construction pendant `_ready()` (le nœud vient
   d'entrer dans l'arbre). Fix : appeler `_load_world()` via `call_deferred("_load_world")`
   plutôt que directement.
2. **`get_name()` est déjà une méthode native de `Node`** (retourne le nom du nœud) — l'autoload
   `map_names.gd` avait une méthode `get_name(scene_id)` qui écrasait la méthode native avec une
   signature incompatible, provoquant une erreur de compilation à l'autoload. Renommé en
   `get_french_name()`.
3. **Reproduire `change_scene_to_file()` dans un harnais de test est piégeux** : appeler
   `change_scene_to_file()` depuis la coroutine d'un nœud qui va lui-même être libéré par ce
   changement de scène provoque un blocage silencieux (le nœud appelant est détruit pendant que
   sa propre coroutine est encore suspendue en `await`). Et reproduire manuellement
   `add_child()` + `current_scene = ...` échoue aussi (`set_current_scene` exige que le nœud
   soit déjà enfant de `root`, donc l'ordre est piégeux). **Méthode qui a marché** : lancer
   directement la carte à tester comme scène de démarrage
   (`godot --path . res://scenes/maps/X.tscn`) et injecter la logique de test via un **autoload
   temporaire** (ligne ajoutée dans `project.godot`, retirée après coup) plutôt que via une
   scène `_tmp_*.tscn` classique — évite complètement le problème de self-destruction.

### Bug corrigé : bandeau affiché 2 fois sur une carte scindée en plusieurs scènes
Certaines cartes réelles FRLG (ex. Route 21) sont générées en **plusieurs scènes Godot**
(`route21_north` + `route21_south`, voir `import_map.gd`/`MAPS`) qui partagent le même nom
affiché en français (`map_names.gd`). `_update_current_zone()` comparait l'id de scène
(`current_map_name`), donc franchir `route21_north → route21_south` déclenchait 2 bandeaux
"Route 21" à la suite. **Fix** : nouvelle variable `last_banner_name` (dernier nom **français**
réellement affiché) ; le bandeau ne se déclenche que si `MapNames.get_french_name(...)` diffère
de `last_banner_name`, pas juste si l'id de scène change.

### Bug corrigé : à-coup visible en entrant/sortant d'un bâtiment (warp)
Signalé par Gus en testant : passage par un warp ponctuel (porte forêt de Jade, entrée/sortie
Zone Safari...) causait un petit lag. Cause : `change_scene_to_file()` déclenche la construction
synchrone du monde seamless de la nouvelle carte (`_load_world()`, jusqu'à ~600ms pour une carte
extérieure avec beaucoup de connexions) sur une seule frame — un gel bref et visible. **Fix**,
fidèle FRLG (pret `field_fadetransition.c`, `WarpFadeInScreen` : fondu noir avant un warp) :
nouvel autoload `ScreenFade` (`scripts/screen_fade.gd`), un `CanvasLayer` (layer 100, toujours
au-dessus) avec un `ColorRect` noir plein écran, persistant entre les scènes (contrairement à
tout ce qui vit dans `current_scene`). `await ScreenFade.fade_out()` (0.15s) est appelé juste
avant chacun des 3 `change_scene_to_file()` de warp dans `player.gd` (`_check_input` warp
direct, `_try_transition` connexion non-seamless, retour auto Zone Safari sans Safari Ball) ;
`await ScreenFade.fade_in()` est appelé à la fin de `_load_world()`, une fois le monde
construit — donc l'écran reste noir pendant tout le hitch, sans saccade visible. `is_busy = true`
posé avant le `fade_out()` (comme pour `_start_encounter()`) pour empêcher `_physics_process` de
redéclencher une transition pendant l'attente. Sans effet sur le tout premier chargement du jeu
(alpha du fondu déjà à 0, `fade_in()` est un no-op).

## ✅ Bandeau du nom de lieu (`location_banner.gd`/`.tscn`)
Fidèle FRLG (pret `src/map_name_popup.c`) : se déroule verticalement depuis le haut-gauche de
l'écran (même fenêtre "standard" `assets/ui/std_window.png` que les menus de choix — **pas** le
cadre ondulé des dialogues, ce sont deux éléments distincts dans le vrai jeu), reste affiché
~1.8s, puis se réenroule. Déclenché par `player.gd` : à chaque `_ready()` (donc à chaque
chargement/téléportation de carte) ET à chaque changement de zone détecté par
`_update_current_zone()` (pour les cartes en mode seamless). Texte = police système par défaut
de Godot (pas `dialogue_latin.fnt` — même bug de rendu déjà rencontré sur `PanelContainer` +
`StyleBoxTexture`, voir plus haut).

**Noms français** : `scripts/map_names.gd` (autoload `MapNames`), dictionnaire nom-de-scène →
nom français **vérifié via recherche web** (Poképédia/Pokébip), pas improvisé. Attention :
`get_name()` est déjà une méthode native de `Node`, la fonction de lookup s'appelle
`get_french_name()`. Si une carte est ajoutée à `MAPS` (import_map.gd) sans entrée dans
`MapNames.NAMES`, le bandeau affichera le nom de fichier brut (fallback dans
`get_french_name()`) — penser à compléter le dictionnaire à chaque nouvelle carte.

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
