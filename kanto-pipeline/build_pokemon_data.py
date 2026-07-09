#!/usr/bin/env python3
"""Porte les données des 151 premiers Pokémon (Bulbizarre -> Mew, SPECIES_
1-151, KANTO_SPECIES_END) depuis pokefirered vers un fichier GDScript unique,
plus copie les sprites (front/back/icon) dans assets/pokemon/<espece>/.

Sources (kanto-pipeline/pokefirered) :
- include/constants/species.h : ID -> nom de constante (= nom de dossier
  sprite, ex. SPECIES_MR_MIME -> graphics/pokemon/mr_mime/)
- src/data/text/species_names.h : nom affiché (ex. "BULBASAUR")
- src/data/pokemon/species_info.h : stats de base, types, taux de capture,
  XP, genre, groupe de croissance, groupes d'œufs, talents, fuite Zone
  Safari, etc. (struct SpeciesInfo, include/pokemon.h:208)
- src/data/pokemon/pokedex_entries.h + pokedex_text_fr.h : taille, poids,
  catégorie, description (texte "_fr" = version FireRed du jeu, PAS
  français — le texte est en anglais dans les 2 variantes FR/LG)
- src/data/pokemon/evolution.h : méthode/palier/cible d'évolution
- src/data/pokemon/level_up_learnset_pointers.h +
  level_up_learnsets.h : capacités apprises par niveau
- src/data/pokemon/tmhm_learnsets.h : CT/CS apprenables (juste la liste des
  ID machine, pas de catalogue de capacités derrière pour l'instant)

Volontairement PAS porté (cf. discussion avec Gus) : groupes/capacités
d'œufs (élevage, hors scope), capacités tuteur. Faciles à ajouter plus tard,
tables indépendantes.
"""
import re
import shutil
from pathlib import Path

PRET = Path(__file__).parent / "pokefirered"
OUT_GD = Path(__file__).parent.parent / "scripts" / "species_data.gd"
OUT_SPRITES = Path(__file__).parent.parent / "assets" / "pokemon"

MAX_ID = 151  # SPECIES_MEW = KANTO_SPECIES_END


def read(path):
    return (PRET / path).read_text()


def parse_species_ids():
    """SPECIES_TOKEN -> id, uniquement 1..151."""
    text = read("include/constants/species.h")
    ids = {}
    for m in re.finditer(r"#define SPECIES_(\w+) (\d+)", text):
        token, sid = m.group(1), int(m.group(2))
        if 1 <= sid <= MAX_ID:
            ids[sid] = token
    assert len(ids) == MAX_ID, f"attendu {MAX_ID} espèces, trouvé {len(ids)}"
    return ids


