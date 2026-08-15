# Acte 1 — Parc Safari (Arrivée à Kanto)

## Statut

Structure validée avec Gus (10/07/2026). **Remplace `tutorial-competiteur.md`**
dans son organisation : les 2 tutos ne sont plus optionnels ni indépendants,
ils forment désormais un seul parcours guidé obligatoire (voir
`scenario.md`, le Parc Safari est le vrai premier acte de l'histoire, donc
plus question de rater un objet clé en sautant un tuto). Le contenu déjà
écrit dans `tutorial-competiteur.md` (dialogues de combat) reste réutilisable
et est repris ci-dessous, mais l'organisation générale de ce document-ci fait
foi.

Dialogues de combat à finaliser au fil de l'implémentation du système de
combat (en cours par l'ami de Gus — les 2 combats Compétiteur ne sont pas
encore jouables).

## Vue d'ensemble

Le joueur vit un parcours guidé unique dans le Parc Safari, qui alterne
actions Chercheur et Compétiteur, le fait traverser tout le parc, et le fait
repartir avec les objets clés nécessaires pour la suite (`scenario.md` acte 2
et au-delà). L'ordre choisi (10/07/2026) : **Chercheur d'abord**, puis
Compétiteur.

## Personnages

- **Yohan** — guide Compétiteur (homme), sprite déjà en place
  (`cooltrainer_m`).
- **Camille** — guide Chercheur (homme), sprite déjà en place (`scientist`),
  zone 1.
- **Julien** — second assistant du Pr Chen (homme), distinct de Camille,
  plutôt tourné vers les ruines/fossiles que vers les Pokémon vivants, zone 2
  (sprite `scientist` réutilisé pour l'instant, à distinguer visuellement
  plus tard si besoin).
- Louise, Anselme — inchangés (voir `FLOW.md` section 4).
- Rival et allié·e — pas rencontrés pendant le parcours guidé lui-même, ils
  apparaissent à la toute fin de l'acte, au retour dans le bâtiment (voir
  `scenario.md`, section Personnages récurrents).

## Règle transverse : dialogues neutres en genre

Voir `game-design.md`, section "Conventions d'écriture" — vaut pour tous les
dialogues ci-dessous.

---

## Déroulé complet

1. **Anselme** explique les 2 classes, précise que les arènes/badges sont un
   tronc commun aux deux voies (formation pratique, débutant → confirmé),
   oriente explicitement vers **Camille en premier** (première maison, zone
   1), prévient qu'aucun Pokémon sauvage ne se montrera avant d'avoir des
   Safari Balls, et rappelle qu'on peut sauvegarder à tout moment via le menu
   pause. Débloque la porte nord. **Dialogues exacts validés le 12/07/2026**,
   voir `PRESENTATION` dans `scripts/npc_worker_m.gd`.
   - Le **sac** n'est plus donné ici : le joueur l'a déjà en arrivant, pas
     besoin de le remettre en scène.
   - Les **30 Safari Balls ne sont plus données à ce stade** : elles seront
     remises par Anselme en personne, dans le parc, juste après les 2 tutos
     (voir étape 7 bis ci-dessous, `PARK_HANDOFF` dans le script). ⚠️ Câblé en
     test bout en bout (13/07/2026, voir point 7 plus bas) mais sur une
     condition simplifiée (`PlayerData.has_surf`) plutôt qu'un vrai flag de
     complétion des 2 tutos, qui n'existe pas encore. Le comportement des
     balls elles-mêmes reste inchangé (données dès l'entrée dans le parc via
     `SafariState.enter()`) : ce qui change vraiment avec Anselme, c'est le
     déblocage des rencontres sauvages et la canne à pêche.
   - 🎓 **Moment pédagogique** : rappel qu'on peut **sauvegarder à tout
     moment** via le menu pause.

