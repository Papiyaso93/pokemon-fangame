# Tutoriel Compétiteur — proposition de scénario

**⚠️ Organisation remplacée par `acte1-parc-safari.md` (10/07/2026).** Le Parc
Safari est devenu le vrai premier acte de l'histoire (voir `scenario.md`) : les
tutos Compétiteur/Chercheur ne sont plus optionnels ni indépendants, ils
forment un seul parcours guidé obligatoire. Les dialogues et brouillons de
combat ci-dessous restent réutilisables tels quels et sont référencés depuis
`acte1-parc-safari.md`, mais pour la structure/l'ordre/les objets clés,
c'est ce nouveau document qui fait foi.

**Statut : proposition à valider avec l'ami de Gus.** Rien n'est encore implémenté ni
tranché définitivement — ce document sert de support pour la discussion, à mettre à
jour au fil des décisions.

## Contexte

Se déroule dans le Parc Safari, **avant** le vrai choix de classe (qui se fait à la
toute fin, avec Louise — voir `FLOW.md` section 4). Les 2 PNJ (déjà en place dans
`safari_zone_center.tscn`, sprites `cooltrainer_m`/`scientist`) proposent chacun un
**aperçu essayable** de leur classe, sans engagement — le joueur peut tester l'un,
l'autre, les deux, ou aucun, avant de trancher avec Louise.

PNJ : **Yohan** (compétiteur aguerri) et une 2e PNJ à nommer (proposition : **Camille**),
tous deux noms de travail, facilement renommables.

## Règle transverse : dialogues neutres en genre

Voir `game-design.md`, section "Conventions d'écriture" — toutes les lignes ci-dessous
doivent éviter les adjectifs accordés en genre.

## Déroulé

1. **Yohan explique la classe Compétiteur**, sans avoir encore demandé de tester.
2. **Il demande si le joueur veut un aperçu** (Oui/Non).
   - **Non** : il indique qu'on peut revenir le voir plus tard si l'envie change.
   - **Oui** : il indique une zone du parc (à définir) où le retrouver, et dit qu'il
     nous y attendra directement (parti "en avance", pas suivi pas à pas).
3. **Tuto "verrouillé"** une fois lancé :
   - Reparler à la 2e PNJ (Chercheur) pendant que le tuto Compétiteur est en cours ->
     elle renvoie finir avec Yohan d'abord.
   - Essayer de sortir du parc -> confirmation "Tu es en pleine initiation Compétiteur.
     Vraiment abandonner et sortir du parc ?" (Oui/Non).
   - Reparler à Yohan avant d'arriver au point de rendez-vous -> répète l'indication
     de zone, sans le "Parfait" du premier message (déjà validé, pas la peine de
     répéter l'enthousiasme).
4. **Le joueur rejoint la zone indiquée par ses propres moyens.**
   - Sur le chemin : possibilité de croiser d'autres nouveaux arrivants (autres
     joueurs fraîchement débarqués comme le nôtre), qu'on pourrait recroiser plus
     tard dans le jeu (rivaux et/ou clins d'œil). **Note indépendante du tuto
     Compétiteur en lui-même**, juste une idée à garder pour le worldbuilding
     général.
5. **Retrouvailles avec Yohan** dans la zone : il prête 3 Pokémon (lesquels/niveau à
   définir plus tard), explique qu'on va affronter quelqu'un, et indique où aller.
   Ton à adopter ici : **pédagogique, pas surmotivé** — c'est de l'initiation, pas un
   hype de compétition. C'est aussi le moment (ou alternativement, le dresseur
   adverse lui-même) d'annoncer la règle "pas d'objet utilisable en combat officiel,
   seuls les objets déjà équipés comptent", et qu'on va s'entraîner dans ces
   conditions dès maintenant.
