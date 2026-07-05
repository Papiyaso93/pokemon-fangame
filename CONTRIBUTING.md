# Workflow Git — à lire avant de pousser du code

On est deux à toucher ce repo (code + game design). Tant qu'une seule personne
committait, travailler directement sur `main` ne posait pas de problème. Dès
que deux personnes codent en parallèle, il faut un minimum de process pour
éviter les conflits et les régressions silencieuses.

## Règle de base

**Plus personne ne push directement sur `main`.** Chaque sujet de travail se
fait sur sa propre branche, avec une Pull Request sur GitHub avant de merger.

## Workflow

1. Avant de commencer à coder, se mettre à jour :
   ```
   git checkout main
   git pull origin main
   ```
2. Créer une branche pour le sujet en cours :
   ```
   git checkout -b feature/nom-du-sujet
   ```
   Exemples : `feature/safari-roster`, `fix/apparence-joueur`,
   `content/pokemon-stats`.
3. Committer normalement sur cette branche, pousser :
   ```
   git push -u origin feature/nom-du-sujet
   ```
4. Ouvrir une Pull Request sur GitHub vers `main`. Même une relecture rapide
   de 2 minutes suffit — l'objectif est surtout d'éviter les surprises, pas de
   faire un process lourd.
5. Merger, puis supprimer la branche.

## ⚠️ Piège spécifique Godot : les fichiers `.tscn` / `.tres`

Ce sont des fichiers texte, donc Git peut les merger — mais Godot réordonne
parfois les `sub_resource`, régénère des UID, ou change des détails de
formatage d'une machine à l'autre. Résultat : un conflit sur un `.tscn` est
souvent illisible et risqué à résoudre à la main (on peut casser la scène
sans s'en rendre compte).

**Donc, si vous devez modifier le même fichier `.tscn`/`.tres` en même
temps** : prévenez-vous rapidement avant de commencer, pour éviter de
travailler à deux sur le même écran/scène en parallèle. En cas de conflit
malgré tout, mieux vaut qu'une personne réapplique ses changements à la main
sur la version de l'autre plutôt que de merger le diff brut.

## Ne jamais committer

- `kanto-pipeline/pokefirered/` — clone de la décompilation FireRed (72 Mo,
  gitignoré, à re-cloner localement si besoin — voir `HANDOFF.md`).

## Garder `HANDOFF.md` à jour

C'est le point d'entrée pour reprendre le projet d'une session à l'autre
(état exact, prochaines étapes, pièges connus). Le mettre à jour à la fin
d'une session de travail notable évite de refaire découvrir les mêmes pièges.