# Noms français officiels des 151 premiers Pokémon — la ROM pret est
# anglaise, aucune donnée française à extraire, donc table à part codée en
# dur ici (contrairement au reste du script, rien à parser depuis pret).
FRENCH_NAMES = {
    "BULBASAUR": "Bulbizarre", "IVYSAUR": "Herbizarre", "VENUSAUR": "Florizarre",
    "CHARMANDER": "Salamèche", "CHARMELEON": "Reptincel", "CHARIZARD": "Dracaufeu",
    "SQUIRTLE": "Carapuce", "WARTORTLE": "Carabaffe", "BLASTOISE": "Tortank",
    "CATERPIE": "Chenipan", "METAPOD": "Chrysacier", "BUTTERFREE": "Papilusion",
    "WEEDLE": "Aspicot", "KAKUNA": "Coconfort", "BEEDRILL": "Dardargnan",
    "PIDGEY": "Roucool", "PIDGEOTTO": "Roucoups", "PIDGEOT": "Roucarnage",
    "RATTATA": "Rattata", "RATICATE": "Rattatac", "SPEAROW": "Piafabec",
    "FEAROW": "Rapasdepic", "EKANS": "Abo", "ARBOK": "Arbok",
    "PIKACHU": "Pikachu", "RAICHU": "Raichu", "SANDSHREW": "Sabelette",
    "SANDSLASH": "Sablaireau", "NIDORAN_F": "Nidoran♀", "NIDORINA": "Nidorina",
    "NIDOQUEEN": "Nidoqueen", "NIDORAN_M": "Nidoran♂", "NIDORINO": "Nidorino",
    "NIDOKING": "Nidoking", "CLEFAIRY": "Mélofée", "CLEFABLE": "Mélodelfe",
    "VULPIX": "Goupix", "NINETALES": "Feunard", "JIGGLYPUFF": "Rondoudou",
    "WIGGLYTUFF": "Grodoudou", "ZUBAT": "Nosferapti", "GOLBAT": "Nosferalto",
    "ODDISH": "Mystherbe", "GLOOM": "Ortide", "VILEPLUME": "Rafflesia",
    "PARAS": "Paras", "PARASECT": "Parasect", "VENONAT": "Mimitoss",
    "VENOMOTH": "Aéromite", "DIGLETT": "Taupiqueur", "DUGTRIO": "Triopikeur",
    "MEOWTH": "Miaouss", "PERSIAN": "Persian", "PSYDUCK": "Psykokwak",
    "GOLDUCK": "Akwakwak", "MANKEY": "Férosinge", "PRIMEAPE": "Colossinge",
    "GROWLITHE": "Caninos", "ARCANINE": "Arcanin", "POLIWAG": "Ptitard",
    "POLIWHIRL": "Têtarte", "POLIWRATH": "Tartard", "ABRA": "Abra",
    "KADABRA": "Kadabra", "ALAKAZAM": "Alakazam", "MACHOP": "Machoc",
    "MACHOKE": "Machopeur", "MACHAMP": "Mackogneur", "BELLSPROUT": "Chétiflor",
    "WEEPINBELL": "Boustiflor", "VICTREEBEL": "Empiflor", "TENTACOOL": "Tentacool",
    "TENTACRUEL": "Tentacruel", "GEODUDE": "Racaillou", "GRAVELER": "Gravalanch",
    "GOLEM": "Grolem", "PONYTA": "Ponyta", "RAPIDASH": "Galopa",
    "SLOWPOKE": "Ramoloss", "SLOWBRO": "Flagadoss", "MAGNEMITE": "Magnéti",
    "MAGNETON": "Magnéton", "FARFETCHD": "Canarticho", "DODUO": "Doduo",
    "DODRIO": "Dodrio", "SEEL": "Otaria", "DEWGONG": "Lamantine",
    "GRIMER": "Tadmorv", "MUK": "Grotadmorv", "SHELLDER": "Kokiyas",
    "CLOYSTER": "Crustabri", "GASTLY": "Fantominus", "HAUNTER": "Spectrum",
    "GENGAR": "Ectoplasma", "ONIX": "Onix", "DROWZEE": "Soporifik",
    "HYPNO": "Hypnomade", "KRABBY": "Krabby", "KINGLER": "Krabboss",
    "VOLTORB": "Voltorbe", "ELECTRODE": "Électrode", "EXEGGCUTE": "Noeunoeuf",
    "EXEGGUTOR": "Noadkoko", "CUBONE": "Osselait", "MAROWAK": "Ossatueur",
    "HITMONLEE": "Kicklee", "HITMONCHAN": "Tygnon", "LICKITUNG": "Lippoutou",
    "KOFFING": "Smogo", "WEEZING": "Smogogo", "RHYHORN": "Rhinocorne",
    "RHYDON": "Rhinoféros", "CHANSEY": "Leveinard", "TANGELA": "Saquedeneu",
    "KANGASKHAN": "Kangourex", "HORSEA": "Hypotrempe", "SEADRA": "Hypocéan",
    "GOLDEEN": "Poissirène", "SEAKING": "Poissoroy", "STARYU": "Stari",
    "STARMIE": "Staross", "MR_MIME": "M. Mime", "SCYTHER": "Insécateur",
    "JYNX": "Lippouti", "ELECTABUZZ": "Élektek", "MAGMAR": "Magmar",
    "PINSIR": "Scarabrute", "TAUROS": "Tauros", "MAGIKARP": "Magicarpe",
    "GYARADOS": "Léviator", "LAPRAS": "Lokhlass", "DITTO": "Métamorph",
    "EEVEE": "Évoli", "VAPOREON": "Aquali", "JOLTEON": "Voltali",
    "FLAREON": "Pyroli", "PORYGON": "Porygon", "OMANYTE": "Amonita",
    "OMASTAR": "Amonistar", "KABUTO": "Kabuto", "KABUTOPS": "Kabutops",
    "AERODACTYL": "Ptéra", "SNORLAX": "Ronflex", "ARTICUNO": "Artikodin",
    "ZAPDOS": "Électhor", "MOLTRES": "Sulfura", "DRATINI": "Dratatin",
    "DRAGONAIR": "Draco", "DRAGONITE": "Dracolosse", "MEWTWO": "Mewtwo",
    "MEW": "Mew",
}