6. **Combat 1 — stratégique (météo)** contre un dresseur adverse.
   - Conseils de Yohan pendant le combat (dialogue à retravailler plus tard,
     brouillon pas satisfaisant pour l'instant).
   - Message de fin différent selon victoire/défaite (à retravailler plus tard),
     mais **n'affecte pas la suite du tuto** dans les deux cas.
7. **Dans la même zone, rencontre de Camille** (2e PNJ, une femme pour la parité) :
   explique qu'aucune équipe n'est infaillible, qu'il faut connaître ses forces et
   faiblesses (et celles d'en face).
8. **Elle reprend les 3 Pokémon prêtés par Yohan et en prête 3 autres**, sans dire à
   l'avance ce qui change dans le combat à venir.
9. **Combat 2 — duo, révélé seulement au début du combat.**
   - **Précision de mécanique (corrigée)** : combat duo **solo** — le joueur envoie 2
     Pokémon simultanément contre les 2 Pokémon du dresseur adverse (pas un
     coéquipier IA), avec ciblage à choisir à chaque action. Camille supervise/
     conseille, elle ne combat pas à nos côtés.
   - Conseils pendant le combat (brouillon à retravailler plus tard).
   - Message de fin différent selon victoire/défaite (à retravailler plus tard),
     n'affecte pas la suite.
10. **Fin du tuto** : Camille (ou Yohan, à trancher) reprend les Pokémon prêtés, le
    joueur est téléporté à l'entrée du Parc Safari, repositionné face à Yohan comme en
    pleine discussion. Yohan conclut (ligne de fin à retravailler avec les autres
    dialogues de combat).
11. **Si le joueur reparle à Yohan après coup** : prévoir un texte indiquant que
    l'aperçu a déjà été fait.

## Dialogues validés (ou à corriger encore)

**Yohan — explication de la classe** *(à retravailler, la V1 ne satisfaisait pas)*
> "Le Compétiteur, c'est simple sur le papier : combattre, progresser, devenir
> Champion de la Ligue. Sur le terrain, c'est du calcul, de l'anticipation, et du
> sang-froid à chaque tour."

**Proposition de test — VALIDÉE (corrigée pour la neutralité, minimalement retouchée)**
> "Alors, envie de tester la voie du Compétiteur ? Si t'aimes la stratégie, les défis
> qui se jouent à un coup près, et l'idée de repousser tes limites en combat, viens,
> je vais te montrer ce qui t'attend."

**Si Non**
> "Pas de souci. Si l'envie te prend plus tard, je serai toujours dans le coin."

**Si Oui**
> "Retrouve-moi du côté de [zone à définir] — j'ai deux ou trois choses à te montrer
> là-bas."

**Si on reparle à Yohan avant d'arriver au point de rendez-vous** (même texte, sans le
"Parfait" initial — pas la peine de répéter l'enthousiasme)
> "Retrouve-moi du côté de [zone à définir] — j'ai deux ou trois choses à te montrer
> là-bas."

**Si on reparle à Camille (Chercheur) pendant le tuto Compétiteur en cours**
> "Yohan t'a déjà mis le grappin dessus, non ? Va d'abord finir avec lui, on se
> reparlera après."

**Prompt de sortie du parc pendant le tuto — corrigé (nommer l'initiation, pas le PNJ)**
> "Tu es en pleine initiation Compétiteur. Vraiment abandonner et sortir du parc ?"
> *(Oui/Non)*

**Retrouvailles avec Yohan dans la zone d'arrivée — À RETRAVAILLER**
Ton pédagogique, pas surmotivé. Doit inclure (ici ou via le dresseur adverse) la règle
objets interdits en combat officiel.
> *(brouillon rejeté : "Montre-moi ce que t'as dans le ventre" — trop "hype
> compétition", pas assez "initiation")*

**Pendant le combat 1 (météo posée)** — brouillon jugé faible, à retravailler
> *(brouillon rejeté : "Tu vois ? Il vient de retourner la table. À toi de
> t'adapter.")*

**2e PNJ (Camille) — intro**
> "Toi, tu dois être la nouvelle recrue de Yohan. Écoute bien : aucune équipe n'est
> infaillible. Connaître ses forces, ses faiblesses, et celles d'en face, c'est la
> vraie base."

**Camille reprend/reprête les Pokémon**
> "Cette fois, nouvelle équipe, nouvelle donne. Va voir [adversaire] — cette fois, tu
> vas comprendre en le vivant plutôt qu'en l'entendant."

**Révélation duo, en tout début de combat 2**
> "Ah, un détail que j'ai oublié de mentionner : ce sera un combat en duo."

## Questions ouvertes / à trancher avec l'ami de Gus

- Nom définitif de la 2e PNJ (proposition : Camille).
- Zones exactes du parc pour le rendez-vous et les 2 combats.
- Qui prend en charge la règle "objets interdits" : Yohan, ou le dresseur adverse
  lui-même au début du combat ?
- Qui reprend les Pokémon et conclut à la toute fin (Yohan ou Camille) ?
- Pokémon prêtés (espèces, niveaux) pour les 2 équipes de 3.
- Dialogues de conseil pendant les combats (brouillons actuels jugés faibles).
- Messages de fin de combat (victoire/défaite) pour les 2 combats.
- Ligne de conclusion finale de Yohan.
- Idée "croiser d'autres nouveaux arrivants sur le chemin" : à creuser séparément,
  indépendante de ce tuto.
- Mini-map du Parc Safari (voir discussion — scope réduit au parc pour commencer,
  décision de généraliser à tout Kanto reportée).

## Tutoriel Chercheur

Pas encore détaillé à ce niveau — scénario de base déjà esquissé (voir discussion),
à reprendre dans un document séparé une fois le Compétiteur validé avec l'ami de Gus.
