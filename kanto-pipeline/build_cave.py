#!/usr/bin/env python3
"""Génère une petite grotte générique réutilisable (sol + murs, vraies tuiles
FRLG extraites de Mt Moon) avec 2 portes (warps) vers 2 points d'une ou deux
routes. Même format de sortie que build_godot.py (JSON + atlas below/above)
+ un champ "warps" (téléportation ponctuelle, indépendante des bords de map).
"""
import json
from pathlib import Path
from PIL import Image
import render_map as R

PRET = R.PRET
OUT = Path("/Users/gus/Desktop/pokemon-fangame/generated")

FLOOR = 641   # metatile réel Mt Moon (sol de grotte), collision=0
WALL = 657    # metatile réel Mt Moon (paroi rocheuse), collision=1
W, H = 9, 11  # petite pièce
DOOR_A = (4, 9)   # bas : entrée côté A
DOOR_B = (4, 1)   # haut : sortie côté B

def build_generic_cave(name, door_a_target, door_b_target):
    """door_*_target = {"target": scene, "x":..., "y":...} — coord d'arrivée
    sur la carte de destination quand on sort par cette porte."""
    prim = PRET / "data/tilesets/primary/general"
    sec = PRET / "data/tilesets/secondary/cave"
    pals = R.load_palettes(prim, sec)
    pt = R.load_tiles(prim / "tiles.png")
    st = R.load_tiles(sec / "tiles.png")
    pm = R.load_metatiles(prim / "metatiles.bin")
    sm = R.load_metatiles(sec / "metatiles.bin")

    def get(mid):
        if mid < R.NUM_METATILES_PRIMARY:
            return pm[mid]
        return sm[mid - R.NUM_METATILES_PRIMARY]

    used = sorted({FLOOR, WALL})
    idx_of = {mid: k for k, mid in enumerate(used)}
    cols = 16
    below = Image.new("RGBA", (cols * 16, 16), (0, 0, 0, 0))
    above = Image.new("RGBA", (cols * 16, 16), (0, 0, 0, 0))
    for k, mid in enumerate(used):
        entries = get(mid)
        img = R.render_metatile(entries, pt, st, pals)
        below.paste(img, (k * 16, 0))

    cells, collision = [], []
    for y in range(H):
        for x in range(W):
            is_wall = x == 0 or x == W - 1 or y == 0 or y == H - 1
            mid = WALL if is_wall else FLOOR
            cells.append(idx_of[mid])
            collision.append(1 if is_wall else 0)

    warps = [
        {"x": DOOR_A[0], "y": DOOR_A[1], "target": door_a_target["target"],
         "tx": door_a_target["x"], "ty": door_a_target["y"], "face": "up"},
        {"x": DOOR_B[0], "y": DOOR_B[1], "target": door_b_target["target"],
         "tx": door_b_target["x"], "ty": door_b_target["y"], "face": "down"},
    ]

    OUT.mkdir(parents=True, exist_ok=True)
    below.save(OUT / f"{name}_below.png")
    above.save(OUT / f"{name}_above.png")
    data = {
        "name": name, "width": W, "height": H, "atlas_cols": cols,
        "tiles": used, "above": [False, False],
        "cells": cells, "collision": collision,
        "connections": [], "warps": warps,
        "spawn": list(DOOR_A),  # spawn par défaut si on entre sans info de warp
    }
    json.dump(data, open(OUT / f"{name}.json", "w"))
    print(f"{name}: grotte generique {W}x{H}, portes A={DOOR_A} B={DOOR_B}")

# Les 5 points de passage grotte de Kanto classique (coord. reelles pret).
# Chaque grotte relie 2 points (parfois 2 routes differentes, parfois 2
# endroits de la meme route de part et d'autre d'un obstacle).
CAVES = {
    "cave_diglett": (
        {"target": "route2", "x": 17, "y": 12},
        {"target": "route11", "x": 6, "y": 8},
    ),
    "cave_mtmoon": (
        {"target": "route4", "x": 19, "y": 6},
        {"target": "route4", "x": 32, "y": 6},
    ),
    "cave_rocktunnel": (
        {"target": "route10", "x": 8, "y": 20},
        {"target": "route10", "x": 8, "y": 58},
    ),
    "cave_seafoam": (
        {"target": "route20", "x": 60, "y": 9},
        {"target": "route20", "x": 72, "y": 15},
    ),
    "cave_victoryroad": (
        {"target": "route23", "x": 5, "y": 29},
        {"target": "route23", "x": 18, "y": 29},
    ),
}

if __name__ == "__main__":
    for name, (a, b) in CAVES.items():
        build_generic_cave(name, a, b)
