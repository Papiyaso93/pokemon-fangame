#!/usr/bin/env python3
"""Porte un sous-ensemble de capacités depuis pokefirered vers un fichier
GDScript unique (scripts/move_data.gd), pour le combat dresseur de Yohan
(zone 3, voir acte1-parc-safari.md et le plan de conception associé).

Source (kanto-pipeline/pokefirered) :
- src/data/battle_moves.h : struct BattleMove par capacité (effect, power,
  type, accuracy, pp, secondaryEffectChance, priority).

Volontairement PAS un portage complet des 355 capacités du jeu (contrairement
à build_pokemon_data.py qui porte les 151 espèces en entier) : seules les
capacités réellement utilisées par le combat de Yohan sont incluses ici,
choisies precisément parce qu'elles sont soit de pur dégât (EFFECT_HIT,
secondaryEffectChance=0), soit un des 2 seuls effets réellement implémentés
par scripts/battle_engine.gd (Danse Pluie, brûlure de Flammèche) — voir la
conversation de conception. Facile d'étendre MOVE_KEYS et de relancer ce
script pour ajouter des capacités plus tard.
"""
import re
from pathlib import Path

PRET = Path(__file__).parent / "pokefirered"
OUT_GD = Path(__file__).parent.parent / "scripts" / "move_data.gd"

MOVE_KEYS = [
    "SCRATCH", "EMBER", "WATER_GUN", "RAIN_DANCE",
    "VINE_WHIP", "RAZOR_LEAF", "RAPID_SPIN", "TACKLE", "KARATE_CHOP",
]

FRENCH_NAMES = {
    "SCRATCH": "Griffe",
    "EMBER": "Flammèche",
    "WATER_GUN": "Pistolet à O",
    "RAIN_DANCE": "Danse Pluie",
    "VINE_WHIP": "Fouet Lianes",
    "RAZOR_LEAF": "Tranch'Herbe",
    "RAPID_SPIN": "Vibraqua",
    "TACKLE": "Charge",
    "KARATE_CHOP": "Tranchage",
}

# Split physique/spécial par type, fidèle Gen < 4 (avant que Game Freak ne
# fasse dépendre la catégorie de la capacité elle-même plutôt que du type) —
# table fixe, pas dans les données pret.
PHYSICAL_TYPES = {
    "NORMAL", "FIGHTING", "FLYING", "GROUND", "ROCK", "BUG", "GHOST",
    "POISON", "STEEL",
}


def read(path):
    return (PRET / path).read_text()


def parse_field(block, name, cast=str):
    m = re.search(r"\." + name + r"\s*=\s*([^,\n]+)", block)
    return cast(m.group(1).strip()) if m else None


def parse_battle_moves():
    text = read("src/data/battle_moves.h")
    out = {}
    for key in MOVE_KEYS:
        pat = r"\[MOVE_" + re.escape(key) + r"\]\s*=\s*\{(.*?)\n\s*\},"
        m = re.search(pat, text, re.S)
        assert m, f"MOVE_{key} introuvable dans battle_moves.h"
        block = m.group(1)
        move_type = parse_field(block, "type").replace("TYPE_", "")
        power = int(parse_field(block, "power"))
        category = "STATUS" if power == 0 else (
            "PHYSICAL" if move_type in PHYSICAL_TYPES else "SPECIAL"
        )
        out[key] = {
            "effect": parse_field(block, "effect"),
            "power": power,
            "type": move_type,
            "category": category,
            "accuracy": int(parse_field(block, "accuracy")),
            "pp": int(parse_field(block, "pp")),
            "secondary_effect_chance": int(parse_field(block, "secondaryEffectChance")),
            "priority": int(parse_field(block, "priority")),
        }
    return out


def gd_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    moves = parse_battle_moves()

    lines = []
    lines.append("class_name MoveData")
    lines.append("extends RefCounted")
    lines.append("")
    lines.append("# Généré par kanto-pipeline/build_moves_data.py depuis pokefirered — ne pas")
    lines.append("# éditer à la main, relancer le script pour régénérer/étendre MOVE_KEYS.")
    lines.append("# Sous-ensemble volontaire (voir docstring du script), pas les 355 capacités")
    lines.append("# du jeu — seulement celles utilisées par le combat de Yohan (zone 3).")
    lines.append("")
    lines.append("const MOVES := {")
    for key in MOVE_KEYS:
        mv = moves[key]
        lines.append(f'\t"{key}": {{')
        lines.append(f'\t\t"name": {gd_string(FRENCH_NAMES[key])},')
        lines.append(f'\t\t"effect": {gd_string(mv["effect"])},')
        lines.append(f'\t\t"power": {mv["power"]},')
        lines.append(f'\t\t"type": {gd_string(mv["type"])},')
        lines.append(f'\t\t"category": {gd_string(mv["category"])},')
        lines.append(f'\t\t"accuracy": {mv["accuracy"]},')
        lines.append(f'\t\t"pp": {mv["pp"]},')
        lines.append(f'\t\t"secondary_effect_chance": {mv["secondary_effect_chance"]},')
        lines.append(f'\t\t"priority": {mv["priority"]},')
        lines.append('\t},')
    lines.append("}")
    lines.append("")

    OUT_GD.parent.mkdir(parents=True, exist_ok=True)
    OUT_GD.write_text("\n".join(lines))
    print(f"Sauvé : {OUT_GD} ({len(MOVE_KEYS)} capacités)")


if __name__ == "__main__":
    main()