def parse_names():
    # Le nom anglais brut (species_names.h) ne sert plus qu'en repli si jamais
    # un token manquait de FRENCH_NAMES — le jeu affiche toujours le français.
    text = read("src/data/text/species_names.h")
    names = {}
    for m in re.finditer(r'\[SPECIES_(\w+)\] = _\("([^"]*)"\)', text):
        token, raw = m.group(1), m.group(2)
        english = " ".join(w.capitalize() for w in raw.split(" "))
        names[token] = FRENCH_NAMES.get(token, english)
    return names


def parse_field(block, name, cast=int):
    m = re.search(r"\." + name + r"\s*=\s*([^,\n]+)", block)
    return cast(m.group(1).strip()) if m else None


def parse_species_info():
    text = read("src/data/pokemon/species_info.h")
    # Le bloc factice [SPECIES_NONE] = {0}, tient sur une seule ligne, sans
    # le motif "{\n ... \n    }," des vraies entrées — le laisser dans le
    # texte casse le premier match non-greedy (il avale tout jusqu'au
    # prochain "    }," réel, càd la fin du bloc BULBASAUR en entier).
    text = re.sub(r"\[SPECIES_NONE\] = \{0\},\n", "", text)
    info = {}
    for m in re.finditer(r"\[SPECIES_(\w+)\]\s*=\s*\{(.*?)\n    \},", text, re.S):
        token, block = m.group(1), m.group(2)
        if "baseHP" not in block:
            continue  # entrées macro (OLD_UNOWN_SPECIES_INFO), pas concernées (hors 1-151)
        types = re.findall(r"TYPE_(\w+)", block)
        types = list(dict.fromkeys(types))  # dédoublonne (mono-type répété x2)
        abilities = [a for a in re.findall(r"ABILITY_(\w+)", block) if a != "NONE"]
        egg_groups = list(dict.fromkeys(
            g for g in re.findall(r"EGG_GROUP_(\w+)", block) if g != "UNDISCOVERED"
        ))
        gender_block = parse_field(block, "genderRatio", str)
        info[token] = {
            "base_hp": parse_field(block, "baseHP"),
            "base_attack": parse_field(block, "baseAttack"),
            "base_defense": parse_field(block, "baseDefense"),
            "base_speed": parse_field(block, "baseSpeed"),
            "base_sp_attack": parse_field(block, "baseSpAttack"),
            "base_sp_defense": parse_field(block, "baseSpDefense"),
            "types": types,
            "catch_rate": parse_field(block, "catchRate"),
            "exp_yield": parse_field(block, "expYield"),
            "gender_ratio": gender_block,
            "egg_cycles": parse_field(block, "eggCycles"),
            "friendship": parse_field(block, "friendship"),
            "growth_rate": parse_field(block, "growthRate", str),
            "egg_groups": egg_groups,
            "abilities": abilities,
            "safari_flee_rate": parse_field(block, "safariZoneFleeRate"),
        }
    return info


def parse_pokedex_text():
    """gXPokedexText -> description (une seule chaîne, \\n littéraux gardés
    tels quels, l'appelant Godot décidera comment les afficher)."""
    text = read("src/data/pokemon/pokedex_text_fr.h")
    out = {}
    for m in re.finditer(r"const u8 g(\w+)PokedexText\[\] = _\((.*?)\);", text, re.S):
        varname, body = m.group(1), m.group(2)
        if varname.endswith("Unused"):
            continue
        parts = re.findall(r'"((?:[^"\\]|\\.)*)"', body)
        out[varname] = "".join(parts).replace("\\n", " ").strip()
    return out


