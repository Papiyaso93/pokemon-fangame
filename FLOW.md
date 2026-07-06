# FLOW.md — Parcours joueur & suivi des specs

## À quoi sert ce document

Différent de `HANDOFF.md` (compte-rendu technique de session, destiné à l'agent IA
pour reprendre le travail). **Celui-ci décrit ce que le JOUEUR vit, écran par
écran** — un storyboard fonctionnel qui sert à la fois de script de jeu et de
suivi d'avancement. Il répond à trois questions à tout moment :
- Qu'est-ce qui est fait et vérifié en jeu ?
- Qu'est-ce qu'il reste à faire ?
- Quelles décisions de game design sont encore ouvertes ?

À tenir à jour après chaque fonctionnalité livrée — pas seulement dans
`HANDOFF.md`, qui reste le contexte technique d'une session à l'autre.

**Précision de Gus (06/07/2026)** : ce document doit vraiment servir de
**scénario global** du jeu, pas juste d'une liste de statuts. Chaque section
doit pouvoir se lire comme le déroulé réel vécu par le joueur (avec les
dialogues quand ils existent), pour que Gus et son ami puissent suivre
l'histoire dans son ensemble et où on en est, pas juste cocher des cases.

## Légende

- ✅ Fait et vérifié en jeu
- 🚧 Partiellement fait / placeholder
- ❌ Pas fait du tout
- ❓ Décision de game design à prendre (ne pas improviser seul — cf. règle du projet)

---

## 1. Démarrage du jeu — écran titre ✅ (mécanique) / 🚧 (habillage)

`project.godot` démarre maintenant sur `scenes/ui/title_screen.tscn`. Écran
minimal (fond uni + fenêtre `std_window.png`), propose **Nouvelle partie** /
**Charger une partie** / **Tests**.
- ✅ Nouvelle partie → prend silencieusement le premier slot libre et va
  directement à `scenes/intro/intro.tscn`, sans passer par l'écran de slots
  (simplifié à la demande de Gus : pas besoin de choisir un slot pour
  commencer). L'écran de slots ne s'affiche que si les 3 sont déjà pris, pour
  en libérer un avant de pouvoir continuer.
- ✅ Charger une partie → écran de sélection de slot → choix d'un slot rempli →
  charge la sauvegarde
- 🚧 Tests : bouton présent mais **ne fait rien pour l'instant** — décision
  reportée (tranché avec Gus : on définira sa fonction plus tard)
- 🚧 Pas d'habillage visuel (logo, artwork) — écran fonctionnel seulement

Fichiers : `scripts/title_screen.gd` + `scenes/ui/title_screen.tscn`.

---

## 2. Charger une partie ✅ (mécanique) / 🚧 (contenu sauvegardé)

Système de sauvegarde en place (tranché avec Gus le 06/07/2026) :
- ✅ **3 slots** (`scripts/save_manager.gd`, autoload `SaveManager`), un fichier
  JSON par slot dans `user://saves/slot_N.json`
