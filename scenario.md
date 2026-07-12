# Scénario — Pokémon Fangame

## À quoi sert ce document

Complète `game-design.md` (mécaniques par classe) et `FLOW.md` (parcours écran
par écran). **Celui-ci est la bible narrative** : thème, contexte du monde,
antagoniste, personnages récurrents, structure en actes, fins. Discuté avec
Gus le 09/07/2026, à tenir à jour au fil des décisions.

Légende : ✅ tranché / ❓ décision de game design encore ouverte (ne pas
improviser seul — cf. règle du projet).

---

## Vue d'ensemble

Histoire **réaliste et sérieuse** plutôt qu'une redite des jeux originaux, tout
en gardant des éléments familiers (Kanto, badges, Team Rocket, Giovanni). Ton
sombre-adulte, avec de l'humour pour ne pas plomber l'ambiance en continu.

Thème central, déjà présent dans les dialogues de Louise/Anselme : **"ici,
rien n'est gratuit"**. Tout ce qui semble facile ou gratuit dans l'histoire
doit avoir un prix caché — c'est le ressort principal du pivot criminel.

---

## Contexte du monde

Le joueur a 18 ans. Kanto n'a pas d'école — c'est une région où l'on vient
**démarrer sa vie professionnelle** une fois diplômé ailleurs. Le joueur
arrive donc "les mains vides et pleine d'espoir" (réplique déjà en jeu),
sans attaches ni réseau local à Kanto : un profil que Team Rocket sait
repérer et exploiter.

❓ Géographie précise des "régions d'études" : pas nécessaire tant que
l'histoire reste autonome à Kanto (décidé 09/07/2026 — on pourra détailler si
une suite dans d'autres régions voit le jour).

---

## Les classes

Voir `game-design.md` pour les mécaniques (slots, capture, économie, accès au
monde). Rappel narratif : **même trame principale** pour Compétiteur et
Chercheur — ils vivent la même histoire mais la résolvent différemment
(gameplay et expérience différents, pas des scènes ou une fin différentes en
soi, hors branche Criminel).

---

## Antagoniste — Team Rocket

Vrai crime organisé implanté à Kanto, sur 3 volets :

| Volet | Angle | Classe la plus concernée |
|---|---|---|
| Trafic de Pokémon | Braconnage, marché noir, espèces rares | Chercheur |
| Corruption du système compétitif | Arènes/Ligue truquées, argent détourné | Compétiteur |
| Racket / extorsion | Prêts abusifs, protection forcée visant les précaires | Commun aux deux classes |

**Giovanni** reprend son double rôle canonique : Champion d'arène de Jadielle
**et** chef secret de la Team Rocket. **Précision (11/07/2026)** : contrairement
à l'idée initiale, son arène n'est pas bloquée jusqu'à la chute de la Team
Rocket — elle se débloque normalement après l'épisode Sylph Co (voir
`actes-2-a-6-campagne.md`, acte 3). Le combat de gym contre lui à ce moment-là
est un combat classique (il n'y est jamais "à fond", comme tous les champions
face aux dresseurs qui passent) — **pas** la chute du chef de la Team Rocket,
qui reste actif jusqu'au climax final au Casino de Celadopole (acte 6).

**Jessie et James** — duo Team Rocket récurrent (canon repris tel quel).
Apparaissent au Mont Sélénite puis à Sylph Co, toujours en duo, toujours
au-dessus du niveau du joueur à ce stade de l'histoire — deux défaites
scriptées, impossibles à gagner, qui font partie intégrante du récit (voir
`actes-2-a-6-campagne.md`).

---

## Personnages récurrents

Rencontrés tôt (arc Arrivée), distincts de **Yohan** et **Camille** qui
restent des PNJ facultatifs du tutoriel de classe (Parc Safari). ❓ Moment
exact où Yohan/Camille sont introduits si le tuto est facultatif — à trancher.

### Le/la rival·e (même classe que le joueur)
- Début de partie : rivalité **saine**, motivante, pousse le joueur à
  progresser (badges).
- **Moment de bascule confirmé (11/07/2026)** : à Sylph Co (acte 3, badge
  7+), le combat 2 contre 2 perdu face à Jessie et James, suivi de leur
  tentative de recrutement — voir `actes-2-a-6-campagne.md`. Le rival prend
  **le chemin opposé à celui du joueur** à partir de cette même scène.
  Joueur reste légitime → le rival devient Rocket. Joueur devient Criminel →
  le rival reste légitime.