def parse_pokedex_entries(ids):
    text = read("src/data/pokemon/pokedex_entries.h")
    desc = parse_pokedex_text()
    entries = {}
    for m in re.finditer(r"\[NATIONAL_DEX_(\w+)\]\s*=\s*\{(.*?)\n    \},", text, re.S):
        token, block = m.group(1), m.group(2)
        cat = re.search(r'\.categoryName = _\("([^"]*)"\)', block)
        desc_var = re.search(r"\.description = g(\w+)PokedexText,", block)
        entries[token] = {
            "category": cat.group(1).title() if cat else "",
            "height_dm": parse_field(block, "height") or 0,  # décimètres
            "weight_hg": parse_field(block, "weight") or 0,  # hectogrammes
            "description": desc.get(desc_var.group(1), "") if desc_var else "",
        }
    return entries


def parse_evolutions():
    text = read("src/data/pokemon/evolution.h")
    evos = {}
    # Certaines espèces (Évoli) ont plusieurs tuples {méthode, param, cible}
    # sur plusieurs lignes — borner la capture sur un compte de "}}," précis
    # casse soit les entrées mono-ligne, soit les multi-lignes (essayé les
    # deux, cf. bug vécu). Solution robuste : capturer jusqu'à la ligne de
    # la prochaine espèce (ou la fin du tableau), peu importe le nombre de
    # tuples/accolades à l'intérieur, puis chercher tous les tuples dedans.
    for m in re.finditer(r"\[SPECIES_(\w+)\]\s*=\s*\{(.*?)(?=\n    \[SPECIES_|\n\};)", text, re.S):
        token, body = m.group(1), m.group(2)
        chain = []
        for tm in re.finditer(r"\{EVO_(\w+),\s*([^,]+),\s*SPECIES_(\w+)\}", body):
            method, param, target = tm.group(1), tm.group(2).strip(), tm.group(3)
            chain.append({"method": method, "param": param, "target": target})
        if chain:
            evos[token] = chain
    return evos


def parse_level_up_learnsets():
    pointers_text = read("src/data/pokemon/level_up_learnset_pointers.h")
    var_of = {}
    for m in re.finditer(r"\[SPECIES_(\w+)\] = (s\w+LevelUpLearnset),", pointers_text):
        var_of[m.group(1)] = m.group(2)

    sets_text = read("src/data/pokemon/level_up_learnsets.h")
    moves_of = {}
    for m in re.finditer(r"static const u16 (s\w+LevelUpLearnset)\[\] = \{(.*?)\};", sets_text, re.S):
        varname, body = m.group(1), m.group(2)
        moves = [
            {"level": int(lm.group(1)), "move": lm.group(2)}
            for lm in re.finditer(r"LEVEL_UP_MOVE\((\d+),\s*MOVE_(\w+)\)", body)
        ]
        moves_of[varname] = moves

    return {token: moves_of.get(var, []) for token, var in var_of.items()}


def parse_tmhm_learnsets():
    text = read("src/data/pokemon/tmhm_learnsets.h")
    out = {}
    for m in re.finditer(r"\[SPECIES_(\w+)\]\s*=\s*TMHM_LEARNSET\((.*?)\),\n", text, re.S):
        token, body = m.group(1), m.group(2)
        machines = re.findall(r"TMHM\((\w+)\)", body)
        if machines:
            out[token] = machines
    return out


def gd_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def gd_array_of_strings(items):
    return "[" + ", ".join(gd_string(i) for i in items) + "]"


def gd_learnset(moves):
    return "[" + ", ".join(
        '{"level": %d, "move": %s}' % (mv["level"], gd_string(mv["move"])) for mv in moves
    ) + "]"


def gd_evolutions(chain):
    return "[" + ", ".join(
        '{"method": %s, "param": %s, "target": %s}' % (
            gd_string(e["method"]), gd_string(e["param"]), gd_string(e["target"])
        ) for e in chain
    ) + "]"


