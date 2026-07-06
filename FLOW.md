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

## 1. Démarrage du jeu — écran titre ❌

**Rien n'existe aujourd'hui** : le jeu démarre directement sur
`scenes/intro/intro.tscn` (écran noir + dialogue), sans aucun écran titre.
`project.godot` a `run/main_scene` codé en dur sur cette scène.

**Spec cible :**
- Le jeu s'allume
- Un écran propose : **Nouvelle partie** / **Charger une partie** / **Tests**
  (temporaire, pour faciliter la recette)
  - ❓ Le mode "Tests" doit-il être retiré/masqué dans une build finale, ou
    juste laissé de côté et ignoré par les joueurs ? À trancher le moment venu.

---

## 2. Charger une partie ❌

**Rien n'existe aujourd'hui** : aucun système de sauvegarde (ni fichier, ni
sérialisation de l'état du joueur/monde, ni temps de jeu). Gros chantier à part
entière, pas juste un écran UI.

**Spec cible :**
- Affiche tous les slots disponibles
  - ❓ Nombre de slots : entre 3 et 5, à trancher
- Par slot rempli, afficher : nombre d'heures jouées, map actuelle du joueur
- Slot vide → rien de cliquable
- Bouton "Revenir" → retour à l'écran titre
- Clic sur un slot rempli → charge la partie, le joueur apparaît exactement là
  où était sa dernière sauvegarde
- Bouton supprimer (icône corbeille) à côté de chaque slot rempli, pour
  libérer la place

**Prérequis technique à concevoir avant l'UI elle-même :**
- Format de sauvegarde (quelles données : position/map, temps de jeu, équipe
  Pokémon, PlayerData, inventaire, quêtes en cours, état du monde...)
- Quand déclencher une sauvegarde (auto ? manuelle ? les deux ?)

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
  carte, style fidèle au vrai jeu. Testé et validé sur Bourg Palette ↔ Route 1 uniquement pour
  l'instant — le reste de Kanto utilise encore l'ancien système de téléportation (pas de
  régression, juste pas encore étendu). Voir `HANDOFF.md` pour le détail technique.

- ❌ Système de sauvegarde (voir section 2)
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
