# Handoff — Pokémon Fangame Godot 4.7

## Qui est l'utilisateur
Gus (guillaumecastro9@gmail.com, GitHub : Papiyaso93). Il fait le code avec l'aide d'un agent IA. Lui et un ami font le game design. Il parle français, préfère les réponses courtes et directes.

---

## Le projet

Fan-game Pokémon dans la région de Kanto, graphismes FireRed/LeafGreen (FRLG), joueur âgé de 18 ans avec un choix de classe (Compétiteur ou Chercheur), pivot criminel possible (Team Rocket). Voir `game-design.md` pour les détails narratifs.

**Stack :**
- Godot 4.7, GDScript
- `TileMapLayer` (Godot 4.7 — `TileMap` est déprécié, ne plus l'utiliser)
- Tileset principal : `assets/tilesets/outdoor_v2.png` — 128×9584px, tuiles 16×16, 8 cols × 599 rows
- Spritesheet joueur : `assets/characters/red_walk.png` — 48×128px, 3 frames × 4 directions, 16×32px par frame

---

## Structure du projet

```
pokemon-fangame/
├── assets/
│   ├── characters/red_walk.png       # spritesheet Red
│   ├── tilesets/outdoor_v2.png       # tileset principal
│   └── maps/reference/               # images de référence (à vérifier si existantes)
├── scenes/
│   ├── maps/pallet_town.tscn         # scène principale actuelle
│   └── player/player.tscn            # CharacterBody2D + AnimatedSprite2D
├── scripts/
│   ├── generate_pallet_town.gd       # EditorScript @tool — génère la map Bourg Palette
│   └── player.gd                     # déplacement case par case
└── game-design.md
```

---

## API Godot 4.7 à utiliser (IMPORTANT)

```gdscript
# Cibler le TileMapLayer (pas TileMap directement)
var layer = scene.get_node("TileMap/Layer0")  # TileMapLayer node

# Placer une tuile
layer.set_cell(Vector2i(col, row), source_id, atlas_coords)
# PAS layer.set_cell(layer_index, coords, ...)  ← ancienne API TileMap

# Effacer
layer.clear()
```

Les scripts de génération utilisent `@tool` + `extends EditorScript`, lancés via **Fichier → Exécuter** dans l'éditeur de script Godot.

---

## Tuiles connues dans outdoor_v2.png

| Nom | Atlas coords | Description |
|-----|-------------|-------------|
| GRASS | Vector2i(1, 1) | Herbe verte |
| TREE | Vector2i(5, 0) | Buisson/arbre rond |
| PATH | Vector2i(4, 32) | Chemin sableux |
| WATER | Vector2i(1, 52) | Eau bleue calme |
| FLOWER | Vector2i(4, 0) | Fleurs rouges |
| SIGN | Vector2i(2, 0) | Panneau |

**Note :** les bâtiments (maisons, labo) sont en placeholder herbe pour l'instant. Gus les placera manuellement avec le pinceau TileMap de Godot.

---

## État actuel — Bourg Palette

Le script `scripts/generate_pallet_town.gd` génère une map 20×20 avec :
- Chemin nord (sortie Route 1) en row 0
- Bordure d'arbres 2 tuiles d'épaisseur sur les 4 côtés
- Maisons placeholder rows 2-4
- Labo placeholder rows 7-10
- Fleurs rows 12-13, côté gauche
- Lac rows 14-16, côté gauche
- Chemin sud (mer / Route 21 plus tard) rows 18-19

**Pas encore fait :**
- Collisions (StaticBody2D ou TileSet collision layers)
- Caméra suivant le joueur
- Transitions entre maps (sortie nord → Route 1, etc.)
- Système de combat (responsabilité de l'ami de Gus)

---

## Prochaine grande étape : construire toutes les maps de Kanto

### Contexte
Kanto dans FRLG, c'est ~50-80 maps extérieures (villes, routes, grottes, îles) + des dizaines d'intérieurs (bâtiments, donjons). C'est un travail énorme si fait à la main.

### Stratégie recommandée (à évaluer)

**Option A — Récupérer des données fan existantes**
Des centaines de fans ont déjà cartographié Kanto en détail. Sources possibles :
- **Pokémon Essentials** (RPG Maker XP) — projet open-source, contient toutes les maps Kanto en format `.rxdata` ou `.json` exportable. Chercher sur GitHub `pokemon-essentials kanto maps`.
- **PokeAPI / Bulbapedia** — données de référence sur la géographie, dimensions, connexions entre zones.
- **Pret (pret/pokefirered)** — décompilation du ROM FireRed sur GitHub, contient les données de map en C/assembleur. Légalement ambigu mais techniquement précis.
- **Fan-made map exports** — chercher sur GitHub des projets comme `kanto-tilemap`, `firered-maps-csv`, etc. Certains ont déjà exporté les layouts en grille CSV ou JSON.

**Option B — Générer à partir de screenshots**
Prendre des screenshots de FRLG (émulateur) map par map et recréer le layout à la main dans le script de génération. Laborieux mais précis.

**Option C — Hybrid**
Récupérer les données de connexion et dimensions (tailles des routes) depuis des sources fan, puis reconstruire le layout tile par tile avec le script de génération en se basant sur les screenshots comme référence visuelle.

### Architecture système maps recommandée

Plutôt que des scripts `generate_xxx.gd` séparés pour chaque map, il vaut mieux :
1. Un fichier de données par map (JSON ou GDScript const) avec le layout en grille de caractères
2. Un seul script de génération générique `MapGenerator.gd` qui charge le fichier de données et peuple le TileMapLayer
3. Une scène template `map_template.tscn` réutilisable

Cela permettra d'avoir 80 maps sans 80 scripts différents.

### Questions à résoudre en premier
- Trouver une source de données fan fiable pour les layouts Kanto
- Définir le format de données (JSON ? GDScript const arrays ?)
- Décider si on utilise les mêmes tiles que FRLG ou si on adapte
- Gérer les transitions entre maps (Area2D en bord de map + chargement de scène)

---

## Player

- `CharacterBody2D` + `AnimatedSprite2D`, 8 animations (idle/walk × 4 directions)
- Déplacement case par case (tile-based), SPEED = 48 px/s, TILE_SIZE = 16
- Position initiale dans Bourg Palette : (160, 272)

---

## Remarques importantes

- Quand Godot détecte une modification de fichier externe, cliquer **"Recharger depuis le disque dur"**, puis relancer le script de génération, puis **Ctrl+S** pour sauvegarder la scène.
- Le warning `TileMap deprecated` dans la console est non-bloquant, ne pas essayer de le résoudre avec "Extraire les couches" (ça ne marche pas sur cette version).
- Ne jamais utiliser `tilemap.set_cell(layer_index, ...)` — utiliser uniquement `layer.set_cell(coords, source_id, atlas)` sur le nœud `TileMapLayer`.
