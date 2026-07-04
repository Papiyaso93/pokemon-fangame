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

def build(name, layout_dir, primary, secondary, connections):
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

    data = {
        "name": name, "width": W, "height": H, "atlas_cols": cols,
        "tiles": used, "above": above_flags,
        "cells": cells, "collision": collision,
        "connections": connections,
    }
    json.dump(data, open(OUT / f"{name}.json", "w"))
    print(f"{name}: {W}x{H}, {len(used)} metatiles, "
          f"{sum(above_flags)} avec haut, {sum(collision)} cases solides")
    print("->", OUT)

def tileset_folder(gname):
    # "gTileset_PalletTown" -> "pallet_town"
    name = gname.replace("gTileset_", "")
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

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
          tileset_folder(L["secondary_tileset"]), conns)

# Table nom-pret -> nom-godot (snake_case) pour les maps à générer.
MAPS = {
    "PalletTown": "pallet_town",
    "Route1": "route1",
}

if __name__ == "__main__":
    targets = sys.argv[1:] or list(MAPS.keys())
    for pret_name in targets:
        build_map(pret_name, MAPS.get(pret_name, pret_name.lower()))