def main():
    ids = parse_species_ids()
    names = parse_names()
    info = parse_species_info()
    dex = parse_pokedex_entries(ids)
    evos = parse_evolutions()
    levelup = parse_level_up_learnsets()
    tmhm = parse_tmhm_learnsets()

    OUT_SPRITES.mkdir(parents=True, exist_ok=True)

    lines = []
    lines.append("class_name SpeciesData")
    lines.append("extends RefCounted")
    lines.append("")
    lines.append("# Généré par kanto-pipeline/build_pokemon_data.py depuis pokefirered — ne pas")
    lines.append("# éditer à la main, relancer le script pour régénérer. Clé = nom en minuscules")
    lines.append("# (identique au dossier sprite assets/pokemon/<clé>/), pas le numéro de Dex.")
    lines.append("")
    lines.append("const SPECIES := {")
    for sid in range(1, MAX_ID + 1):
        token = ids[sid]
        key = token.lower()
        sp_info = info[token]
        dex_info = dex.get(token, {"category": "", "height_dm": 0, "weight_hg": 0, "description": ""})
        evo_chain = evos.get(token, [])
        moves = levelup.get(token, [])
        machines = tmhm.get(token, [])

        # Copie des sprites (déjà en RGBA correct, pas de décodage custom
        # nécessaire — contrairement à region_map.png, ces PNG embarquent
        # directement leur propre palette 16 couleurs).
        src_dir = PRET / "graphics" / "pokemon" / key
        dst_dir = OUT_SPRITES / key
        dst_dir.mkdir(parents=True, exist_ok=True)
        for fname in ("front.png", "back.png", "icon.png"):
            src = src_dir / fname
            if src.exists():
                shutil.copyfile(src, dst_dir / fname)

        lines.append(f'\t"{key}": {{')
        lines.append(f'\t\t"dex_number": {sid},')
        lines.append(f'\t\t"name": {gd_string(names.get(token, token.title()))},')
        lines.append(f'\t\t"types": {gd_array_of_strings(sp_info["types"])},')
        lines.append(f'\t\t"base_hp": {sp_info["base_hp"]},')
        lines.append(f'\t\t"base_attack": {sp_info["base_attack"]},')
        lines.append(f'\t\t"base_defense": {sp_info["base_defense"]},')
        lines.append(f'\t\t"base_sp_attack": {sp_info["base_sp_attack"]},')
        lines.append(f'\t\t"base_sp_defense": {sp_info["base_sp_defense"]},')
        lines.append(f'\t\t"base_speed": {sp_info["base_speed"]},')
        lines.append(f'\t\t"catch_rate": {sp_info["catch_rate"]},')
        lines.append(f'\t\t"exp_yield": {sp_info["exp_yield"]},')
        lines.append(f'\t\t"gender_ratio": {gd_string(sp_info["gender_ratio"])},')
        lines.append(f'\t\t"egg_cycles": {sp_info["egg_cycles"]},')
        lines.append(f'\t\t"base_friendship": {sp_info["friendship"]},')
        lines.append(f'\t\t"growth_rate": {gd_string(sp_info["growth_rate"])},')
        lines.append(f'\t\t"egg_groups": {gd_array_of_strings(sp_info["egg_groups"])},')
        lines.append(f'\t\t"abilities": {gd_array_of_strings(sp_info["abilities"])},')
        lines.append(f'\t\t"safari_flee_rate": {sp_info["safari_flee_rate"]},')
        lines.append(f'\t\t"category": {gd_string(dex_info["category"])},')
        lines.append(f'\t\t"height_dm": {dex_info["height_dm"]},')
        lines.append(f'\t\t"weight_hg": {dex_info["weight_hg"]},')
        lines.append(f'\t\t"description": {gd_string(dex_info["description"])},')
        lines.append(f'\t\t"evolutions": {gd_evolutions(evo_chain)},')
        lines.append(f'\t\t"level_up_moves": {gd_learnset(moves)},')
        lines.append(f'\t\t"tm_hm_learnset": {gd_array_of_strings(machines)},')
        lines.append('\t},')
    lines.append("}")
    lines.append("")

    OUT_GD.parent.mkdir(parents=True, exist_ok=True)
    OUT_GD.write_text("\n".join(lines))
    print(f"Sauvé : {OUT_GD} ({MAX_ID} espèces)")
    print(f"Sprites copiés dans : {OUT_SPRITES}")


if __name__ == "__main__":
    main()