2. **Camille — action 1 : le Pokémon "un peu particulier"** (zone ❓ — à
   assigner sur la vraie carte)
   - **Dialogues d'ouverture validés (12/07/2026)** :
     1. *"Ah, te voilà. Anselme m'a prévenu."*
     2. *"Chercheur, c'est un métier de patience et d'observation. Tu vas voir,
        c'est très différent de foncer dans le tas."*
     3. *"Tiens, prends ça : un Pokédex. Il recense déjà toutes les espèces de
        Kanto, ou presque. Tu le trouveras dans les objets importants de ton
        sac, et bientôt directement avec la touche 1 (modifiable plus tard
        si besoin)."*
     4. *"D'ailleurs, ça tombe bien : on vient de recevoir un Pokémon un peu
        particulier, et il s'est échappé dans cette zone avant qu'on ait pu
        bien l'observer."*
     5. *"Tu veux bien aller y jeter un œil ? Cherche du côté des hautes
        herbes, il ne doit pas être bien loin."*
   - Camille explique brièvement la classe Chercheur, remet le **Pokédex**
     (déjà pré-rempli pour tout Kanto sauf légendaires — voir section
     dédiée ci-dessous et `game-design.md`).
     - 🎓 **Moment pédagogique** : explication rapide de l'usage de base du
       Pokédex (comment l'ouvrir, ce qu'une fiche affiche).
   - Camille explique que le labo vient de recevoir un Pokémon "un peu
     particulier" et qu'il s'est échappé dans cette zone, sans en dire plus
     — reste volontairement vague sur ce qui le rend spécial. Le joueur doit
     le retrouver en repérant un patch d'herbes hautes qui bouge selon un
     motif différent des autres (mécanique de repérage visuel).
   - Une fois localisé, capture via le système existant (appât/pierre,
     `scripts/encounter.gd`) — sert de mise en pratique immédiate du
     système de capture, avec Camille qui coache en direct (premier vrai
     usage guidé de la mécanique dans l'histoire, avant la session libre
     plus tard dans l'acte).
     - 🎓 **Moment pédagogique** : explication du fonctionnement appât/
       pierre pendant cette toute première capture encadrée.
   - **Révélation** : c'est un **Minidraco chromatique (shiny)** — surprise
     à la capture, Camille réagit avec étonnement ("Attends... ses couleurs
     ne sont pas normales. C'est... c'est un shiny !"). Il repart avec elle
     pour être étudié au labo du Pr Chen — le joueur ne le garde pas. Plante
     une graine thématique sur les chromatiques (pourquoi ils existent, en
     quoi ils diffèrent) qui pourra revenir en quête de recherche plus tard,
     et prépare un possible retour de ce **même individu**, évolué (Draco ou
     Dracolosse chromatique), capturable cette fois, dans l'arc Chercheur de
     l'acte 4 (légendaire/chromatique/méga-évolution — voir `scenario.md`).
     ❓ Un fil équivalent pour le Compétiteur (ex. un Pokémon adverse
     remarquable croisé pendant le combat en duo de Yohan, retrouvé en face
     à la Ligue en acte 4) — idée à creuser plus tard, pas encore
     développée.

3. **Julien — action 2 : les fragments des ruines** (zone 2,
   `safari_rest_house_east`) ✅ implémenté (15/08/2026), voir
   `scripts/npc_julien_zone2.gd` et `scripts/fragments_puzzle.gd`.
   - **Julien**, un second assistant du Pr Chen distinct de Camille (lui
     plutôt tourné vers les ruines/fossiles que vers les Pokémon vivants), se
     présente puis remet le **vélo** (pause réservée au son d'objet obtenu,
     même pattern que le Pokédex chez Camille) : moyen de transport
     écologique, utile vu la taille de la région.
   - Julien présente ensuite le puzzle comme un aperçu volontairement simple
     du métier de Chercheur (des missions bien plus complexes existent, mais
     celle-ci lui sert justement d'introduction pour le joueur pendant que
     lui s'occupe d'autre chose) : des fragments de pierre gravés, ramenés de
     ruines (hors du parc), qu'il n'a pas réussi à remettre dans l'ordre
     seul.
   - À la conversation suivante, Julien propose explicitement de s'y mettre
     (choix Oui/Non) avant de lancer le puzzle — pas d'enchaînement
     automatique dès la première conversation.
   - **Puzzle** : grille 4x5 (20 fragments), les 4 cases du haut forment le
     nom "PTERA", les 16 du dessous la silhouette gravée (généré depuis
     `assets/pokemon/aerodactyl/front.png`, voir
     `assets/ui/julien_fragments_sheet.png`). Mécanique par sélection/échange
     façon puzzle Zarbi d'Or/Argent (pas de glisser-déposer, cohérent avec le
     reste du jeu, entièrement clavier/manette) : toutes les cases sont
     occupées dès le départ, donc un fragment mal placé peut toujours être
     resélectionné et redéplacé, sans pénalité. Sortie possible à tout moment
     (Échap), progression sauvegardée (`PlayerData.julien_fragments_order`)
     pour reprendre plus tard.
   - À la résolution : petite animation de succès (pulsation en cascade des
     fragments) puis fondu, retour automatique à la conversation avec Julien
     qui enchaîne directement sur la révélation, sans repasser par le
     joueur : *"Un genre de grand reptile ailé... On dirait bien qu'on peut
     l'appeler Ptéra."*
   - Pas de récompense objet à ce stade (le vélo couvre déjà la récompense de
     zone 2) : ce moment reste narratif, et plante une graine claire pour une
     future quête liée à un vrai fossile/Ambre Ancien (asset
     `aerodactyl_fossil.png` déjà présent dans le pipeline, pas encore
     utilisé).

4. Julien (ou Camille, ❓ à trancher selon qui le joueur voit en dernier)
   redirige vers Yohan : *"Si tu veux voir l'autre facette, il est du côté de
   [zone]."*

5. **Yohan — action 1 : combat stratégique météo** (zone ❓)
   - Repris de `tutorial-competiteur.md` (dialogues en brouillon, jugés à
     retravailler) : prêt de 3 Pokémon, combat contre un dresseur, un
     changement météo en cours de combat pousse à adapter sa stratégie.
     Doit inclure la règle "objets interdits en combat officiel" (portée par
     Yohan ou par le dresseur adverse — ❓ non tranché).
     - 🎓 **Moment pédagogique** : bases du combat (types, effets météo)
       enseignées naturellement par le déroulé du combat lui-même.
   - Récompense : **5 Répulsifs** (décidé le 13/07/2026) ✅ câblé en test —
     voir section "Objets clés récupérés" plus bas pour le détail.

6. **Yohan — action 2 : combat duo révélé** (même zone ou zone ❓)
   - Repris de `tutorial-competiteur.md` : nouvelle équipe prêtée par Yohan
     (plus de passage par Camille entre les deux, contrairement au brouillon
     original), révélation du format duo seulement au lancement du combat.
     Précision de mécanique : combat "duo solo" — 2 Pokémon envoyés
     simultanément par le joueur, ciblage à choisir à chaque action, pas de
     coéquipier IA.
   - Récompense : **objet de Surf**.
     - 🎓 **Moment pédagogique** : Yohan explique ce que l'objet permet de
       faire (franchir l'eau) — démo pratique complète pas obligatoire ici,
       peut attendre la première vraie traversée d'eau hors du parc (acte 2)
       si le Parc Safari n'a pas de zone d'eau adaptée.

7. **Anselme réapparaît en personne dans le parc** (résout le ❓ posé plus
   haut : c'est bien lui, pas Yohan) et remet les 30 Safari Balls à ce
   moment précis (`PARK_HANDOFF`, voir `scripts/npc_worker_m.gd`) : *"Tu as
   vu les deux facettes, maintenant. Voilà 30 Safari Balls : à partir de
   maintenant, les Pokémon sauvages vont enfin se montrer dans les hautes
   herbes."* + rappel des règles de capture (Pokémon de base uniquement,
   retour forcé à l'entrée si 0 ball, capture multiple puis choix du
   partenaire) + *"Bon, je te laisse. À tout à l'heure !"* → il repart, les
   Pokémon deviennent disponibles dans les hautes herbes à partir de là.
   → capture libre (mécanique existante, 4 sous-zones ouvertes).
   - ✅ **Câblé en test bout en bout (13/07/2026)**, voir
     `scripts/npc_anselme_park.gd` : posé dans `safari_secret_house` (la
     maison secrète de la zone 4, atteignable depuis `safari_zone_west`,
     jusque-là vide de tout PNJ), conditionné à `PlayerData.has_surf` plutôt
     qu'à un vrai flag de complétion des 2 tutos (placeholder simple en
     attendant le contenu réel des zones 2/3). Donne la canne à pêche et
     débloque `SafariState.hunting_unlocked` ; les 30 Safari Balls restent
     données par `SafariState.enter()` comme avant (déjà 30 à ce stade,
     jamais entamées puisqu'aucune rencontre n'était possible avant). À
     déplacer/retravailler une fois la vraie condition de complétion des
     tutos posée.

8. Retour au bâtiment → choix du partenaire (inchangé) → choix de classe
   avec Louise (inchangé) → à ce moment, **le rival et l'allié·e sont déjà
   présents dans le bâtiment** : Anselme explique qu'ils viennent eux aussi
   de choisir leur classe et d'attraper leur premier Pokémon (parcours
   parallèle, pas montré à l'écran). Voir `scenario.md` pour leur
   description complète.

9. Avant de sortir vers Kanto, Anselme (ou un PNJ à définir) remet la
   **carte de Kanto** — seulement utile une fois dehors, donc logique de la
   donner en tout dernier. Départ vers Bourg Palette. **Fin de l'acte 1.**
   - 🎓 **Moment pédagogique** : dernier rappel de sauvegarde avant de
     partir dans le monde ouvert.

---

## Objets clés récupérés pendant l'acte 1

Le sac n'en fait plus partie : le joueur l'a déjà en arrivant à Kanto, pas
besoin de le remettre en scène (décidé 12/07/2026).

**Mis à jour le 13/07/2026** suite au passage à un PNJ par zone (voir
`scenario.md`/session du 12-13/07) — chaque objet est maintenant remis à
l'issue de la conversation dans la maison de repos correspondante, dialogues
encore placeholder ("Pouet.") sauf zone 1 :

1. 30 Safari Balls (Anselme, dans le parc, après les 2 tutos — `PARK_HANDOFF`) ✅ câblé en test (voir point 7 ci-dessus), toujours données via `SafariState.enter()` en pratique
2. Pokédex (Camille, **zone 1**) ✅ implémenté, dialogue validé — plus dans le sac tant que non reçu
3. Canne à pêche — **retirée de la zone 2** (décidé 13/07/2026 : inutile tant
   que la capture n'est pas débloquée). Remise par Anselme en même temps que
   le déblocage des rencontres sauvages (`PARK_HANDOFF`) ✅ câblé en test
   (voir point 7 ci-dessus). La mécanique de pêche elle-même est prête côté
   code (`scripts/player.gd`), avec une vraie animation (lancer de ligne,
   attente, touche, rangement de la canne) ✅ ajoutée le 13/07/2026, sprites
   réels FRLG `red_fish.png`/`green_fish.png` (red_normal/green_normal
   seulement, comme Surf/Vélo).
4. **Zone 3 (Yohan) : 5 Répulsifs**, décidé le 13/07/2026 ✅ câblé en test
   (`PlayerData.repel_count`/`repel_steps_remaining`, voir
   `scripts/npc_yohan_zone3.gd`) — un seul palier (pas de Super/Max
   Répulsif), utilisable depuis la poche "Objets" du sac. Suppression
   d'encontre simplifiée (pas de comparaison de niveau avec l'équipe : le
   joueur n'a encore aucun Pokémon à ce stade), 100 pas de durée. Utile dès
   maintenant dans le Parc Safari (seul endroit avec des rencontres
   sauvages pour l'instant), et réutilisable plus tard une fois les
   rencontres overworld implémentées.
5. Objet de Surf (Yohan, **zone 4**) ✅ implémenté (mécanique de Surf fonctionnelle, dialogue encore placeholder)
6. **Vélo (zone 2, Julien)** — décidé le 13/07/2026 ✅ câblé en test
   (`PlayerData.has_bike`/`is_biking`, voir `scripts/npc_julien_zone2.gd`) :
   remplace la canne à pêche comme récompense de zone 2 (qui a migré chez
   Anselme, voir point 3). Utile aux deux classes pour se déplacer plus vite
   (x2, `BIKE_SPEED` dans `scripts/player.gd`). Se monte/descend depuis la
   poche "Objets Rares" du sac (bascule, pas de confirmation). Descend
   automatiquement en entrant dans un bâtiment/une grotte (même logique que
   le Surf sur terre ferme) — pas de vélo en intérieur. Sprites réels FRLG
   (`red_bike.png`/`green_bike.png`, copiés depuis `kanto-pipeline/`)
   seulement pour red_normal/green_normal, comme le Surf ; layout des poses
   pas encore vérifié visuellement en jeu, à ajuster si besoin.
7. Carte de Kanto (Anselme, à la sortie du bâtiment) — pas encore câblée

## Le Minidraco chromatique — fil narratif Chercheur

Trouvé et capturé (action 1) mais aussitôt repris par Camille pour étudier
au labo — le joueur ne le garde pas. Sème une graine thématique sur les
chromatiques (pourquoi ils existent visuellement différents, ont-ils
d'autres caractéristiques propres) qui peut nourrir des quêtes de recherche
en acte 2-3. Paiement narratif prévu en acte 4 (arc Chercheur) : ce même
individu, évolué en Draco ou Dracolosse chromatique, redevient rencontrable
et **capturable** cette fois. ❓ Fil équivalent côté Compétiteur pas encore
défini (piste : un adversaire remarquable croisé pendant le combat en duo de
Yohan, retrouvé à la Ligue en acte 4).

## Moments pédagogiques (mécaniques expliquées en jeu)

Listés dans l'ordre où ils apparaissent pendant l'acte, pour vérifier qu'on
couvre tout sans doublon ni oubli :

1. Sauvegarde (menu pause) — Anselme, avant d'entrer dans le parc (beat 3a).
2. Pas de Pokémon sauvage sans Safari Ball — Anselme, même moment (beat 3a).
3. Pokédex, usage de base — Camille, en le remettant (action 1).
4. Capture (appât/pierre) — Camille, pendant la capture du Minidraco
   (action 1).
5. Métier de Chercheur, autre facette (ruines/fossiles, pas seulement le
   terrain) — Julien, en présentant le puzzle des fragments (action 2).
7. Combat, bases (types, météo, ciblage duo) — Yohan, pendant les 2 combats
   (actions 1 et 2).
8. Objet de Surf, à quoi ça sert — Yohan, en le remettant (action 2) ; démo
   pratique complète possiblement différée à l'acte 2.
9. Règles des Safari Balls (base uniquement, retour forcé, capture multiple
   puis choix du partenaire) — Anselme, dans le parc, après les 2 tutos
   (beat 3b / `PARK_HANDOFF`).
10. Rappel de sauvegarde avant de quitter le bâtiment — Anselme, juste avant
    le départ vers Bourg Palette.

## Le Pokédex — spécificité de ce jeu

Rappel narratif (mécanique consolidée à ajouter dans `game-design.md`) :
contrairement aux jeux originaux, le Pokédex contient déjà toutes les
espèces de Kanto (hors légendaires) dès le départ — mais les entrées des
espèces rares restent incomplètes tant qu'elles n'ont pas été suffisamment
étudiées. Le contenu affiché diffère aussi selon la classe : données
orientées combat/stratégie pour le Compétiteur, données approfondies
(mesures, comportement, nécessite parfois plusieurs captures de la même
espèce pour compléter une entrée) pour le Chercheur.

---

## Dialogues déjà écrits (repris de `tutorial-competiteur.md`)

Voir ce fichier pour le détail — conservés tels quels pour l'instant,
adaptés au besoin une fois les combats implémentables (ne pas dupliquer ici
tant qu'ils n'ont pas été retravaillés).

## Questions ouvertes / à trancher

- **Anselme/`PARK_HANDOFF`** : câblé en test (13/07/2026) dans
  `safari_secret_house`, condition = `PlayerData.has_surf`. À terme, il
  faudra conditionner son apparition/dialogue à un vrai flag de complétion
  des 2 tutos plutôt qu'à la possession du Surf (qui n'est qu'un proxy).
- Assignation précise des zones (1/2/3/4 du Parc Safari) une fois la vraie
  carte sous les yeux — actuellement des placeholders dans ce document.
- Dialogues détaillés des 2 combats Compétiteur — brouillons existants jugés
  faibles (voir `tutorial-competiteur.md`), à retravailler, dépend aussi du
  système de combat en cours de développement par l'ami de Gus.
- Fil narratif équivalent au Minidraco chromatique côté Compétiteur — à
  imaginer.
- Qui remet la carte de Kanto exactement (Anselme pressenti, à valider).
- Sprite propre pour Julien (actuellement `scientist`, comme Camille) — à
  envisager pour les différencier visuellement.
- Vraie quête de résurrection de fossile (Ambre Ancien → Ptéra) évoquée en
  graine narrative par le puzzle des fragments — à concevoir plus tard,
  emplacement dans le scénario pas encore décidé.
- Ligne de transition finale avant de quitter le bâtiment vers Bourg
  Palette.
- Répartition des captures pouvant apparaître pendant la session libre
  (roster Safari déjà codé dans `scripts/safari_roster.gd`, sans lien direct
  avec ce document).