- ✅ Écran de sélection de slot partagé entre Nouvelle partie/Charger une
  partie/Sauvegarder (`scripts/save_slots.gd` + `scenes/ui/save_slots.tscn`) :
  slot vide non cliquable en mode "charger", slot rempli non cliquable en
  mode "nouvelle partie" (il faut le supprimer d'abord), **tous les slots
  cliquables en mode "sauvegarder"** ; affiche nom du perso, carte actuelle
  (nom FR), temps de jeu (format `H:MM`) ; bouton supprimer sur chaque slot
  rempli ; bouton "Revenir".
- ✅ **Sauvegarde manuelle** via un mini-menu pause (touche `ui_cancel`/Échap,
  `scripts/pause_menu.gd`) : Reprendre / Sauvegarder / Quitter (ordre fixé le 06/07/2026).
  "Quitter" ramène à l'écran-titre (fondu noir, pas de sauvegarde automatique). "Sauvegarder" ouvre
  l'écran de slots pour que le joueur **choisisse délibérément** où
  sauvegarder — écraser une partie existante ou en garder une de côté en
  utilisant un slot différent (demandé par Gus, plus besoin d'écraser
  silencieusement le slot de la partie en cours). Pas de sauvegarde
  automatique (tranché avec Gus) — le vrai menu Start (Pokédex/Sac/Options/...)
  viendra plus tard, au fur et à mesure que ces systèmes existeront.
- ✅ **Sauvegarde autorisée n'importe où**, y compris en pleine visite de la
  Zone Safari (balls restantes + captures en cours incluses dans la
  sauvegarde) — fidèle FRLG (le seul vrai blocage dans le jeu original est
  pendant un combat, pas la Zone Safari)
- ✅ Le joueur réapparaît exactement là où il a sauvegardé, y compris quand
  cet endroit était sous une carte voisine chargée en recouvrement seamless
  (la sauvegarde capture la **zone effective** sous ses pieds, pas juste la
  scène `.tscn` chargée)
- 🚧 **Contenu sauvegardé aujourd'hui** : uniquement ce qui existe déjà dans le
  jeu (`PlayerData` complet, position/carte, orientation, état Zone Safari,
  temps de jeu). Pas d'équipe Pokémon/inventaire/quêtes/Pokédex — ces systèmes
  n'existent pas encore (section 6), à ajouter au format de sauvegarde au fur
  et à mesure qu'ils seront construits.

Voir `HANDOFF.md` pour le détail technique (format JSON, points d'intégration).

---

## 3. Nouvelle partie — création de personnage ✅ (mécanique) / ❓ (portée)

Écran noir (fond de `intro.tscn`), 3 questions dans l'ordre **nom → genre → apparence**
(réordonné le 06/07/2026 à la demande de Gus, avant c'était genre → nom → apparence). Chaque
question suit le même principe que le reste du jeu : posée dans une boîte de dialogue classique
tenue ouverte, puis une fenêtre dédiée pour la réponse à côté (`scripts/character_creation.gd`
n'a plus aucun visuel propre, juste un orchestrateur qui enchaîne les 3 étapes).

- Renseigner son nom (max 12 caractères — le vrai jeu limite à 7 par contrainte GBA, pas
  pertinent sur PC) ✅ — saisie via un champ de texte
  (`scenes/ui/name_entry.tscn`) dans une fenêtre `std_window.png`, pas le clavier virtuel du
  vrai jeu (compromis assumé, voir HANDOFF.md)
- Choisir son sexe ✅ — vraie fenêtre de choix (`scenes/ui/gender_choice.tscn`, Garçon/Fille)
- Choisir son apparence ✅ — fenêtre de choix avec les 2 aperçus cliquables
  (`scenes/ui/appearance_choice.tscn`), actuellement **4 sprites prédéfinis** (2 par genre :
  Red/Brendan pour homme, Green/May pour femme), pas de personnalisation fine
  - ❓ Garder ce choix limité (fidèle FRLG) ou permettre une
    hyper-personnalisation (couleur de peau, cheveux, tenue...) ? Impact
    important sur le travail de sprite à prévoir si on part sur la 2e option.

Fichiers : `scripts/character_creation.gd` (orchestrateur), `scenes/ui/name_entry.tscn`,
`scenes/ui/gender_choice.tscn`, `scenes/ui/appearance_choice.tscn`,
`scripts/player_data.gd` (autoload `PlayerData`).

---

## 4. Intro narrative — bâtiment Zone Safari ✅

Scénario complet (tranché avec Gus et son ami le 06/07/2026), avec les dialogues
réels — cette section fait référence pour tout le début du jeu, à garder
synchronisée avec le texte réellement en jeu à chaque ajustement.

**Personnages** : **Louise** (accueil de Kanto, script `npc_worker_f.gd`,
node `worker_f`) et **Anselme** (détail des classes + Parc Safari, script
`npc_worker_m.gd`, node `worker_m`), tous deux dans `safari_entrance`. Le
spawn ne change pas (toujours dans ce bâtiment, tout le monde reste à la même
place).

### Déroulé

1. **Écran noir (Louise, hors-champ)** : "Bienvenue à Kanto !" →
   "Tu n'es pas la première personne à débarquer ici les mains vides et
   pleine d'espoir. Et tu seras loin d'être la dernière." → "Mais avant de
   rêver, on fait les choses dans l'ordre : dis-moi qui tu es." → formulaire
   (= création de personnage, section 3) → spawn direct dans le bâtiment,
   sans phrase de transition.
2. **Louise (suite, à l'arrivée)** : "Bien, [Nom]. C'est noté. Passons aux
   choses sérieuses : qu'est-ce que tu comptes faire de ta vie, ici ?" →
   évoque les 2 classes (Compétiteur/Chercheur) **sans demander de choisir**
   → renvoie vers Anselme pour le détail.
3. **Anselme (présentation)** : détaille les 2 classes (avec l'insistance sur
   le fait que rien n'est gratuit à Kanto, il faut gagner sa vie), annonce les
   2 PNJ optionnels du Parc Safari (compétiteur aguerri + assistant du
   Pr Chen, pour un aperçu de chaque voie, sans interaction pour l'instant),
   donne 30 Safari Balls et explique le système de capture (Pokémon de base
   uniquement, retour libre ou forcé si 0 ball). Débloque la porte nord.
4. **Verrou des portes** (`safari_entrance_gate.gd`) :
   - Avant d'avoir parlé à Anselme : portes nord **et** sud bloquées, Louise
     interpelle (petit point d'exclamation au-dessus du joueur).
   - Après Anselme, avant d'avoir un partenaire : seule la porte sud reste
     bloquée ("Ton premier partenaire t'attend !").
5. **Parc Safari** : 2 PNJ optionnels (compétiteur aguerri, assistant du
   Pr Chen) placés devant le bâtiment d'entrée, pas d'interaction pour
   l'instant (prévu pour plus tard, une fois le système de combat de l'ami de
   Gus disponible). Capture libre inchangée (section 5).
6. **Retour au bâtiment** :
   - **Volontaire** (il reste des Safari Balls) : Anselme demande "Alors, tu
     as fini d'explorer le parc ?" → Oui/Non. Oui → enchaîne sur le choix du
     partenaire. Non → le joueur se retourne et repart automatiquement dans
     le parc (sa session ne change pas).
   - **Forcé** (0 Safari Ball) : message en combat ("Il ne te reste plus
     aucune Safari Ball !"), combat interrompu net (plus de tour appât/
     pierre), message de retour, transition, spawn dans le bâtiment, direct
     sur le choix du partenaire (même comportement que "Oui" ci-dessus).
7. **Choix du partenaire** (inchangé, section 5) : 0 capture → Rattata offert.
   ≥ 1 capture → choix parmi les captures.
8. **Louise (final)** : enchaîne directement après le choix du partenaire
   ("Alors, cette fois c'est décidé ?") → vrai choix de classe (menu
   Compétiteur/Chercheur, "Chercheur indisponible" avec la blague Grodolphe
   déjà établie).
   - ❓ Une fois la classe choisie, faut-il aussi bloquer la porte sud tant
     que ce choix n'est pas fait (actuellement non — la porte sud se
     débloque dès qu'un partenaire est choisi, avant même de reparler à
     Louise) ? Décision reportée avec Gus.

Fichiers : `scripts/intro.gd`, `scripts/npc_worker_f.gd`, `scripts/npc_worker_m.gd`,
`scripts/safari_entrance_gate.gd`, `scenes/ui/yes_no_choice.tscn` (nouveau,
petit choix Oui/Non réutilisable).

---

## 5. Zone Safari — capture du partenaire ✅ (mécanique) / ❓ (contenu)

- Marche dans les hautes herbes → rencontre aléatoire (10 % de chance par pas) ✅
- Transition d'écran (rideau) → écran de capture fidèle au vrai jeu (fond,
  boîte de stats, plateformes, appât/pierre, formule de capture à 4 secousses) ✅
- Retour à l'entrée (volontaire ou forcé si 0 Safari Ball) ✅
- Choix du partenaire parmi les captures de la session (ou Rattata de secours
  si bredouille) ✅ → remplit `PlayerData.starter_species`
  - ❓ **Roster réel de la Zone Safari** : actuellement un seul Rattata
    placeholder (niveau 5 fixe). Le vrai roster (bébés Pokémon 1ère génération,
    taux d'apparition/capture par sous-zone) reste à définir avec l'ami de Gus
    — voir `HANDOFF.md` pour le détail technique.

- Positionnement de l'écran de capture (sprites, cartes d'infos, fenêtre d'action séparée du
  message) recalé sur les vraies coordonnées FRLG le 06/07/2026 — voir `HANDOFF.md` pour le
  détail, à valider visuellement par Gus.

Fichiers : `scripts/encounter.gd`, `scripts/safari_state.gd`,
`scripts/partner_choice.gd`.

---

## 6. Suite du jeu — monde ouvert Kanto ❌

Techniquement, le monde extérieur de Kanto est généré et navigable (12 villes,
31 routes, 5 grottes génériques — voir `HANDOFF.md`), mais **aucun scénario, PNJ
ou quête n'existe après la Zone Safari**. Tout le reste est à construire :

- ✅ **Transitions fluides entre cartes connectées** (pas d'écran noir en passant d'une carte à
  une autre directement reliée) + **bandeau du nom de lieu** en français à chaque changement de
  carte, style fidèle au vrai jeu. Étendu à **tout Kanto extérieur** (plus seulement Bourg
  Palette ↔ Route 1) : 37 zones se chargent en continu autour du joueur, quel que soit son point
  de départ. Seules les cartes qui ne s'atteignent pas par un bord dans le vrai jeu (Safrania via
  ses portes, Forêt de Jade et les 4 sous-zones de la Zone Safari via leurs warps internes)
  restent en téléportation classique — comportement fidèle, pas une lacune. Voir `HANDOFF.md`
  pour le détail technique.

- ✅ Système de sauvegarde (voir section 2) — couvre tout ce qui existe
  aujourd'hui ; à étendre au fur et à mesure des systèmes ci-dessous
- ❌ Équipe Pokémon (party) : affichage, soin, échange d'ordre
- ❌ Centre Pokémon
- ❌ Boutiques / objets / sac
- ❌ Combats dresseurs (le seul "combat" existant est la capture Safari, pas un
  vrai combat Pokémon contre Pokémon)
- ❌ Arènes / Ligue (chemin Compétiteur)
- ❌ Quêtes de recherche (chemin Chercheur, v2)
- ❌ Pokédex
- ❌ Pivot Criminel (v3, cf. `game-design.md`)

Cette section sera complétée au fur et à mesure des sessions futures, au même
niveau de détail que les sections précédentes, dès qu'un chantier est abordé.

---

## Comment on tient ce document à jour

- Une fonctionnalité livrée et testée → passer son statut à ✅ ici (pas
  seulement documenter dans `HANDOFF.md`)
- Une décision ❓ tranchée avec Gus/son ami → remplacer le ❓ par le choix fait,
  garder une trace de l'ancienne question si utile
- Une nouvelle étape du parcours joueur qui apparaît (nouveau bâtiment,
  mécanique, écran) → l'ajouter ici en suivant le même format que les sections
  existantes