- Reste un obstacle jusqu'à la fin, quel que soit le chemin du joueur.
  ❓ Placement exact de la confrontation finale (avant/après Red/Giovanni au
  Casino de Celadopole, acte 6) — encore ouvert.
- Mécanisme de bascule : le joueur et le rival vivent **la même épreuve**
  (défaite face à Jessie/James + tentative de recrutement) et y réagissent à
  l'opposé — miroir dramatique assumé, pas deux histoires séparées.

### L'allié·e (autre classe que le joueur)
- Genre opposé à celui du joueur, personnage à genre fixe (pas de version
  alternative selon le genre choisi — trop de travail d'écriture pour le
  bénéfice). Pas de sous-intrigue romantique : la relation est de
  l'**admiration/complicité**, ce qui fonctionne quel que soit le genre du
  joueur.
- Apporte des compétences que le joueur n'a pas (celles de l'autre classe),
  aide concrètement dans l'histoire plutôt que de rester en simple figurant.

### Superboss caché (postgame)
- Un·e dresseur·se **légendaire retiré·e**, léger ancrage dans l'univers
  (pas un pur easter egg déconnecté). Sa présence se justifie par tout ce que
  le joueur a déjà accompli à ce stade (Ligue/tournoi, légendaires, Giovanni,
  rival) — c'est le vrai dernier test, mérité plutôt que gratuit.
- ❓ Identité/nom précis à définir plus tard (clin d'œil perso de Gus). Ce
  n'est **pas** Red (voir ci-dessous), qui a déjà son propre rôle dans la
  trame principale.

### Red — mentor du Compétiteur, pendant du Pr Chen
- Symétrique au Pr Chen pour le Chercheur, mais avec un style
  d'accompagnement volontairement différent — ce qui sert la différence
  d'expérience recherchée entre les deux classes (Chercheur = encadrement
  quotidien et concret ; Compétiteur = parcours plus solitaire porté par la
  poursuite d'une légende).
  - **Sa mère**, rencontrée à Bourg Palette, joue le rôle de relais concret :
    elle indique où aller, transmet en pratique les premiers défis que Red a
    laissés pour les jeunes prometteurs. Ça garde un flux de quêtes
    équivalent à celui du Pr Chen, sans avoir à inventer un système
    différent.
  - **Red lui-même reste insaisissable** presque tout le jeu : on entend
    parler de lui partout à Kanto ("il vient de repartir", "il était là
    hier"), on l'aperçoit 2-3 fois de loin sans vraie interaction — ça
    construit du mythe plutôt qu'une présence quotidienne.
  - **Sa vraie apparition a lieu au climax de l'acte 6** (Casino de
    Celadopole), intégrée à la chute de Giovanni plutôt que dans une scène
    séparée :
    - Chemin légitime : Red réapparaît en personne comme **renfort** pour
      affronter Giovanni aux côtés du joueur — le "dépassement du mentor" se
      prouve par l'action, pas par un duel formé (un petit combat amical
      peut suivre en guise de clôture, à confirmer).
    - Chemin Criminel : Red devient le **dernier obstacle avant le trône** —
      le héros légendaire tente d'arrêter le nouveau boss de la Team
      Rocket. Climax fort pour la fin "les méchants triomphent".

---

## Structure narrative (les actes)

### Acte 1 — Arrivée (Zone Safari)

**Détail complet dans `acte1-parc-safari.md`** (validé 10/07/2026) — ce
fichier ne garde que le résumé haut niveau, à tenir cohérent avec la version
détaillée.

1. Création du personnage, explications (Louise/Anselme).
2. **Parcours guidé obligatoire** dans le Parc Safari, Chercheur d'abord :
   Camille (guide Chercheur) fait vivre 2 actions (retrouver un Pokémon bébé
   échappé + Pokédex, puzzle de piste de cris + canne à pêche), puis Yohan
   (guide Compétiteur) fait vivre 2 actions (combat météo, combat duo révélé
   + objet de Surf). Fini l'aperçu facultatif façon `tutorial-competiteur.md`
   — devenu nécessaire du moment que le Parc Safari est un vrai acte 1 et
   que des objets clés en dépendent.
