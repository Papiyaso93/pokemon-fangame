#!/usr/bin/env python3
"""Génère les artefacts Godot pour une map FRLG :
  - <name>_below.png / <name>_above.png : atlas des metatiles utilisés (16px)
  - <name>.json : dimensions, mapping, grille, collision, connexions
Sortie dans le projet Godot : res://generated/
"""
import json, struct, re, sys
from pathlib import Path
from PIL import Image
import render_map as R

PRET = R.PRET
OUT = Path("/Users/gus/Desktop/pokemon-fangame/generated")
ATLAS_COLS = 16

def load_attributes(p):
    data = p.read_bytes()
    return list(struct.unpack(f"<{len(data)//4}I", data))

def render_half(entries, half, pt, st, pals):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pos = [(0, 0), (8, 0), (0, 8), (8, 8)]
    for i in range(4):
        R.render_subtile(img, pos[i][0], pos[i][1], entries[half*4+i], pt, st, pals)
    return img

def build(name, layout_dir, primary, secondary, connections, warps=None):
    prim = PRET / f"data/tilesets/primary/{primary}"
    sec = PRET / f"data/tilesets/secondary/{secondary}"
    pals = R.load_palettes(prim, sec)
    pt = R.load_tiles(prim / "tiles.png")
    st = R.load_tiles(sec / "tiles.png")
    pm = R.load_metatiles(prim / "metatiles.bin")
    sm = R.load_metatiles(sec / "metatiles.bin")
    pa = load_attributes(prim / "metatile_attributes.bin")
    sa = load_attributes(sec / "metatile_attributes.bin")

    def get(mid):
        if mid < R.NUM_METATILES_PRIMARY:
            return pm[mid], pa[mid]
        i = mid - R.NUM_METATILES_PRIMARY
        return sm[i], sa[i]

    # lire les dimensions + grille depuis la layout
    lj = json.load(open(PRET / "data/layouts/layouts.json"))
    L = next(x for x in lj["layouts"] if x and x["id"] == layout_dir)
    W, H = L["width"], L["height"]
    grid = struct.unpack(f"<{W*H}H", (PRET / L["blockdata_filepath"]).read_bytes())

    used = sorted({v & 0x3FF for v in grid})
    idx_of = {mid: k for k, mid in enumerate(used)}

    # atlas
    cols = ATLAS_COLS
    rows = (len(used) + cols - 1) // cols
    below = Image.new("RGBA", (cols*16, rows*16), (0, 0, 0, 0))
    above = Image.new("RGBA", (cols*16, rows*16), (0, 0, 0, 0))
    above_flags = []
    for k, mid in enumerate(used):
        entries, attr = get(mid)
        lt = (attr >> 29) & 0x3   # 0=NORMAL 1=COVERED 2=SPLIT
        low = render_half(entries, 0, pt, st, pals)
        high = render_half(entries, 1, pt, st, pals)
        b = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        a = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        if lt == 1:  # COVERED : tout en bas
            b.alpha_composite(low); b.alpha_composite(high)
        else:
            b.alpha_composite(low); a.alpha_composite(high)
        cx, cy = (k % cols)*16, (k // cols)*16
        below.paste(b, (cx, cy))
        above.paste(a, (cx, cy))
        above_flags.append(a.getbbox() is not None)

    OUT.mkdir(parents=True, exist_ok=True)
    below.save(OUT / f"{name}_below.png")
    above.save(OUT / f"{name}_above.png")

    cells = [idx_of[v & 0x3FF] for v in grid]
    collision = [1 if ((v >> 10) & 0x3) != 0 else 0 for v in grid]

    # Rebords (ledges) : franchissables dans un seul sens (saut de 2 cases).
    # Comportement metatile = attrs bits 0-8 (pret src/fieldmap.c). Constantes
    # dans include/constants/metatile_behaviors.h : MB_JUMP_EAST/WEST/NORTH/SOUTH.
    LEDGE_BEHAVIOR_TO_DIR = {0x38: "right", 0x39: "left", 0x3A: "up", 0x3B: "down"}
    def behavior_of(mid):
        _, attr = get(mid)
        return attr & 0x1FF
    ledges = [LEDGE_BEHAVIOR_TO_DIR.get(behavior_of(v & 0x3FF), "") for v in grid]

    # Hautes herbes : MB_TALL_GRASS = 0x02 (pret include/constants/metatile_behaviors.h).
    grass = [behavior_of(v & 0x3FF) == 0x02 for v in grid]

    data = {
        "name": name, "width": W, "height": H, "atlas_cols": cols,
        "tiles": used, "above": above_flags,
        "cells": cells, "collision": collision, "ledges": ledges, "grass": grass,
        "connections": connections, "warps": warps or [],
    }
    json.dump(data, open(OUT / f"{name}.json", "w"))
    print(f"{name}: {W}x{H}, {len(used)} metatiles, "
          f"{sum(above_flags)} avec haut, {sum(collision)} cases solides")
    print("->", OUT)

def tileset_folder(gname):
    # "gTileset_PalletTown" -> "pallet_town" ; "gTileset_GenericBuilding2" -> "generic_building_2"
    name = gname.replace("gTileset_", "")
    name = re.sub(r"(?<!^)(?=[A-Z])", "_", name)
    name = re.sub(r"(?<=[a-zA-Z])(?=[0-9])", "_", name)
    return name.lower()

def build_map(pret_map, godot_name):
    """Génère une map à partir de son nom pret (ex: 'Route1'). Déduit layout,
    tilesets et connexions automatiquement depuis les données pret."""
    mj = json.load(open(PRET / f"data/maps/{pret_map}/map.json"))
    lj = json.load(open(PRET / "data/layouts/layouts.json"))
    L = next(x for x in lj["layouts"] if x and x["id"] == mj["layout"])
    # target = nom de scène godot (ex: "MAP_ROUTE1" -> "route1")
    conns = [{"dir": c["direction"], "offset": c["offset"],
              "target": c["map"].replace("MAP_", "").lower()}
             for c in (mj.get("connections") or [])]
    build(godot_name, L["id"], tileset_folder(L["primary_tileset"]),
          tileset_folder(L["secondary_tileset"]), conns, WARP_OVERRIDES.get(godot_name))

# Warps ponctuels ajoutés à la main sur des maps déjà générées : portes vers
# les grottes génériques (build_cave.py) + accès direct Route2<->Foret de Jade
# (pas de batiment-porte, on saute directement l'etape "petit batiment vide").
# Coordonnées réelles extraites des warp_events pret (voir conversation) —
# ce sont les points d'entrée sur CETTE map, avec la cible correspondante.
WARP_OVERRIDES = {
    "route2": [
        {"x": 17, "y": 11, "target": "cave_diglett", "tx": 4, "ty": 9},
        {"x": 5, "y": 13, "target": "viridian_forest", "tx": 5, "ty": 9},
        {"x": 6, "y": 13, "target": "viridian_forest", "tx": 5, "ty": 9},
        {"x": 5, "y": 51, "target": "viridian_forest", "tx": 29, "ty": 62},
        {"x": 6, "y": 51, "target": "viridian_forest", "tx": 29, "ty": 62},
    ],
    "route11": [
        {"x": 6, "y": 7, "target": "cave_diglett", "tx": 4, "ty": 1},
    ],
    "route4": [
        {"x": 19, "y": 5, "target": "cave_mtmoon", "tx": 4, "ty": 9},
        {"x": 32, "y": 5, "target": "cave_mtmoon", "tx": 4, "ty": 1},
    ],
    "route10": [
        {"x": 8, "y": 19, "target": "cave_rocktunnel", "tx": 4, "ty": 9},
        {"x": 8, "y": 57, "target": "cave_rocktunnel", "tx": 4, "ty": 1},
    ],
    "route20": [
        {"x": 60, "y": 8, "target": "cave_seafoam", "tx": 4, "ty": 9},
        {"x": 72, "y": 14, "target": "cave_seafoam", "tx": 4, "ty": 1},
    ],
    "route23": [
        {"x": 5, "y": 28, "target": "cave_victoryroad", "tx": 4, "ty": 9},
        {"x": 18, "y": 28, "target": "cave_victoryroad", "tx": 4, "ty": 1},
    ],
    "viridian_forest": [
        {"x": 5, "y": 9, "target": "route2", "tx": 5, "ty": 12},
        {"x": 6, "y": 9, "target": "route2", "tx": 5, "ty": 12},
        {"x": 29, "y": 62, "target": "route2", "tx": 5, "ty": 52},
        {"x": 30, "y": 62, "target": "route2", "tx": 5, "ty": 52},
    ],
    # Portes de Safrania : accès direct route<->ville, sans batiment-porte
    # (meme principe que la Foret de Jade). Coord. reelles pret.
    "route5": [
        {"x": 24, "y": 32, "target": "saffron_city", "tx": 34, "ty": 6},
        {"x": 25, "y": 32, "target": "saffron_city", "tx": 35, "ty": 6},
    ],
    "route6": [
        {"x": 12, "y": 5, "target": "saffron_city", "tx": 34, "ty": 45},
        {"x": 13, "y": 5, "target": "saffron_city", "tx": 35, "ty": 45},
    ],
    "route7": [
        {"x": 15, "y": 10, "target": "saffron_city", "tx": 9, "ty": 27},
    ],
    "route8": [
        {"x": 7, "y": 10, "target": "saffron_city", "tx": 57, "ty": 27},
    ],
    "saffron_city": [
        {"x": 34, "y": 5, "target": "route5", "tx": 24, "ty": 31},
        {"x": 35, "y": 5, "target": "route5", "tx": 25, "ty": 31},
        {"x": 34, "y": 46, "target": "route6", "tx": 12, "ty": 6},
        {"x": 35, "y": 46, "target": "route6", "tx": 13, "ty": 6},
        {"x": 8, "y": 27, "target": "route7", "tx": 14, "ty": 10},
        {"x": 58, "y": 27, "target": "route8", "tx": 8, "ty": 10},
    ],
    # Intro : le joueur démarre directement dans safari_entrance (bâtiment
    # d'Entrée réel de la Zone Safari à Parmanie). Coordonnées réelles pret.
    "safari_office": [
        {"x": 5, "y": 9, "target": "fuchsia_city", "tx": 28, "ty": 17},
        {"x": 6, "y": 9, "target": "fuchsia_city", "tx": 28, "ty": 17},
        {"x": 7, "y": 9, "target": "fuchsia_city", "tx": 28, "ty": 17},
    ],
    "safari_entrance": [
        {"x": 4, "y": 1, "target": "safari_zone_center", "tx": 26, "ty": 30},
        {"x": 3, "y": 7, "target": "fuchsia_city", "tx": 24, "ty": 6},
        {"x": 4, "y": 7, "target": "fuchsia_city", "tx": 24, "ty": 6},
        {"x": 5, "y": 7, "target": "fuchsia_city", "tx": 24, "ty": 6},
    ],
    "fuchsia_city": [
        {"x": 24, "y": 5, "target": "safari_entrance", "tx": 4, "ty": 7},
        {"x": 28, "y": 16, "target": "safari_office", "tx": 6, "ty": 9},
    ],
    # Zone Safari : 4 sous-cartes reliées entre elles (Center = carrefour) +
    # une maison de repos par sous-carte. Coordonnées réelles extraites des
    # warp_events pret (kanto-pipeline/pokefirered/data/maps/SafariZone_*/map.json),
    # validées en jeu par Gus le 12/07/2026 (testées case par case).
    "safari_zone_center": [
        {"x": 25, "y": 30, "target": "safari_entrance", "tx": 4, "ty": 2},
        {"x": 26, "y": 30, "target": "safari_entrance", "tx": 4, "ty": 2},
        {"x": 27, "y": 30, "target": "safari_entrance", "tx": 4, "ty": 2},
        {"x": 25, "y": 5, "target": "safari_zone_north", "tx": 30, "ty": 34},
        {"x": 26, "y": 5, "target": "safari_zone_north", "tx": 31, "ty": 34},
        {"x": 27, "y": 5, "target": "safari_zone_north", "tx": 32, "ty": 34},
        {"x": 8, "y": 17, "target": "safari_zone_west", "tx": 40, "ty": 26},
        {"x": 8, "y": 18, "target": "safari_zone_west", "tx": 40, "ty": 27},
        {"x": 8, "y": 19, "target": "safari_zone_west", "tx": 40, "ty": 28},
        {"x": 43, "y": 15, "target": "safari_zone_east", "tx": 8, "ty": 26},
        {"x": 43, "y": 16, "target": "safari_zone_east", "tx": 8, "ty": 27},
        {"x": 43, "y": 17, "target": "safari_zone_east", "tx": 8, "ty": 28},
        {"x": 29, "y": 25, "target": "safari_rest_house_center", "tx": 4, "ty": 9},
    ],
    "safari_zone_east": [
        {"x": 8, "y": 9, "target": "safari_zone_north", "tx": 48, "ty": 31},
        {"x": 8, "y": 10, "target": "safari_zone_north", "tx": 48, "ty": 32},
        {"x": 8, "y": 11, "target": "safari_zone_north", "tx": 48, "ty": 33},
        {"x": 8, "y": 26, "target": "safari_zone_center", "tx": 43, "ty": 15},
        {"x": 8, "y": 27, "target": "safari_zone_center", "tx": 43, "ty": 16},
        {"x": 8, "y": 28, "target": "safari_zone_center", "tx": 43, "ty": 17},
        {"x": 40, "y": 14, "target": "safari_rest_house_east", "tx": 4, "ty": 9},
    ],
    "safari_zone_north": [
        {"x": 10, "y": 34, "target": "safari_zone_west", "tx": 30, "ty": 5},
        {"x": 11, "y": 34, "target": "safari_zone_west", "tx": 31, "ty": 5},
        {"x": 12, "y": 34, "target": "safari_zone_west", "tx": 32, "ty": 5},
        {"x": 20, "y": 34, "target": "safari_zone_west", "tx": 37, "ty": 5},
        {"x": 21, "y": 34, "target": "safari_zone_west", "tx": 38, "ty": 5},
        {"x": 22, "y": 34, "target": "safari_zone_west", "tx": 39, "ty": 5},
        {"x": 48, "y": 31, "target": "safari_zone_east", "tx": 8, "ty": 9},
        {"x": 48, "y": 32, "target": "safari_zone_east", "tx": 8, "ty": 10},
        {"x": 48, "y": 33, "target": "safari_zone_east", "tx": 8, "ty": 11},
        {"x": 30, "y": 34, "target": "safari_zone_center", "tx": 25, "ty": 5},
        {"x": 31, "y": 34, "target": "safari_zone_center", "tx": 26, "ty": 5},
        {"x": 32, "y": 34, "target": "safari_zone_center", "tx": 27, "ty": 5},
        {"x": 43, "y": 8, "target": "safari_rest_house_north", "tx": 4, "ty": 9},
    ],
    "safari_zone_west": [
        {"x": 30, "y": 5, "target": "safari_zone_north", "tx": 10, "ty": 34},
        {"x": 31, "y": 5, "target": "safari_zone_north", "tx": 11, "ty": 34},
        {"x": 32, "y": 5, "target": "safari_zone_north", "tx": 12, "ty": 34},
        {"x": 37, "y": 5, "target": "safari_zone_north", "tx": 20, "ty": 34},
        {"x": 38, "y": 5, "target": "safari_zone_north", "tx": 21, "ty": 34},
        {"x": 39, "y": 5, "target": "safari_zone_north", "tx": 22, "ty": 34},
        {"x": 40, "y": 26, "target": "safari_zone_center", "tx": 8, "ty": 17},
        {"x": 40, "y": 27, "target": "safari_zone_center", "tx": 8, "ty": 18},
        {"x": 40, "y": 28, "target": "safari_zone_center", "tx": 8, "ty": 19},
        {"x": 12, "y": 7, "target": "safari_secret_house", "tx": 4, "ty": 9},
        {"x": 19, "y": 18, "target": "safari_rest_house_west", "tx": 4, "ty": 9},
    ],
    "safari_rest_house_center": [
        {"x": 3, "y": 9, "target": "safari_zone_center", "tx": 29, "ty": 26},
        {"x": 4, "y": 9, "target": "safari_zone_center", "tx": 29, "ty": 26},
        {"x": 5, "y": 9, "target": "safari_zone_center", "tx": 29, "ty": 26},
    ],
    "safari_rest_house_east": [
        {"x": 3, "y": 9, "target": "safari_zone_east", "tx": 40, "ty": 15},
        {"x": 4, "y": 9, "target": "safari_zone_east", "tx": 40, "ty": 15},
        {"x": 5, "y": 9, "target": "safari_zone_east", "tx": 40, "ty": 15},
    ],
    "safari_rest_house_north": [
        {"x": 3, "y": 9, "target": "safari_zone_north", "tx": 43, "ty": 9},
        {"x": 4, "y": 9, "target": "safari_zone_north", "tx": 43, "ty": 9},
        {"x": 5, "y": 9, "target": "safari_zone_north", "tx": 43, "ty": 9},
    ],
    "safari_rest_house_west": [
        {"x": 3, "y": 9, "target": "safari_zone_west", "tx": 19, "ty": 19},
        {"x": 4, "y": 9, "target": "safari_zone_west", "tx": 19, "ty": 19},
        {"x": 5, "y": 9, "target": "safari_zone_west", "tx": 19, "ty": 19},
    ],
    # Zone Safari Ouest : la Maison secrète (item rare dans le vrai jeu, pas
    # encore intégrée à notre histoire). Warp posé pour être complet/fidèle,
    # contenu (PNJ/objet) pas encore décidé.
    "safari_secret_house": [
        {"x": 3, "y": 9, "target": "safari_zone_west", "tx": 12, "ty": 8},
        {"x": 4, "y": 9, "target": "safari_zone_west", "tx": 12, "ty": 8},
        {"x": 5, "y": 9, "target": "safari_zone_west", "tx": 12, "ty": 8},
    ],
}

# Table nom-pret -> nom-godot (snake_case) pour les maps à générer.
# Kanto classique (villes + routes), îles Sevii et grottes exclues pour l'instant.
MAPS = {
    "CeladonCity": "celadon_city",
    "CeruleanCity": "cerulean_city",
    "CinnabarIsland": "cinnabar_island",
    "FuchsiaCity": "fuchsia_city",
    "IndigoPlateau_Exterior": "indigo_plateau_exterior",
    "LavenderTown": "lavender_town",
    "PalletTown": "pallet_town",
    "PewterCity": "pewter_city",
    "Route1": "route1",
    "Route10": "route10",
    "Route11": "route11",
    "Route12": "route12",
    "Route13": "route13",
    "Route14": "route14",
    "Route15": "route15",
    "Route16": "route16",
    "Route17": "route17",
    "Route18": "route18",
    "Route19": "route19",
    "Route2": "route2",
    "Route20": "route20",
    "Route21_North": "route21_north",
    "Route21_South": "route21_south",
    "Route22": "route22",
    "Route23": "route23",
    "Route24": "route24",
    "Route25": "route25",
    "Route3": "route3",
    "Route4": "route4",
    "Route5": "route5",
    "Route6": "route6",
    "Route7": "route7",
    "Route8": "route8",
    "Route9": "route9",
    "SafariZone_Center": "safari_zone_center",
    "SafariZone_East": "safari_zone_east",
    "SafariZone_North": "safari_zone_north",
    "SafariZone_West": "safari_zone_west",
    "SaffronCity": "saffron_city",
    "SaffronCity_Connection": "saffron_city_connection",
    "VermilionCity": "vermilion_city",
    "ViridianCity": "viridian_city",
    "ViridianForest": "viridian_forest",
    # Intro : vrais bâtiments Zone Safari (Parmanie).
    "FuchsiaCity_SafariZone_Office": "safari_office",
    "FuchsiaCity_SafariZone_Entrance": "safari_entrance",
    # Maisons de repos du Parc Safari (une par sous-zone) + Maison secrète.
    "SafariZone_Center_RestHouse": "safari_rest_house_center",
    "SafariZone_East_RestHouse": "safari_rest_house_east",
    "SafariZone_North_RestHouse": "safari_rest_house_north",
    "SafariZone_West_RestHouse": "safari_rest_house_west",
    "SafariZone_SecretHouse": "safari_secret_house",
}

if __name__ == "__main__":
    targets = sys.argv[1:] or list(MAPS.keys())
    for pret_name in targets:
        build_map(pret_name, MAPS.get(pret_name, pret_name.lower()))
