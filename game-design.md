# Game Design — Pokémon Fangame

## Vue d'ensemble

Fan-game Pokémon basé sur la région de Kanto. Le joueur a 18 ans et doit choisir sa voie professionnelle. L'histoire et les mécaniques varient selon la classe choisie et les choix moraux effectués en cours de partie.

---

## Les classes

### 2 classes de base

- **Compétiteur** — vit de la compétition Pokémon comme un sportif de haut niveau
- **Chercheur** — travaille sur le terrain pour le labo du Pr. Chen

### Le pivot criminel

À un moment clé de l'histoire, le joueur peut choisir de rejoindre la Team Rocket. Il conserve sa classe de base et gagne en plus la classe **Criminel**. L'objectif devient alors de gravir les échelons de la Team Rocket pour en devenir le boss.

### 4 scénarios résultants

1. Compétiteur (chemin droit) → devenir champion de la Ligue
2. Chercheur (chemin droit) → compléter ses recherches et explorer tout Kanto
3. Compétiteur + Criminel → contrôler la scène compétitive pour la Team Rocket
4. Chercheur + Criminel → mener des recherches illégales pour la Team Rocket

---

## Mécaniques par classe

### Combat

| Axe | Compétiteur | Chercheur |
|-----|-------------|-----------|
| Slots Pokémon | 6 slots | 3 slots (l'appareil de terrain prend les 3 autres) |
| Capture | Nécessite au moins 1 slot libre | Toujours possible — si équipe pleine, envoi automatique au PC |
| Gestion de l'équipe | Centre Pokémon uniquement | N'importe où via l'appareil de terrain |
| Objets en combat | Objets équipés autorisés, utilisation pendant le combat interdite (contre PNJ) — libre contre Pokémon sauvages | Tous les objets autorisés en toutes circonstances |
| Format de combat | Solo ou duo selon les arènes | Solo uniquement |
| Objectif arènes | Progresser vers la grande compétition | Débloquer l'accès à des zones dangereuses ou protégées |

### Économie

| Axe | Compétiteur | Chercheur |
|-----|-------------|-----------|
| Revenu principal | Matchs officiels (arènes, compétitions, PNJ forts) | Quêtes de recherche — rémunération par batch selon rareté du Pokémon |

**Quêtes secondaires (communes aux 2 classes)**
- 1 à 2 par jour, faible récompense, générées aléatoirement
- Types différents selon la classe
- Se débloquent après la quête principale de zone

**Centre Pokémon**
- Payant pour tout le monde
- Exception chemin Criminel — à confirmer plus tard

### Accès au monde

| Zone | Compétiteur | Chercheur |
|------|-------------|-----------|
| Arènes | ✓ | ✓ |
| Compétitions & Ligue | ✓ | ✗ |
| Zones protégées, labos, ruines | ✗ | ✓ |

---

## Le Pokédex

Remis à tout le monde pendant l'acte 1 (Parc Safari), quelle que soit la
classe finalement choisie — voir `acte1-parc-safari.md` pour le moment
narratif exact.

- Contrairement aux jeux originaux, **toutes les espèces de Kanto sont déjà
  répertoriées dès le départ** (hors légendaires) — pas de dex à remplir
  espèce par espèce.
- Les entrées des espèces **rares restent incomplètes** tant qu'elles n'ont
  pas été suffisamment étudiées/rencontrées.
- Le contenu affiché diffère selon la classe :
  - **Compétiteur** : données orientées combat/stratégie (types, capacités,
    matchups).
  - **Chercheur** : données approfondies (mesures, comportement) — certaines
    entrées nécessitent plusieurs captures de la **même** espèce pour se
    compléter (ex. taille moyenne réelle de l'espèce).

❓ Détail technique de "l'incomplétude" par rareté et du système de capture
répétée pour le Chercheur — à définir au moment de l'implémentation.

---

## Le pivot criminel

### Déclenchement
- Choix unique à un moment clé de l'histoire (irréversible)
- Le joueur conserve toutes les mécaniques de sa classe de base

### Avantages Criminel
- Peut voler des Pokémon ou de l'argent à d'autres personnages
- Peut corrompre ou combattre un garde pour accéder à une zone interdite
- Peut utiliser des objets secrètement en combat officiel
- Accès à des objets illégaux introuvables ailleurs
- Peut intimider des PNJ pour obtenir des informations

### Compensation difficulté
- Les adversaires ont N niveaux de plus quand le joueur est Criminel (valeur à définir)

---

## Ordre de développement

1. Compétiteur chemin droit (v1)
2. Chercheur chemin droit (v2)
3. Pivot Criminel pour les deux classes (v3)

---

## Conventions d'écriture

- **Dialogues neutres en genre** : le joueur choisit son genre à la création de
  personnage (`PlayerData.gender`), mais rien dans le système de dialogue ne
  gère encore les accords ("tenté"/"tentée", etc.). En attendant un éventuel
  helper technique pour gérer ça proprement, **toujours privilégier une
  formulation qui évite l'accord** plutôt qu'un adjectif genré (ex. "envie de
  tester ?" plutôt que "tenté(e) ?"). Vaut pour tout nouveau dialogue écrit
  dans le jeu, pas seulement les tutoriels de classe.

---

## À confirmer plus tard

- Valeur exacte du malus de niveaux pour le chemin Criminel
- Centre Pokémon et le chemin Criminel (gratuit ?)
- Échelle des prix et de la rémunération
- Moment exact du pivot criminel dans l'histoire
- Détail des quêtes secondaires par classe