3. Capture libre du premier Pokémon partenaire (mécanique existante).
4. Choix de la classe (Compétiteur/Chercheur, avec Louise).
5. **Rencontre du/de la rival·e et de l'allié·e** : ils sont déjà présents
   physiquement dans le bâtiment au retour du joueur — Anselme explique
   qu'ils viennent eux aussi de choisir leur classe et d'attraper leur
   premier Pokémon (parcours parallèle, pas montré à l'écran).
   - Le/la rival·e est **toujours** celui/celle qui partage la classe du
     joueur ; l'allié·e est **toujours** celui/celle de l'autre classe —
     vrai dès l'acte 1, quel que soit le choix du joueur.
6. Remise de la **carte de Kanto** en sortant du bâtiment (utile seulement à
   partir de là). **Fin de l'acte** sur un objectif clair : direction Bourg
   Palette, pour voir le Pr Chen (Chercheur) ou trouver Red (Compétiteur, en
   réalité sa mère qui l'oriente — voir section Red ci-dessus). Le/la
   rival·e et l'allié·e s'y retrouvent aussi, ce qui amorce naturellement
   l'acte 2.

❓ Noms définitifs du/de la rival·e et de l'allié·e — placeholders acceptés
pour l'instant, à trancher plus tard sans bloquer le reste de l'écriture.

### Actes 2 à 7 — Badges, Team Rocket, Ligue, climax

**Détail complet dans `actes-2-a-6-campagne.md`** (validé 11/07/2026,
remplace l'ancien découpage à 5 actes). Résumé haut niveau :

- **Acte 2 — Badges et escalade Rocket** (jusqu'au Mont Sélénite) : badges 1
  à ~5, communs aux 2 classes. 3 rencontres Team Rocket badge-gated à Azuria
  (badge 3+, combat gagnable), à la centrale électrique à l'est d'Azuria
  (badge 4+, joueur spectateur — Électhor capturé sous ses yeux), et au Mont
  Sélénite (badge 5+, défaite scriptée contre Jessie et James — premier vrai
  tournant).
- **Acte 3 — Sylph Co, le choix, et Jadielle** : prise d'otage de Sylph Co
  (badge 7+), champions/top dresseurs en renfort, 2e défaite scriptée contre
  Jessie et James (2v2 avec le/la rival·e cette fois) → tentative de
  recrutement → **choix gentil/méchant du joueur, bascule inverse du
  rival**. Puis combat de gym classique contre Giovanni à Jadielle
  (obligatoire, badge/test d'initiation selon le chemin — ne représente pas
  la chute du chef Rocket).
- **Acte 4 — Ligue Pokémon actuelle** : étape commune aux 2 classes
  (prérequis vécu différemment selon gentil/méchant). À la fin, Team Rocket
  prend le contrôle de la Ligue (tout le monde affaibli).
- **Acte 5 — Arc de classe** : tournois (Compétiteur) ou grosse
  recherche/légendaire (Chercheur), sous contrôle Rocket de la Ligue.
- **Acte 6 — Casino de Celadopole (climax final)** : QG Team Rocket. Chemin
  légitime → Red + renforts, Giovanni tombe pour de bon. Chemin Criminel →
  combat contre les gentils, trahison de Giovanni, le joueur devient le
  nouveau boss.
- **Acte 7 — Superboss caché** (postgame, optionnel).

---

## Fins

- **Chemin légitime** : Team Rocket démantelée, Giovanni arrêté. Corruption
  **volontairement pas totalement éradiquée** (pas de monde bisounours) —
  laisse une porte ouverte pour une suite (ex. évasion de Giovanni dans une
  future région).
- **Chemin Criminel** : le joueur prend la place du boss et **règne sur la
  région** — fin où "les méchants gagnent", assumée comme telle.

---

## Ton

- Sombre-adulte, tempéré par de l'humour (pour casser la tension, pas pour
  désamorcer l'enjeu).
- Enjeux humains francs possibles : arrestations, blessures, trahisons.
- **Pas de mort de Pokémon à l'écran pour l'instant** (09/07/2026) — on garde
  l'angoisse/l'ambiguïté sans la montrer. Pas de violence graphique.

---

## À confirmer plus tard

- Nom et personnalité définitifs du/de la rival·e et de l'allié·e
  (placeholders acceptés pour avancer)
- Placement exact de la confrontation contre le/la rival·e par rapport à
  Red/Giovanni au climax de l'acte 6 (Casino de Celadopole)
- Détail du petit combat amical contre Red pour le chemin légitime (présent
  ou non)
- Identité du superboss légendaire postgame (distinct de Red)
- Voir aussi `actes-2-a-6-campagne.md` pour toutes les questions ouvertes
  détaillées des actes 2 à 6 (Léo, argumentaire de recrutement Jessie/James,
  contenu des quêtes Criminel, formats de tournoi, etc.)
- Contenu concret de l'arc Chercheur de l'acte 5 (légendaire/chromatique/
  méga-évolution, probablement lié au Minidraco chromatique de l'acte 1)
