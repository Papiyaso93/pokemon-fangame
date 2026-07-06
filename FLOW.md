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
  `scripts/pause_menu.gd`) : Sauvegarder / Reprendre. "Sauvegarder" ouvre
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

- Écran noir, dialogue d'ouverture ✅
- Renseigner son nom (max 7 caractères, fidèle FRLG) ✅
- Choisir son sexe ✅
- Choisir son apparence ✅ — actuellement **4 sprites prédéfinis** (2 par
  genre : Red/Brendan pour homme, Green/May pour femme), pas de personnalisation
  fine
  - ❓ Garder ce choix limité (fidèle FRLG) ou permettre une
    hyper-personnalisation (couleur de peau, cheveux, tenue...) ? Impact
    important sur le travail de sprite à prévoir si on part sur la 2e option.

Fichiers : `scripts/character_creation.gd` + `scenes/ui/character_creation.tscn`,
`scripts/player_data.gd` (autoload `PlayerData`).

---

## 4. Intro narrative — bâtiment Zone Safari ✅

- Le joueur spawn dans `safari_entrance` ✅
- `worker_f` engage automatiquement la conversation : confirmation → explication
  des 2 classes (Compétiteur/Chercheur) → choix, avec boucle "peux-tu répéter ?"
  et rappel "Chercheur indisponible" (Chercheur = v2, cf. `game-design.md`) ✅
- Les sorties du bâtiment restent verrouillées tant que `worker_m` n'a pas été vu ✅
- `worker_m` explique les règles du Parc Safari (30 Safari Balls, capture libre,
  retour pour choisir le partenaire, retour auto si 0 ball) ✅

Fichiers : `scripts/npc_worker_f.gd`, `scripts/npc_worker_m.gd`,
`scripts/safari_entrance_gate.gd`.

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
