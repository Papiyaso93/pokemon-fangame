#!/usr/bin/env python3
"""Découpe chaque metatile en 2 images : BAS (sous le joueur) et HAUT (au-dessus).
Règle (layer type, bits 29-30 des attributs) :
  NORMAL(0)/SPLIT(2) -> bas = moitié basse, haut = moitié haute
  COVERED(1)         -> bas = les deux moitiés, haut = vide
Produit un atlas 'below' et un atlas 'above' pour vérifier visuellement le split.
"""
import struct
from pathlib import Path
from PIL import Image
import render_map as R  # réutilise le moteur de rendu validé

PRET = R.PRET

def load_attributes(bin_path):
    data = bin_path.read_bytes()
    n = len(data) // 4
    return list(struct.unpack(f"<{n}I", data))  # uint32 par metatile (FRLG)

def layer_type(attr):
    return (attr >> 29) & 0x3  # 0=NORMAL 1=COVERED 2=SPLIT

def render_half(entries, half, prim_tiles, sec_tiles, pals):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pos = [(0, 0), (8, 0), (0, 8), (8, 8)]
    for i in range(4):
        R.render_subtile(img, pos[i][0], pos[i][1], entries[half*4 + i],
                         prim_tiles, sec_tiles, pals)
    return img

def main():
    prim = PRET / "data/tilesets/primary/general"
    sec = PRET / "data/tilesets/secondary/pallet_town"
    pals = R.load_palettes(prim, sec)
    prim_tiles = R.load_tiles(prim / "tiles.png")
    sec_tiles = R.load_tiles(sec / "tiles.png")
    prim_meta = R.load_metatiles(prim / "metatiles.bin")
    sec_meta = R.load_metatiles(sec / "metatiles.bin")
    prim_attr = load_attributes(prim / "metatile_attributes.bin")
    sec_attr = load_attributes(sec / "metatile_attributes.bin")

    def get(mid):
        if mid < R.NUM_METATILES_PRIMARY:
            return prim_meta[mid], prim_attr[mid]
        idx = mid - R.NUM_METATILES_PRIMARY
        return sec_meta[idx], sec_attr[idx]

    # metatiles réellement utilisés dans Pallet Town
    W, H = 24, 20
    grid = struct.unpack(f"<{W*H}H", (PRET / "data/layouts/PalletTown/map.bin").read_bytes())
    used = sorted({v & 0x3FF for v in grid})
    print(f"{len(used)} metatiles utilisés dans Pallet Town")

    # construit les images bas/haut par metatile
    below, above = {}, {}
    n_above = 0
    for mid in used:
        entries, attr = get(mid)
        lt = layer_type(attr)
        b = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        a = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        low = render_half(entries, 0, prim_tiles, sec_tiles, pals)
        high = render_half(entries, 1, prim_tiles, sec_tiles, pals)
        if lt == 1:  # COVERED : tout en bas
            b.alpha_composite(low); b.alpha_composite(high)
        else:        # NORMAL / SPLIT
            b.alpha_composite(low)
            a.alpha_composite(high)
        below[mid], above[mid] = b, a
        if a.getbbox():
            n_above += 1
    print(f"{n_above} metatiles ont une partie HAUTE (au-dessus du joueur)")

    # atlas de contrôle : une grille, bas à gauche / haut à droite côte à côte
    cols = 16
    rows = (len(used) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols*16, rows*16*2 + rows), (40, 40, 40, 255))
    for k, mid in enumerate(used):
        cx = (k % cols) * 16
        cy = (k // cols) * (16*2 + 1)
        sheet.alpha_composite(below[mid], (cx, cy))
        sheet.alpha_composite(above[mid], (cx, cy + 16))
    out = Path(__file__).parent / "atlas_split_check.png"
    sheet.save(out)
    print("controle ->", out, "(chaque colonne: bas en haut, haut en bas)")

    # rendu map en 2 couches séparées pour valider la perspective
    mapb = Image.new("RGBA", (W*16, H*16), (0, 0, 0, 255))
    mapa = Image.new("RGBA", (W*16, H*16), (90, 90, 90, 255))
    for i, v in enumerate(grid):
        mid = v & 0x3FF
        cx, cy = (i % W) * 16, (i // W) * 16
        mapb.alpha_composite(below[mid], (cx, cy))
        mapa.alpha_composite(above[mid], (cx, cy))
    mapb.save(Path(__file__).parent / "map_below.png")
    mapa.save(Path(__file__).parent / "map_above.png")
    print("map_below.png / map_above.png generes")

if __name__ == "__main__":
    main()
