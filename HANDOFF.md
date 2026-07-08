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
- **Police** : `dialogue_latin.fnt` via le thème partagé `assets/ui/game_theme.tres` (voir section
  dédiée plus bas — corrigé après coup, cette scène utilisait la police système par défaut à
  l'origine, exactement le bug documenté ci-dessous).
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

  **✅ Suite (session suivante, signalé par Gus) : incohérence de police dans TOUTE l'UI.**
  Une fois les deux causes ci-dessus réellement comprises, il s'est avéré que le "contournement"
  (police système par défaut) n'avait **jamais été retiré** des écrans où le vrai bug avait été
  contourné avant que la cause 2 soit identifiée : `class_choice.tscn`, `partner_choice.tscn`,
  `location_banner.gd`, plus les écrans ajoutés depuis dans ce même style
  (`pause_menu.tscn`, `save_slots.tscn`, `title_screen.tscn`) — tous utilisaient encore la police
  système, uniquement parce que leur `Button/Label` `font_color` était resté à une teinte sombre
  (`Color(0.1, 0.1, 0.1, 1)`, copiée-collée d'un menu à l'autre). Résultat : la boîte de dialogue
  (police fidèle) et les fenêtres de choix (police système) affichaient deux typographies
  différentes à l'écran en même temps — repéré par Gus sur un screenshot.
  - **Fix définitif — `assets/ui/game_theme.tres`** : un unique `Theme` partagé
    (`default_font = dialogue_latin.fnt`, `Label/colors/font_color` et tous les
    `Button/colors/font_*_color` figés à `Color(1,1,1,1)`, sauf `font_disabled_color` à
    `Color(1,1,1,0.5)` — l'alpha seul peut varier sans casser le rendu, jamais les canaux RGB).
    Appliqué en `theme = ExtResource(...)` sur le nœud `Control` racine de chaque écran
    (`class_choice.tscn`, `partner_choice.tscn`, `pause_menu.tscn`, `save_slots.tscn`,
    `title_screen.tscn`, `location_banner.tscn`) : la résolution de thème Godot remonte
    l'arbre, donc les sous-thèmes locaux de chaque scène (styles de bouton, tailles de police
    spécifiques) restent utilisables **tant qu'ils ne redéfinissent plus `font`/`font_color`**
    eux-mêmes — retiré de tous au passage.
  - **`scenes/ui/ui_theme.tres`** (encore plus ancien, seul restant à utiliser le style "boutons
    sombres génériques" explicitement abandonné plus tôt cette session, utilisé par
    `character_creation.tscn`) : gardé tel quel pour son style de bouton propre (pas dans le
    scope de ce fix), mais `default_font` ajouté vers `dialogue_latin.fnt`, et
    `Button/colors/font_hover_color` (qui était un jaune `Color(1, 0.9, 0.4, 1)`, une vraie
    teinte, pas juste un alpha) remis à blanc pour ne pas casser le glyphe — le survol reste
    perceptible via le changement de couleur de fond/bordure du bouton, pas la couleur du texte.
  - **`encounter.tscn`** : `BottomBox` (message + boutons d'action Ball/Appât/Pierre/Fuite)
    utilisait aussi la police système alors que `HealthBox`/`SafariBox`, dans la **même scène**,
    utilisaient déjà `dialogue_latin.fnt` correctement — ajouté `theme_override_fonts/font` sur
    le Label du message et `Button/fonts/font` sur `ActionTheme`.
  - **Règle à suivre pour toute nouvelle UI** : ne jamais créer de nouveau `Theme` ad hoc avec sa
    propre couleur/police de texte — appliquer `game_theme.tres` à la racine, et ne définir
    localement que ce qui est vraiment spécifique à l'écran (styles de bouton, tailles, marges).

  **⚠️ Découverte suite au screenshot de Gus (écran-titre) : le halo de `dialogue_latin.png` est
  OPAQUE, pas transparent.** Vérifié en inspectant la palette réelle du PNG : le halo blanc de
  chaque glyphe est bien `(255,255,255,255)` — alpha 255, donc un **rectangle plein**, pas un
  contour qui laisserait voir ce qu'il y a derrière. Dans le vrai jeu (et dans `dialogue_box.tscn`
  qui fonctionne), ça ne se voit jamais car le fond de la boîte de dialogue est **exactement** ce
  même blanc — le rectangle se fond dedans. Partout où le fond immédiat n'est PAS ce blanc exact
  (fond de bouton par défaut de Godot = gris, `ColorRect` de couleur = n'importe quoi), on voit un
  bloc blanc plein derrière chaque mot. **Ce n'est pas un bug Godot, c'est une contrainte de
  l'asset** : cette police ne peut être utilisée QUE sur un fond exactement blanc/`std_window.png`/
  `dialogue_frame.png` (leur intérieur est ce même blanc, vérifié). **Fix appliqué** : partout où
  `game_theme.tres` est utilisé, les boutons doivent avoir un style `StyleBoxEmpty` (transparent,
  laisse voir la fenêtre blanche derrière) plutôt que le style gris par défaut de Godot — ajouté à
  `title_screen.tscn` (nouveau : le titre "Pokémon Fangame" déplacé dans sa propre petite fenêtre
  `std_window.png` au lieu d'être directement sur le fond marine) et `save_slots.tscn` (boutons de
  slots + Revenir, qui n'avaient pas ce style). `class_choice`/`partner_choice`/`pause_menu`
  l'avaient déjà (`Btn_empty`), pas touché.
  - **`character_creation.tscn` / `scenes/ui/ui_theme.tres` volontairement PAS corrigé** : cet
    écran a un fond **noir** et des boutons à fond **sombre** (`StyleBoxFlat` foncé) — y appliquer
    `dialogue_latin.fnt` recréerait le même bug en pire (blocs blancs sur fond noir, contraste
    encore plus violent). Le corriger proprement demanderait de refaire tout l'habillage de
    l'écran en clair (fond blanc/crème + fenêtres `std_window.png`), un chantier plus gros que la
    simple cohérence de police — **laissé en l'état (police système par défaut), décision à
    prendre avec Gus** : soit on accepte que cet écran reste visuellement à part (c'est un écran
    de configuration, pas un écran "in-fiction"), soit on le refait dans le style clair du reste
    du jeu.

  **✅ Vrai fix (session suivante, signalé par Gus sur l'écran de capture) : le halo n'est pas un
  halo, c'est le fond opaque de la cellule + une ombre portée.** Le contournement ci-dessus
  (fenêtre blanche assortie) ne marche que si l'écran peut se permettre un fond blanc — impossible
  sur `encounter.tscn` (`HealthBox`/`SafariBox` en fond crème, `BottomBox` en fond marine, des
  couleurs fidèles au vrai jeu, non négociables). Inspection pixel par pixel de
  `dialogue_latin.png` : chaque cellule de glyphe (32×32) contient en réalité 3 zones bien
  distinctes — encre foncée `(56,56,56,255)`, une **ombre portée décalée** en gris clair
  `(216,216,216,255)` (pas de l'anti-aliasing, un vrai décalage visible au zoom), et le **fond de
  la cellule** en blanc opaque `(255,255,255,255)` qui n'a jamais été pensé comme un "halo" à
  proprement parler. **Fix définitif** : rendu uniquement ce blanc `(255,255,255,255)` transparent
  (alpha 0) dans `assets/fonts/dialogue_latin.png`, en gardant l'encre et l'ombre intactes.
  Vérifié avant/après par composition PNG sur fond blanc (aucun changement visuel, les deux
  scènes qui marchaient déjà continuent de marcher) et sur fond marine (bloc blanc disparu, texte
  propre avec juste son ombre). **Ce fix corrige tous les écrans d'un coup** (encounter.tscn
  compris) sans avoir besoin du contournement fenêtre-blanche — mais celui-ci reste utile pour
  la cohérence visuelle (une fenêtre `std_window.png` reste préférable à un texte nu). Le fichier
  `.fnt` (métriques/largeurs) n'a pas bougé, seul le PNG a changé (même dimensions, juste l'alpha).

  **✅ Marge intérieure des fenêtres `std_window.png`/`dialogue_frame.png`** : signalé par Gus sur
  le bandeau de lieu (texte trop proche de la bordure). Audit de tous les `content_margin_*` du
  projet : `location_banner.tscn` avait `content_margin_top/bottom = 10` (trop juste, corrigé à
  `16`) ; `title_screen.tscn` n'avait **aucun** `content_margin` sur son `WindowStyle` (le texte/
  les boutons touchaient quasi directement le bord intérieur de la bordure 9-slice) — ajouté
  `content_margin_left/right = 24`, `content_margin_top/bottom = 16`. `class_choice`/
  `partner_choice`/`pause_menu` (30/20) et `save_slots` (24/20 via son `MarginContainer`) avaient
  déjà une marge suffisante, pas touchés. `encounter.tscn` (stat box/message box, marges 8-12px)
  a des marges plus fines mais **déjà validées avec Gus** lors de sa conception détaillée
  (session capture Safari) — pas retouché sans nouvelle demande explicite sur cet écran-là.
  **Règle pour toute nouvelle fenêtre `std_window.png`/`dialogue_frame.png`** : toujours définir
  un `content_margin_left/right` ≥ 24 et `content_margin_top/bottom` ≥ 16 sur le `StyleBoxTexture`
  (ou l'équivalent via un `MarginContainer` si le contenu est enveloppé différemment) — ne jamais
  laisser le texte s'appuyer directement sur la bordure 9-slice.
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

**✅ Fix : joueur qui "marche sur place" juste avant le rideau de rencontre** —
`player.gd::_move_toward_target()` mettait `is_moving = false` puis appelait directement
`_start_encounter()` sans jamais repasser l'animation en `face` : l'anim `walk` avait été lancée
au début du pas (`_check_input()`) et ne se remet en `face` normalement que via le prochain
passage dans `_check_input()` (frame suivante) — sauf que `_start_encounter()` met `is_busy = true`
dans le même appel, ce qui bloque `_physics_process` avant qu'il n'y repasse. Résultat : le sprite
restait bloqué sur l'animation de marche en boucle pendant tout le rideau de transition. **Fix** :
`_play("face")` ajouté en toute première ligne de `_start_encounter()`. Vérifié que les autres
appels qui posent `is_busy = true` (warp, `_try_transition`, dialogue, pause) se déclenchent tous
alors que `is_moving` est déjà `false` depuis une frame précédente (donc `face` déjà affiché) —
pas de trou équivalent ailleurs.

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

## ✅ Système de sauvegarde

Décisions tranchées avec Gus (06/07/2026) : **3 slots**, sauvegarde **manuelle uniquement**
(mini-menu pause, pas d'auto-save), **écran-titre inclus** dans ce chantier ("Tests" = bouton
placeholder, sa fonction sera définie plus tard), **sauvegarde autorisée n'importe où** y compris
en pleine visite Zone Safari (vérifié fidèle FRLG : le vrai jeu bloque seulement pendant un
combat, pas la Zone Safari).

### Nouveaux fichiers
- **`scripts/save_manager.gd`** (autoload `SaveManager`) : moteur. `SLOT_COUNT := 3`,
  `SAVE_DIR := "user://saves/"`, un fichier JSON par slot (`slot_N.json`, lisible/débogable,
  pas de format binaire). `current_slot` (session active, -1 = aucune) et `play_seconds`
  (compteur de temps de jeu, incrémenté en continu dans `_process()` tant que `current_slot >= 0`).
  - `save_to_slot(n)` : sérialise `PlayerData` (tous les champs), `SafariState` (`active`,
    `balls`, `caught`), `play_seconds`, et la **position effective** du joueur — pas juste la
    scène `.tscn` chargée. Utilise `player._zone_and_local_tile(tile)` (déjà existant pour
    les transitions seamless, voir plus haut) pour trouver la bonne zone/tuile locale même si
    le joueur est physiquement dans une carte voisine chargée en recouvrement. Le `map_name`
    sauvegardé est donc toujours celui de la zone réelle sous les pieds du joueur.
  - `load_from_slot(n)` : restaure `PlayerData`/`SafariState`/`play_seconds`, puis réutilise
    **le mécanisme de warp existant** (`Transitions.pending/direct/direct_tile/facing` +
    `change_scene_to_file`) pour placer le joueur — `player.gd` n'a besoin d'aucune
    modification pour supporter le chargement, c'est exactement le chemin déjà emprunté par
    les portes/grottes.
  - `slot_summary(n)` / `format_playtime(seconds)` : pour l'affichage (nom, carte en français
    via `MapNames`, temps au format `H:MM`), sans toucher à l'état courant du jeu.
  - `delete_slot(n)` : supprime le fichier.
- **`scripts/pause_menu.gd`** + **`scenes/ui/pause_menu.tscn`** : mini-menu (2 boutons
  Sauvegarder/Reprendre seulement — le vrai menu Start FRLG viendra plus tard). Même style que
  `class_choice.tscn` (`dialogue_frame.png`, `CanvasLayer` racine, icône flèche
  blanche/pleine au survol), mais **centré à l'écran** plutôt que calé sur la boîte de
  dialogue. Ouvert par `player.gd` sur `ui_cancel` (Échap, action native Godot, pas besoin de
  la définir dans l'Input Map) quand `not is_busy` et le joueur est à l'arrêt ; pose
  `is_busy = true` le temps du menu, comme `_talk_to()`. "Sauvegarder" affiche ensuite un
  message de confirmation via `DialogueBoxScene` ("Partie sauvegardée !").
- **`scripts/save_slots.gd`** + **`scenes/ui/save_slots.tscn`** : écran de sélection de slot,
  **partagé** entre Nouvelle partie et Charger une partie via une propriété `mode` ("new"/
  "load") à définir **avant** d'ajouter le nœud à l'arbre (lue dans `_ready()`). Slot vide
  cliquable seulement en mode "new" (choisit ce slot, `SaveManager.current_slot = n`, aucune
  écriture disque avant la première vraie sauvegarde) ; slot rempli cliquable seulement en
  mode "load" (`SaveManager.load_from_slot(n)`, qui gère lui-même le changement de scène).
  Bouton supprimer sur tout slot rempli, dans les deux modes. Utilise `std_window.png` (fenêtre
  "standard", même asset que le bandeau de lieu et les menus de choix) plutôt que le cadre
  ondulé des dialogues — cohérent avec le principe déjà établi que ce sont deux styles de
  fenêtre distincts dans le vrai jeu.
- **`scripts/title_screen.gd`** + **`scenes/ui/title_screen.tscn`** : nouveau point d'entrée du
  jeu (`project.godot`, `run/main_scene`, remplace `intro.tscn`). 3 boutons : Nouvelle partie
  (ouvre `save_slots` en mode "new", puis `change_scene_to_file` vers `intro.tscn` une fois un
  slot choisi), Charger une partie (mode "load"), Tests (**ne fait rien pour l'instant**,
  décision reportée). Pas d'habillage visuel (juste un fond uni + la fenêtre des boutons) —
  aucun artwork de titre n'existe, pas dans le scope de cette session.

### ⚠️ Piège Godot découvert cette session : CanvasLayer imbriqué dans un CanvasLayer
Bug signalé par Gus en testant : cliquer sur "Charger une partie" ne faisait **rien**
visuellement. Diagnostic (via clic simulé + capture d'écran headless) : `save_slots` (un
`CanvasLayer`) était bien instancié et `visible = true`, mais **ne s'affichait pas du tout** à
l'écran. Cause : il était ajouté comme enfant direct de `title_screen.gd` (`add_child(...)` sur
`self`), et `title_screen.tscn` a lui-même un `CanvasLayer` comme racine. **Un `CanvasLayer`
ajouté comme enfant d'un AUTRE `CanvasLayer` ne se rend pas correctement** — contrairement à
tous les autres popups du jeu (`dialogue_box`, menus de choix, bandeau de lieu, menu pause) qui
fonctionnent très bien, car ils sont tous ajoutés via `get_tree().current_scene.add_child(...)`
sur une scène dont la racine est un `Node2D` (les cartes), jamais un `CanvasLayer`. `title_screen`
est le premier cas où la "scène courante" est elle-même un `CanvasLayer`. **Fix** : ajouter le
popup à `get_tree().root` (le Viewport) plutôt qu'à `self` :
```gdscript
get_tree().root.add_child(slots_screen)   # et pas add_child(slots_screen)
```
Pour éviter que les 2 fenêtres se superposent/restent cliquables en même temps, `title_screen.gd`
cache aussi son propre bouton-fenêtre (`buttons_window.visible = false`) tant que `save_slots`
est ouvert, et le réaffiche à la fermeture. **À retenir pour toute future scène dont la racine
est un `CanvasLayer`** (peu probable en dehors des écrans meta comme celui-ci, mais à vérifier
si le "vrai" menu Start FRLG est développé plus tard sur le même modèle).

### Format JSON d'un slot
```json
{
  "player_name": "...", "gender": "...", "appearance": "...", "chosen_class": "...",
  "intro_complete": true, "starter_species": "...",
  "map_name": "...", "tile_x": 0, "tile_y": 0, "facing": "...",
  "safari_active": false, "safari_balls": 30, "safari_caught": [],
  "play_seconds": 0.0
}
```
Ne contient que ce qui existe réellement dans le jeu aujourd'hui (voir FLOW.md, section 6) —
pas d'équipe/inventaire/quêtes/Pokédex, à ajouter au fur et à mesure que ces systèmes seront
construits.

### Validé (tests headless, 2 process Godot séparés pour prouver la vraie persistance disque)
Process 1 : lancé sur `pallet_town.tscn`, joueur déplacé jusqu'à se trouver physiquement dans
la zone `route1` chargée en recouvrement seamless, sauvegarde via le menu pause → fichier
`slot_2.json` confirmé avec `map_name: "route1"` (pas `pallet_town`) et la tuile locale
correcte. Process 2 (nouveau process, donc aucun état mémoire partagé) : lancé sur
`title_screen.tscn`, Charger une partie → slot 2 affiche bien le résumé correct → chargement →
scène `route1.tscn` chargée directement, position/orientation/`PlayerData`/temps de jeu tous
restaurés à l'identique.

---

## ✅ Refonte de l'intro narrative (Louise / Anselme, choix de classe déplacé à la fin)

Trame complète tranchée avec Gus et son ami le 06/07/2026 — voir `FLOW.md` section 4 pour le
scénario détaillé avec les dialogues réels. Résumé technique :

- **Changement majeur** : le choix de classe (menu `class_choice.tscn`) ne se fait plus au tout
  début (chez Louise, `worker_f`) mais **à la toute fin**, une fois que le joueur a un partenaire
  Pokémon. Entre les deux, Louise et Anselme (`worker_m`) donnent une présentation narrative des
  2 classes sans forcer de choix.
- **Nouveau champ `PlayerData.orientation_given`** : remplace l'ancien usage de
  `chosen_class.is_empty()` comme condition "le joueur a-t-il déjà vu l'intro de Louise" (devenu
  invalide puisque `chosen_class` reste vide pendant presque toute la partie maintenant). Ajouté
  à la sérialisation `SaveManager` (`save_to_slot`/`load_from_slot`).
- **`npc_worker_f.gd` (Louise)** : `_start_auto_intro()` ne fait plus que le discours d'accueil +
  renvoi vers Anselme (plus d'explication détaillée des classes ni de choix immédiat). Nouvelle
  fonction publique `ask_final_class_choice()`, appelée par `safari_entrance_gate.gd` juste après
  le choix du partenaire — réutilise `class_choice.tscn` à l'identique (même boucle
  repeat/chercheur-indisponible/competiteur qu'avant, juste déclenchée plus tard).
- **`npc_worker_m.gd` (Anselme)** : `get_lines()` donne maintenant la présentation complète des 2
  classes + les 30 Safari Balls + le fonctionnement de la capture (avant, cette explication était
  chez Louise). Nouvelle fonction publique `ask_session_finished() -> bool` : pose la question
  "tu as fini ?" avec un choix Oui/Non (nouveau composant `yes_no_choice.tscn`/`.gd`, générique,
  même style que `class_choice.tscn`), affiche la réponse correspondante, et retourne le résultat.
- **`safari_entrance_gate.gd`** :
  - `gate_check(warp)` distingue maintenant la porte **nord** (`target == "safari_zone_center"`,
    bloquée tant que `not PlayerData.intro_complete`) de la porte **sud** (`target ==
    "fuchsia_city"`, bloquée tant qu'en plus `PlayerData.starter_species` est vide) — avant, une
    seule condition uniforme s'appliquait aux deux portes, devenue incorrecte puisque
    `chosen_class` ne se remplit plus au début.
  - `on_gate_blocked()` : message différent selon l'état (`WAITING_FOR_ANSELME` de Louise avant
    Anselme, "Ton premier partenaire t'attend !" après), plus un petit **point d'exclamation**
    animé au-dessus du joueur (`_show_exclamation()`, nouvel asset `assets/ui/exclamation.png`,
    généré — pas d'équivalent direct trouvé dans les graphics pret `field_effects`, mais c'est un
    élément UI mineur, pas un asset in-fiction).
  - `_ready()` : au retour d'une visite Safari, si `SafariState.balls > 0` (retour volontaire),
    appelle `_ask_if_finished()` (nouvelle fonction, passe par Anselme) au lieu d'enchaîner
    directement sur le choix du partenaire ; si `balls <= 0` (retour forcé), comportement
    inchangé (`_handle_return_from_safari()` direct — ce cas était déjà entièrement pris en
    charge par le code existant, voir plus bas).
  - `_turn_and_return_to_park()` (nouveau) : si le joueur répond "Non" à Anselme, le fait pivoter
    (`facing = "north"`, `_play("face")`), petite pause, puis warp scripté (même mécanisme que
    les warps normaux : `Transitions.direct` + `ScreenFade.fade_out()`) vers
    `safari_zone_center.tscn` à la tuile (26, 30) — exactement la tuile de la porte d'entrée déjà
    utilisée par le warp inverse. `SafariState` n'est pas touché, la session continue à
    l'identique (mêmes balls restantes, mêmes captures).
  - `_handle_return_from_safari()` : logique de capture/Rattata/partenaire **inchangée**, mais
    enchaîne maintenant directement sur `louise.ask_final_class_choice()` si le joueur a
    désormais un partenaire mais pas encore de classe choisie — un seul enchaînement continu,
    pas besoin que le joueur aille reparler à Louise manuellement.
- **`encounter.gd`** : `_on_ball_pressed()` vérifie maintenant `SafariState.balls <= 0`
  **immédiatement après le lancer** (avant `_end_of_round()`), plutôt que de laisser continuer un
  tour appât/pierre pour rien (le bouton Ball est déjà désactivé à 0 ball, donc ces tours
  n'avaient plus vraiment de sens). Message dédié affiché dans l'écran de combat lui-même ("Il ne
  te reste plus aucune Safari Ball !"), avant que `player.gd` n'affiche son propre message de
  retour ("On te raccompagne à l'entrée.") — 2 messages distincts désormais, demandés par Gus.
  Le reste du flux 0-ball (transition, spawn, branchement Rattata/partenaire) existait déjà et
  n'a pas eu besoin d'être retouché.
- **2 nouveaux PNJ dans `safari_zone_center.tscn`** : un compétiteur aguerri et un assistant du
  Pr Chen, placés devant le bâtiment d'entrée (tuiles (23,29) et (29,29), ajustable). **Aucune
  interaction pour l'instant** (juste `npc.tscn` instancié avec un `sprite_name`, pas de script
  dédié — le `get_lines()` par défaut de `npc.gd` renvoie `[]`). Sprites extraits du vrai jeu
  (`kanto-pipeline/pokefirered/graphics/object_events/pics/people/cooltrainer_m.png` et
  `scientist.png`, convertis en RGBA exactement comme `worker_f.png`/`worker_m.png` avant eux) et
  copiés dans `assets/characters/cooltrainer.png`/`scientist.png`. Prévu pour recevoir une vraie
  interaction (aperçu de chaque classe) une fois que le système de combat de l'ami de Gus sera
  disponible et poussé sur le repo — pas de mini-jeu de combat inventé ici pour ne pas avoir à le
  refaire.
- **Mis de côté (déjà discuté avec Gus)** : objets de traversée du parc (canne à pêche, etc. —
  bloqué par l'absence de tout système d'inventaire) et vrai son "objet obtenu" pour "Voilà 30
  Safari Balls" (bloqué par l'absence de tout système audio dans le projet — aucun fichier son,
  aucun `AudioStreamPlayer` nulle part). Une **pause** dans le dialogue à ce moment est en place,
  pas le son.
- **Question encore ouverte** (voir FLOW.md) : faut-il aussi bloquer la porte sud tant que la
  classe finale n'est pas choisie chez Louise ? Actuellement non — la porte se débloque dès
  qu'un partenaire est choisi, avant même de reparler à Louise (qui enchaîne immédiatement de
  toute façon dans le flux normal, donc ça ne se remarque pas en pratique, mais techniquement
  rien n'empêche de sortir avant si le joueur y arrivait autrement).

---

## 🚧 Bordures de cartes mal jointes (zones grises)

Certaines jonctions de cartes seamless (voir section dédiée) ont des tailles qui ne
correspondent pas exactement à leur voisine, laissant apparaître du gris (aucune tuile chargée)
quand le joueur s'approche du bord. Un script d'analyse (`generated/*.json` : tailles + connexions
+ grille de collision, jetable dans `kanto-pipeline/`, pas commité) a trouvé **39 connexions
seamless réciproques, dont 12 avec un vrai décalage de taille**, et 5 d'entre elles ont une
portion de bord réellement praticable (donc gris garanti visible) : `route19`↔`route20`,
`vermilion_city`↔`route6`, `vermilion_city`↔`route11`, `route18`↔`route17`,
`cerulean_city`↔`route9`. Les 7 autres ont un bord entièrement bloqué (arbre/mur), probablement
déjà invisibles.

**Décision avec Gus** : pas de correction automatique/à froid — le remplissage (arbres/eau/
montagne) est une décision de terrain au cas par cas. **Workflow retenu** : Gus se balade en jeu,
capture d'écran + nom de la carte dès qu'il voit du gris, on corrige ensemble à chaque fois
plutôt que d'attaquer toute la liste d'un coup.

**Architecture des patchs** (pour ne jamais toucher aux ~60 maps générées, qui doivent rester
régénérables à tout moment) :
- `scripts/border_fillers.gd` (`class_name BorderFillers`) : manifeste `PATCHES`, dict
  `nom_de_carte -> [{scene, offset (Vector2i, tuiles, relatif à l'origine de la carte,
  peut être négatif)}]`. Vide pour l'instant.
- `scripts/create_border_filler.gd` (`@tool extends EditorScript`, comme `import_map.gd`) :
  génère une scène `scenes/maps/fillers/<nom>.tscn` = un `TileMapLayer` **vide**, avec le vrai
  jeu de tuiles d'une map source au choix (constantes `SOURCE_MAP`/`OUT_NAME`/`SIZE` en tête de
  fichier à adapter avant chaque exécution) — prêt à peindre à la main dans l'éditeur Godot avec
  l'outil de tuiles natif. Pas de calque `Above`/collision : ces patchs sont purement décoratifs
  (le joueur ne peut physiquement pas marcher au-delà des zones chargées, donc pas besoin de
  bloquer quoi que ce soit).
- `player.gd::_load_border_fillers()` (appelée en fin de `_load_world()`) : pose chaque patch
  du manifeste dont la carte correspond à une zone chargée, positionné à
  `zone.rect.position + offset*TILE_SIZE`, ajouté sous le joueur (comme `Below`).

**Marche à suivre pour un nouveau patch** : créer la scène vide avec `create_border_filler.gd` →
la peindre dans l'éditeur → ajouter une entrée dans `BorderFillers.PATCHES` avec le bon offset.

## Gotchas Godot
- Fichier modifié en externe : Godot garde en cache → **Scène → « Recharger la scène
  sauvegardée »**, ou fermer sans enregistrer + rouvrir, ou **redémarrer Godot** (le plus
  sûr pour vider le cache scripts/scènes).
- PNG modifié en externe : cliquer dans la fenêtre Godot (réimport auto au focus).
- Régénérer une map écrase `scenes/maps/<map>.tscn` (l'uid change ; `main_scene` est
  référencé par **chemin** dans `project.godot`, donc rien ne casse).
- Ne **jamais** committer `kanto-pipeline/pokefirered/` (gitignoré).

## ✅ Liste défilante dans `partner_choice.tscn` (débordement d'écran si trop de captures)

Signalé par Gus : avec beaucoup de captures (ex. 9 Rattata), la fenêtre de choix du partenaire
grossissait sans limite et débordait de l'écran. 3 options envisagées avec Gus (défilement natif
+ flèches indicatrices, boutons flèche un par un, pagination "voir plus") — **défilement natif
retenu** (aucun clic supplémentaire pour comparer toutes les captures, contrairement à la
pagination).

- **Structure** : `Window` → `VBox` (nouveau) → `UpArrow` / `Scroll` (`ScrollContainer`,
  scroll horizontal désactivé) / `DownArrow`. `Buttons` (la liste de boutons, inchangée sinon)
  déplacée à l'intérieur du `Scroll`.
- **Hauteur adaptative plafonnée** (`partner_choice.gd::setup()`) : mesure la hauteur naturelle
  du contenu (`buttons_box.get_combined_minimum_size().y`), l'utilise telle quelle si elle tient
  dans `MAX_LIST_HEIGHT` (200px, ~5 lignes), sinon plafonne le `ScrollContainer` à cette valeur
  (le contenu défile au-delà) — donc pas d'espace perdu pour une liste courte, pas de
  débordement pour une liste longue.
- **Flèches haut/bas clignotantes** (réutilise l'asset `down_arrow_3.png`/`down_arrow_4.png` déjà
  utilisé par `dialogue_box.gd` pour la flèche "suite" — `DownArrow` = même texture retournée
  verticalement pour `UpArrow`, pas de nouvel asset). **Piège évité** : ne pas utiliser
  `visible` pour les faire apparaître/disparaître pendant le défilement (ça changerait la taille
  du `VBoxContainer` parent à chaque bascule, donc la fenêtre entière se redimensionnerait de
  façon visible en scrollant) — utilisé `modulate.a` (0/1) à la place, qui garde l'espace réservé
  en permanence. Les flèches ne réservent cet espace QUE si la liste est effectivement défilante
  (`scrollable`, calculé une fois dans `setup()`) ; sinon elles restent à `visible = false` posé
  dans `_ready()`, sans jamais être basculées.

## ✅ Écran-titre : icône de flèche étirée (piège TextureRect dans un conteneur)

Signalé par Gus (capture d'écran) : la flèche de sélection paraissait plus grosse sur
l'écran-titre que dans les menus de choix. Cause confirmée : `choice_arrow.png` fait bien 24×24
partout, mais `title_screen.tscn` utilise un `TextureRect` custom (pas `Button.icon` comme les
autres écrans, à cause du texte centré demandé par Gus — voir plus haut) placé dans un
`HBoxContainer` à l'intérieur d'un bouton de 40px de haut. Sans contrainte, un `TextureRect`
s'étire par défaut (`size_flags_vertical` = FILL) pour remplir la hauteur de sa cellule, et
`stretch_mode` par défaut (`STRETCH_SCALE`) redimensionne la texture en conséquence — la flèche
grossissait donc silencieusement. **Fix** : `size_flags_vertical = 4` (SHRINK_CENTER) +
`stretch_mode = 5` (STRETCH_KEEP_CENTERED) sur les 3 `TextureRect` "Icon" — la texture reste
maintenant à sa taille native quelle que soit la hauteur de la cellule parente. **À vérifier
systématiquement pour tout futur `TextureRect` utilisé comme icône dans un conteneur** (le
`Button.icon` natif ne pose jamais ce problème, seul le `TextureRect` custom introduit pour le
texte centré y est sujet).

## ✅ Refonte de la création de personnage (nom → genre → apparence, style unifié)

Signalé par Gus : `character_creation.tscn` utilisait encore l'ancien style "boutons sombres
génériques" (`ui_theme.tres`, fond noir) au lieu du principe boîte de dialogue + fenêtre de choix
utilisé partout ailleurs — cette dette avait été explicitement laissée de côté lors de la session
précédente (voir plus haut, "volontairement PAS corrigé") en attendant une décision. Avec le vrai
fix du halo de police (transparence du fond de cellule, voir plus haut), le fond noir n'est plus
un problème : `dialogue_latin.fnt` s'affiche correctement sur n'importe quel fond désormais, donc
plus besoin de refaire tout l'habillage en clair comme envisagé — juste remplacer les composants.

- **Ordre changé** : nom → genre → apparence (avant : genre → nom → apparence).
- **`scripts/character_creation.gd` devient un orchestrateur pur** (`extends Node`, plus aucun
  visuel propre) : enchaîne 3 étapes async, chacune = boîte de dialogue (question, tenue ouverte
  via `page_typed`/`active = false`, exactement le principe déjà utilisé par
  `npc_worker_f.gd`/`safari_entrance_gate.gd`) + une fenêtre dédiée pour la réponse. Le fond noir
  vient de `intro.tscn` (déjà présent dans l'arbre, cette scène n'est qu'un enfant ajouté
  par-dessus) — `character_creation.tscn` n'a donc plus besoin de son propre `ColorRect` de fond.
- **`scenes/ui/name_entry.tscn`** (nouveau) : simple `LineEdit` + bouton "Valider" dans une
  fenêtre `std_window.png`. **Compromis assumé** : pas le clavier virtuel du vrai jeu (grille de
  lettres cliquables), juste un champ de texte standard — saisie clavier physique directe, plus
  simple et plus rapide pour un jeu PC, le clavier virtuel n'a de sens que pour une manette/GBA.
- **`scenes/ui/gender_choice.tscn`** (nouveau) : fenêtre de choix Garçon/Fille, calquée à
  l'identique sur `class_choice.tscn` (même structure, juste les 2 boutons différents).
- **`scenes/ui/appearance_choice.tscn`** (nouveau) : même principe mais avec des images
  (`TextureButton`) plutôt que du texte comme options — reprend telle quelle la logique
  `_face_preview()` déjà existante (aperçu frame sud debout de chaque sprite).
- **`assets/ui/game_theme.tres`** : ajout de `LineEdit/colors/font_color` (+ `font_selected_color`,
  `caret_color`) à blanc, pour que `name_entry.tscn` respecte la même règle que le reste
  (`dialogue_latin.fnt` exige toujours `font_color = Color(1,1,1,1)`, jamais une teinte).
- **`scenes/ui/ui_theme.tres` supprimé** : plus aucune référence dans le projet une fois
  `character_creation.tscn` migré, fichier mort retiré plutôt que laissé traîner.

### ✅ `name_entry.tscn` : `LineEdit`/bouton en gris par défaut Godot, corrigé
Repéré par Gus juste après (screenshot) : `NameEdit`/`Confirm` n'avaient reçu **aucun style**
(ni `StyleBoxTexture`/`StyleBoxEmpty`, ni via `game_theme.tres` qui ne définit pas de style de
`LineEdit`) — rendu avec l'apparence grise par défaut de Godot, détonnant avec le reste du jeu.
**Fix** : `Confirm` reprend `Btn_empty` (transparent, laisse voir la fenêtre blanche derrière,
identique aux boutons de `class_choice.tscn`). `NameEdit` reçoit un `StyleBoxFlat` dédié (fond
blanc, bordure bleu-gris `(98,115,123)` — la même couleur que la bordure de `std_window.png`,
prélevée directement dessus) plutôt que le style `LineEdit` gris par défaut.
- **Note technique utile pour la suite** : `caret_color` est un vrai aplat de couleur (pas du
  texte passé par `dialogue_latin.fnt`), donc **la règle "toujours blanc" ne s'applique pas à
  lui** — sur un fond blanc, un curseur blanc serait invisible. Remis à une couleur sombre
  localement sur `NameEdit` (`game_theme.tres` garde `caret_color` blanc par défaut, pertinent
  pour un futur champ de texte sur fond sombre).
- **Découverte annexe** : depuis le vrai fix du halo de police (fond de cellule transparent, pas
  juste `font_color`), teinter `font_color` en sombre n'est plus dangereux — ça ne recrée plus
  jamais de bloc noir, ça assombrit juste l'encre déjà foncée. La règle "toujours blanc" reste un
  bon défaut par prudence/cohérence, mais n'est plus une contrainte dure comme avant ce fix.

### 📋 Styles de fenêtre du vrai jeu — recherche faite, décision reportée
Suite à la question de Gus ("Pokémon propose-t-il d'autres options de fenêtre, coins carrés ?") :
`kanto-pipeline/pokefirered/graphics/text_window/` contient **11 styles réels** différents
(`std`, `type1` à `type10`), utilisés contextuellement dans le vrai jeu — pas juste `std`/
`menu_message` déjà exploités. Notamment **`type2`** : liseré noir double, coins nets, beaucoup
moins "arrondi/pixelisé" que `std_window.png`/`dialogue_frame.png` actuels — correspond
exactement à la demande de coins carrés. Comparatif visuel généré (composite des 11 types) et
montré à Gus. **Décision prise** : ne pas généraliser tout de suite (gros chantier, touche
quasiment tous les écrans) — recontacter Gus avec une vraie maquette avant de basculer quoi que ce
soit vers `type2` ou un mélange rond/carré selon le contexte (dialogue vs menus de choix).

## ✅ Texte noir/blanc selon le fond + réduction générale des tailles (police + flèche)

Gus a fourni 2 captures du vrai jeu : bandeau de lieu (fond clair → texte **noir**) et boîte de
combat (fond marine → texte **blanc**). Confirme le mécanisme déjà pressenti : le vrai jeu
recolore la même police selon le contexte (palette GBA), capacité perdue en figeant tout dans un
PNG à couleurs fixes. Gus a aussi trouvé le texte et la flèche de sélection trop gros par rapport
au vrai jeu.

- **Police blanche (`dialogue_latin_white.fnt`/`.png`)** : nouveau variant, encre inversée en
  blanc `(255,255,255)`, ombre inversée en gris foncé `(40,40,40)`, même fond de cellule
  transparent que le fix précédent. Généré en inversant précisément les pixels connus (56,56,56)
  et (216,216,216) de `dialogue_latin.png`, pas une reconstruction depuis zéro. **Seul écran
  concerné aujourd'hui** : `encounter.tscn` → `BottomBox` (fond marine, `Label` du message +
  `ActionTheme` des boutons Ball/Appât/Pierre/Fuite) — `HealthBox`/`SafariBox` restent en police
  sombre (fond crème). Tout le reste du jeu est déjà sur fond blanc/crème (y compris
  `character_creation` depuis la refonte de la session précédente), donc pas concerné.
  **Piège évité** : bien recréer le `.fnt.import` à la main avec `scaling_mode=0` (jamais laisser
  Godot déduire le défaut MSDF, cf. piège déjà documenté plus haut) et un `.png.import` en
  `importer="skip"` (le PNG n'est qu'une page de police, pas une texture à part).
- **Réduction ~25% des tailles de police**, appliquée partout : `game_theme.tres`
  (`default_font_size` 20→16), `dialogue_box.tscn` (32→24, la boîte de dialogue principale reste
  volontairement un peu plus grande), `location_banner.tscn` (22→16), tous les menus de choix
  (`class_choice`/`partner_choice`/`pause_menu`/`gender_choice`/`yes_no_choice`, 20→16),
  `save_slots.tscn` (titre 24→18, lignes 16→14), `title_screen.tscn` (titre du jeu 32→24),
  `encounter.tscn` (boîtes de stats 18→14, message/boutons 22 et 20→16). `name_entry.tscn`
  (champ de saisie 24→18 pour matcher). **Premier jet, à valider visuellement** — pas de mesure
  pixel-perfect possible sans capture directe du vrai jeu à comparer, donc ajustement empirique
  en attendant le retour de Gus.
- **Flèche de sélection régénérée plus petite** : `choice_arrow.png`/`choice_arrow_blank.png`
  passent de 24×24 à 16×16 (même triangle, juste redessiné à cette taille pour rester net plutôt
  que scalé). Comme les menus de choix utilisent tous `Button.icon` nativement (pas de
  `TextureRect` custom), le changement de taille est automatique partout **sauf**
  `title_screen.tscn` (utilise le `TextureRect` custom pour le texte centré, voir plus haut) où
  les réservations `custom_minimum_size` (`Icon` et `Spacer`) ont dû être mises à jour à la main
  (24→16).

## ✅ Nouveau style de fenêtre : coins carrés, liseré noir double (remplace std/dialogue_frame partout)

Décision de Gus après comparaison de maquettes : passer **toutes** les boîtes de dialogue et
fenêtres de choix du style rond (`std_window.png`/`dialogue_frame.png`, bordure bleu-gris/beige)
à un style carré à liseré noir double, plus "vintage".

- **Tentative de reconstruction fidèle du vrai asset "type2"** (un des 11 styles de fenêtre
  trouvés dans `graphics/text_window/`) abandonnée : inspection pixel par pixel a révélé des
  détails décoratifs (petits tirets) qui ne sont pas conçus pour être étirés à une taille
  arbitraire — une reconstruction en 9-slice donnait un motif de hachures cassé. Documenté ici
  pour ne pas retenter la même chose sans nouvelle piste.
- **`assets/ui/square_window.png`** (nouveau, dessiné à la main plutôt que reconstruit) : tuile
  64×64, bordure extérieure 3px + fond blanc 4px + bordure intérieure 2px, coins durs à 90°,
  couleur `(30,30,30)`. Conçu dès le départ pour un étirement 9-slice propre (motif uniforme le
  long de chaque bord, pas de décoration ponctuelle) — vérifié par un rendu de test étiré à
  500×180 avant de l'appliquer, aucune couture visible.
- **Remplace `std_window.png` ET `dialogue_frame.png` partout** (les deux anciens fichiers
  supprimés, plus aucune référence) : `dialogue_box.tscn` (`NinePatchRect`, `patch_margin` 48/24
  → 12 partout), et en `StyleBoxTexture` (`texture_margin` → 12 partout, `content_margin`
  **inchangé** dans chaque fichier — c'est un réglage indépendant du visuel de la bordure) dans
  `class_choice`, `partner_choice`, `pause_menu`, `gender_choice`, `yes_no_choice`, `save_slots`,
  `title_screen`, `location_banner`, `name_entry`.
- **Règle pour toute nouvelle fenêtre** : utiliser `square_window.png` avec `texture_margin` = 12
  sur les 4 côtés (ou `patch_margin` si `NinePatchRect`), jamais recréer un style rond sans
  décision explicite de Gus.

## ✅ Effet machine à écrire dans `encounter.gd` + 2e passe de taille de police

Gus a testé la réduction ~25% de la session précédente et l'a trouvée encore un peu petite. Comme
je n'avais pas de mesure fiable au pixel près pour trancher, on est reparti sur un ajustement
empirique : **+18% sur toutes les tailles de police déjà réduites** (16→19 par défaut, dialogue
24→28, écran-titre 24→28, etc.) — toujours pas une valeur définitive, à revalider en jouant.

- **`encounter.gd`** : tout le texte s'affichait d'un coup (`label.text = ...` direct), pas
  cohérent avec `dialogue_box.gd` qui a déjà l'effet machine à écrire partout ailleurs. Ajout de
  `_type_text(text)` (même `CHAR_DELAY = 0.02` que `dialogue_box.gd`), utilisé par `_say()` (les

## ✅ Écran de rencontre — repositionnement fidèle + fenêtre d'action séparée (06/07/2026)

Suite au retour de Gus comparant l'écran actuel à de vraies captures FRLG (Bulbizarre/Carapuce,
Onix/Charmander) : positions approximatives, boutons mélangés dans la boîte de message, style de
boîte pas identique, texte trop petit. Recherche faite dans `kanto-pipeline/pokefirered` avant de
retoucher quoi que ce soit (pas de réglage à l'œil) :

- **Positions réelles retrouvées dans le code décompilé** (combat simple, écran natif 240×160,
  `src/battle_anim_mons.c::sBattlerCoords` et `src/battle_interface.c::InitBattlerHealthboxCoords`) :
  - Sprite adversaire : centre `(176, 40)` → fraction d'écran `(0.7333, 0.25)`.
  - Sprite joueur (dos) : centre `(72, 80)` → `(0.30, 0.50)`.
  - Carte adversaire (healthbox) : centre `(44, 30)` → `(0.1833, 0.1875)`.
  - Carte joueur (même emplacement que `SafariBox` avant d'avoir un vrai partenaire) : centre
    `(158, 88)` → `(0.6583, 0.55)`.
  Toutes les ancres de `encounter.tscn` (`Sprite`, `PlayerSprite`, `HealthBox`, `SafariBox`)
  recalées sur ces centres, tailles de boîte conservées.
- **⚠️ La grande ellipse pâle sous chaque combattant (`Shadow`/`PlayerShadow`) n'est PAS
  officiellement dans FireRed/LeafGreen** — vérifié en décodant `terrain.bin`/`anim.bin` pixel par
  pixel (script `/private/tmp/.../decode_terrain.py`, jetable) avec la vraie palette : aucune
  ellipse n'est dessinée dans le tilemap de fond ; le seul asset "ombre" du repo entier
  (`graphics/battle_interface/enemy_mon_shadow.png`) ne fait que **32×8px** (bien trop petit),
  et n'existe que pour l'adversaire (commentaire pret : "The player's shadow is never seen").
  Gus confirme que ses captures viennent bien de Rouge Feu — la grande ellipse reste donc un
  **choix perso non documenté officiellement** ; ses ancres ont été recalées à l'œil sous les
  nouvelles positions de sprite (adversaire : ellipse entièrement visible juste sous les pieds ;
  joueur : ellipse volontairement coupée par `BottomBox`, comme sur les captures de Gus). À
  revoir si Gus retrouve la vraie origine de cet élément.
- **Fenêtre d'action séparée de la boîte de message** (`ActionWindow`, nouveau nœud) : les
  boutons Ball/Appât/Pierre/Fuite ne sont plus dans `BottomBox` (qui ne contient plus que le
  message) — même principe déjà établi pour `class_choice`/`partner_choice` (jamais mélanger
  question et options dans la même fenêtre). Réutilise **`square_window.png`** (le style actuel
  de toutes les fenêtres de choix, pas `std_window.png`/`dialogue_frame.png`, abandonnés) +
  `choice_arrow.png`/`choice_arrow_blank.png` au survol (icône réservée par défaut pour ne pas
  faire varier la largeur des boutons), exactement comme `class_choice.gd`. Ajoutée comme
  simple `PanelContainer` enfant de `Root` (pas un `CanvasLayer` séparé) : `encounter.tscn` est
  déjà lui-même un `CanvasLayer` racine, et un `CanvasLayer` imbriqué dans un autre ne se rend
  pas correctement (piège déjà documenté plus haut pour `save_slots`/`title_screen`).
- **`BottomBox` reconstruite en 3 couches imbriquées** (`BottomBox` or → `Mid` crème → `Inner`
  marine + `Label`) pour un rendu à liseré double plus proche du vrai `textbox.png` FRLG (bordure
  or, fin liseré clair, fond marine) — un seul `StyleBoxFlat` ne permet qu'une seule couleur de
  bordure, d'où les 3 `PanelContainer` imbriqués plutôt qu'un seul.
- **Toutes les tailles de police remontées à 31** (`HealthBox`, `SafariBox`, message, à la
  parité de `dialogue_box.tscn`) — avant : 19 (cartes) / 21 (message et boutons), sensiblement
  plus petit que le reste du jeu, repéré par Gus sur capture. Boutons d'action à 26 (un cran
  en dessous, cohérent avec la capture de référence où le texte d'action est visiblement plus
  petit que le message).
- **Non fait / à valider en jeu** (Godot éditeur ouvert en parallèle, pas de test headless) :
  toutes ces valeurs sont un premier jet basé sur les vraies coordonnées pret + mesure à l'œil
  pour l'ellipse — à confirmer visuellement par Gus, notamment le fait que `PlayerShadow`
  dépasse bien sous `BottomBox` sans clipping bizarre, et que `SafariBox`/`HealthBox` ne
  débordent pas avec le texte en 31.

### ✅ Itérations visuelles post-retours Gus (même session)
- Boutons gris moches sur `ActionWindow` : `ActionBtnTheme` ne définissait pas de style de
  bouton → Godot retombait sur le style gris par défaut du moteur. Fix : `StyleBoxEmpty`
  (`ActionBtn_empty`) sur `normal/hover/pressed/focus/disabled`, comme `Btn_empty` dans
  `class_choice.tscn` — laisse voir le fond blanc de `square_window.png`, texte en encre foncée
  via `dialogue_latin.fnt` (le thème `game_theme` fixe juste `font_color=blanc`, un no-op de
  teinte qui préserve l'encre déjà foncée de cette police, voir règle documentée plus haut).
- Repositionnements empiriques suite à captures de Gus (le sprite adversaire dérivé des
  coordonnées pret paraissait trop haut en vrai rendu — écart entre la sémantique exacte de
  `CreateSprite(x,y)` en C et mon hypothèse "centre visuel", pas creusé plus loin) : joueur
  descendu jusqu'à toucher `BottomBox` (pieds à `bottom=0.78`), adversaire descendu (centre
  `y` 0.25→0.33), `SafariBox` déplacée du milieu d'écran vers juste au-dessus d'`ActionWindow`
  (même largeur qu'elle) plutôt que sa position dérivée de pret (jugée "en plein milieu").
- **⚠️ Piège `TextureRect.stretch_mode` sur `Shadow`/`PlayerShadow`** : élargir l'ancre du
  `TextureRect` ne changeait rien visuellement — `stretch_mode = 5` (`KEEP_ASPECT_CENTERED`)
  verrouille le ratio natif de la texture et centre dedans, indépendamment de la taille du
  conteneur. Repassé à `stretch_mode = 0` (`SCALE`, remplit vraiment le rectangle d'ancrage,
  déforme si besoin) pour que l'ellipse suive réellement les ancres. **Sprite/PlayerSprite
  restent en `stretch_mode = 5`** (aspect gardé intentionnellement pour les sprites Pokémon/
  joueur, pas de déformation) — ne pas appliquer ce fix par réflexe à tout `TextureRect` de la
  scène, seulement à `Shadow`/`PlayerShadow`.
- Ellipse adversaire remontée et élargie en 3 passes successives (retours itératifs de Gus sur
  captures) : centre final `y≈0.40`, largeur `≈0.52` (contre `y≈0.55`/`0.36` au premier jet) ;
  ellipse joueur élargie à `≈0.52` sans toucher sa position verticale (demande explicite de
  Gus de ne pas y toucher).
- **Ellipse toujours pas retrouvée officiellement dans `pokefirered`** malgré une recherche
  poussée (décodage pixel par pixel de `terrain.bin`/`anim.bin` avec le vrai découpage en blocs
  VRAM 32×32, confirmé via `LZDecompressVram` dans `src/battle_bg.c`) — Gus a laissé tomber la
  piste pour l'instant, on garde `platform.png` (asset perso) ajusté à l'œil.
- **Transition de retour de combat** (`player.gd::_start_encounter()`) : avant, l'écran de
  capture disparaissait d'un coup (`encounter.queue_free()` direct) au retour sur la map — cut
  brutal signalé par Gus. 1ère tentative : réutiliser `battle_transition.gd` (rideau flash +
  fermeture, comme l'entrée en combat) — rejetée par Gus, trop pour un simple retour. **Fix
  retenu** : simple fondu noir via l'autoload `ScreenFade` (`fade_out()` → `encounter.queue_free()`
  → `fade_in()`), le même mécanisme déjà utilisé pour les warps/entrées de bâtiment — cohérent
  avec le reste du jeu, pas de nouvel effet inventé. Le cas 0 Safari Ball (dialogue + 2e
  `ScreenFade.fade_out()` + warp vers `safari_entrance`) reste inchangé après.

## ✅ Menu pause : Reprendre/Sauvegarder/Quitter (nouvel ordre + action Quitter)

`pause_menu.tscn`/`pause_menu.gd` réordonnés (Reprendre, Sauvegarder, Quitter — avant :
Sauvegarder, Reprendre seulement). Nouveau bouton **Quitter** : fondu noir (`ScreenFade`) puis
`change_scene_to_file` vers `title_screen.tscn` — pas de sauvegarde automatique, cohérent avec
la règle déjà en place (sauvegarde toujours volontaire).

**⚠️ Bug corrigé juste après (signalé par Gus, testé) : écran noir bloqué après "Quitter".**
`ScreenFade.fade_out()` assombrit l'écran mais **rien n'appelait `fade_in()`** une fois sur
`title_screen.tscn` — contrairement aux cartes, où c'est `player.gd::_load_world()` qui s'en
charge après chaque warp, `title_screen.gd` n'avait jamais eu besoin de ça (c'est normalement
la toute première scène chargée au lancement du jeu, jamais atteinte via un fondu avant
aujourd'hui). **Fix** : `ScreenFade.fade_in()` ajouté en tête de `title_screen.gd::_ready()` —
sans effet si l'alpha est déjà à 0 (démarrage normal), corrige le cas "Quitter". **Règle à
retenir** : toute future scène qui peut être atteinte à la fois au démarrage ET via un
`ScreenFade.fade_out()` doit appeler `fade_in()` dans son propre `_ready()`.

## ✅ Flèche de sélection ajoutée à `save_slots.tscn`

Signalé par Gus : la modale de sauvegarde/chargement n'avait pas la flèche `choice_arrow.png`
au survol contrairement aux autres menus de choix. Les boutons de cet écran sont créés
**dynamiquement en code** (`save_slots.gd::_build_row()`, pas dans le `.tscn`, un par slot +
un "Supprimer" par slot rempli) — nouvelle fonction `_setup_arrow(btn)` (icône
`choice_arrow_blank.png`/`choice_arrow.png` au survol, `icon_alignment`/`expand_icon`) appliquée
à chaque bouton créé (`slot_button`, `delete_button`) et au bouton statique `Back` (Revenir) en
`_ready()`. Seul le `Label` de titre ("Sauvegarder"/"Charger une partie"/"Nouvelle partie") n'a
pas de flèche, comme demandé (ce n'est pas une action cliquable).

**⚠️ Tentative abandonnée : flèche collée au texte centré de "Revenir".** Contrairement aux
lignes de slots (texte aligné à gauche, flèche `Button.icon` déjà collée dessus), "Revenir" a un
texte **centré** — la flèche native (`icon_alignment`) reste ancrée au bord gauche du bouton,
loin du texte. Essayé sans succès :
1. `alignment = LEFT` sur le bouton (aligne texte à gauche comme les slots) — rejeté par Gus,
   il voulait garder "Revenir" centré.
2. `icon_alignment = CENTER` au lieu de `LEFT` — la flèche devient invisible (cause exacte non
   identifiée, semble se superposer sous le label plutôt que se placer à côté).
3. Repris le pattern `Content` (`HBoxContainer`) + `Icon`/`Label`/`Spacer` déjà utilisé par
   `title_screen.gd` pour ce même problème (bouton avec texte centré + icône) — toujours rendu
   avec la flèche au bord gauche du bouton en jeu, cause non comprise (fonctionne pourtant sur
   `title_screen.tscn` avec une structure identique).
**Décision de Gus** : laissé en l'état (flèche à gauche via `_setup_arrow(back_button)`, comme
avant ces tentatives) plutôt que de continuer à bricoler sans piste fiable. À reprendre
seulement avec une vraie nouvelle piste (ex. tester en isolant une scène minimale, comme
recommandé ailleurs dans ce document pour d'autres bugs de rendu Godot non élucidés).

## ✅ Écran de rencontre — 2 retours post-test (alignement + blocage testeur)

- **`HealthBox` alignée avec `BottomBox`** : les deux `anchor_left` étaient légèrement décalés
  (0.0183 vs 0.03, hérité du recalage sur les coordonnées pret qui ne visait pas cet
  alignement). Mis à `0.03` des deux côtés (largeur de `HealthBox` conservée).
- **⚠️ Bug UX corrigé : message "Un Rattata sauvage apparaît !" bloquait un testeur.**
  `_wait_for_continue()` attendait un appui `ui_accept` avant d'enchaîner sur "Que veux-tu
  faire ?" (fidèle FRLG à l'origine) — un testeur ne l'a pas compris et est resté bloqué, aucune
  autre étape de cette séquence ne demande d'appui. **Fix** : remplacé par une simple pause
  chronométrée (`get_tree().create_timer(1.3).timeout`, même ordre de grandeur que les autres
  messages de `encounter.gd`), enchaîne seul sans action requise. Fonction `_wait_for_continue()`
  supprimée (plus aucun appelant).
- **Accéléré le texte à l'appui, comme `dialogue_box.gd`** : demandé par Gus juste après (il a
  remarqué qu'un appui pendant la frappe n'accélérait rien ici, contrairement aux PNJ). Le
  mécanisme `skip_requested`/`typing` existait déjà dans `_type_text()` mais rien ne l'activait
  depuis la suppression de `_wait_for_continue()`. Ajout de `_unhandled_input()` (même pattern
  que `dialogue_box.gd`) : un appui `ui_accept` pendant que `typing == true` affiche le texte
  en cours instantanément — vaut pour **tous** les messages de cet écran (apparition, capture,
  appât/pierre, fuite...), pas seulement celui d'ouverture.
- **Flèche de continuation + saut du délai, pour être iso avec `dialogue_box.gd`** : Gus a
  remarqué qu'un 2e appui (une fois le texte complet affiché) ne faisait rien — il fallait
  attendre le délai fixe (1.3-1.5s) comme pour tous les PNJ. Nouvelle fonction
  `_wait_or_continue(duration)` : affiche `continue_arrow` (même asset `down_arrow_3/4.png`
  clignotant que `dialogue_box.gd`, nouveau nœud `Arrow` sous `BottomBox/Mid/Inner`, en second
  enfant du `PanelContainer` ancré en bas-droite — un `PanelContainer` redimensionne bien
  chaque enfant indépendamment selon ses propres ancres, comme un `Control` classique, donc
  `Label` et `Arrow` coexistent sans conflit) et attend soit le délai, soit
  `advance_requested` (mis à `true` par `_unhandled_input` sur un appui pendant que
  `waiting == true`). `_say()` et le délai de `play_entrance()` utilisent maintenant cette
  fonction au lieu d'un simple `create_timer(...).timeout`.
- **⚠️ Bug corrigé juste après (signalé par Gus) : flèche énorme, centrée dans la boîte.**
  `Label` et `Arrow` étaient tous les deux enfants directs du `PanelContainer` `Inner` —
  **un `Container` (dont `PanelContainer`) redimensionne TOUS ses enfants pour remplir tout le
  rectangle disponible, sans respecter leurs ancres individuelles** (contrairement à
  `dialogue_box.tscn`, dont la racine `Panel` est un `NinePatchRect`, un `Control` classique, pas
  un `Container` — d'où les ancres bas-droite qui y fonctionnaient). Résultat : `Arrow` était
  étiré à la taille entière du panneau. **Fix** : nouveau nœud `Content` (`Control` nu, pas un
  `Container`) inséré comme unique enfant d'`Inner`, avec `Label`/`Arrow` déplacés dedans — un
  `Control` respecte les ancres de ses enfants librement, contrairement à un `Container`.
  **Règle à retenir** : ne jamais mettre plusieurs enfants avec des ancres différentes
  directement dans un `PanelContainer`/`Container` — toujours passer par un `Control`
  intermédiaire si plusieurs éléments doivent coexister à des positions différentes dans la
  même zone.

## ✅ `scripts/typewriter.gd` — effet machine à écrire mutualisé

Gus a demandé de vérifier si la boîte de dialogue PNJ et celle de l'écran de combat étaient
identiques (taille de police, vitesse de frappe) — confirmé identiques (31, `CHAR_DELAY=0.02`)
mais dupliquées dans `dialogue_box.gd` (accumulation dans `_process`) et `encounter.gd` (boucle
`await create_timer` par caractère), avec le risque qu'elles divergent un jour sans que ça se
remarque. Extrait en composant partagé à la demande de Gus ("pour être clean, éviter des
surprises plus tard") :

- **`Typewriter`** (`class_name`, `extends RefCounted`) : `start(text)` / `skip()` /
  `update(delta)` (à appeler depuis le `_process()` de l'appelant, pas de `_process` propre —
  un `RefCounted` n'est pas un `Node`) / signal `completed`. Un seul `CHAR_DELAY` (0.02),
  une seule logique de révélation caractère par caractère.
- **`dialogue_box.gd`** : `current_text`/`revealed`/`char_timer`/`typing` supprimés, remplacés
  par une instance `typewriter` ; `_show_page()` appelle `typewriter.start(...)`, la logique
  qui suivait (afficher la flèche, émettre `page_typed`) déplacée dans un nouveau callback
  `_on_page_typed()` connecté au signal `completed`.
- **`encounter.gd`** : `typing`/`skip_requested`/`CHAR_DELAY` supprimés, `_type_text()` devient
  un simple wrapper (`typewriter.start(text)` puis `await typewriter.completed`) — tous les
  appelants existants (`_say()`, `play_entrance()`, etc.) inchangés, toujours `await`-ables
  pareil qu'avant.
- **Non partagé, volontairement** : la logique de flèche de continuation reste distincte dans
  les deux fichiers (comportement différent : `dialogue_box.gd` attend toujours un appui pour
  avancer, `encounter.gd` avance seul après un délai sauf appui — cf. entrée précédente sur le
  blocage testeur). Seul l'effet de frappe caractère par caractère était vraiment dupliqué à
  l'identique.
  messages type "Gotcha !"/"Vous lancez un appât !") et par le message d'apparition + "Que
  veux-tu faire ?". Un appui pendant la frappe l'affiche instantanément (`skip_requested`, même
  logique que `dialogue_box.gd`) plutôt que de sauter à l'étape suivante par erreur.
  - Le message d'apparition (`intro_message`) se tape maintenant **en parallèle** de l'animation
    d'entrée (rebond du sprite, glissement des boîtes) plutôt qu'instantanément avant — appelé
    sans `await` dans `play_entrance()` pour lancer la frappe en tâche de fond pendant que le
    `Tween` joue, fidèle à la sensation du vrai jeu (texte qui tape pendant que le Pokémon
    apparaît, pas avant).
