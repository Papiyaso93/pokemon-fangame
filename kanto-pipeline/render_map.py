#!/usr/bin/env python3
"""PoC : rend une map FRLG (pret) en une image PNG, en compositant les metatiles.
But : valider le parsing metatiles/tiles/palettes AVANT de générer du Godot.
"""
import struct
from pathlib import Path
from PIL import Image

PRET = Path(__file__).parent / "pokefirered"
NUM_METATILES_PRIMARY = 640
NUM_TILES_PRIMARY = 640
NUM_PALS_PRIMARY = 7

def load_palettes(primary_dir, secondary_dir):
    """16 palettes de 16 couleurs. Slots 0-6 = primaire, 7-15 = secondaire."""
    pals = []
    for i in range(16):
        src = primary_dir if i < NUM_PALS_PRIMARY else secondary_dir
        lines = (src / "palettes" / f"{i:02d}.pal").read_text().splitlines()
        # JASC-PAL : 3 lignes d'entête puis 16 "R G B"
        colors = []
        for ln in lines[3:3+16]:
            r, g, b = map(int, ln.split())
            colors.append((r, g, b))
        pals.append(colors)
    return pals

def load_tiles(png_path):
    """Retourne la liste des tuiles 8x8 en indices (0-15), depuis un PNG indexé."""
    im = Image.open(png_path).convert("P")
    w, h = im.size
    cols = w // 8
    tiles = []
    px = im.load()
    for ty in range(h // 8):
        for tx in range(cols):
            t = [[px[tx*8+x, ty*8+y] for x in range(8)] for y in range(8)]
            tiles.append(t)
    return tiles

def get_tile(tid, prim_tiles, sec_tiles):
    if tid < NUM_TILES_PRIMARY:
        return prim_tiles[tid] if tid < len(prim_tiles) else None
    idx = tid - NUM_TILES_PRIMARY
    return sec_tiles[idx] if idx < len(sec_tiles) else None

def load_metatiles(bin_path):
    data = bin_path.read_bytes()
    n = len(data) // 16
    metas = []
    for m in range(n):
        entries = struct.unpack_from("<8H", data, m*16)
        metas.append(entries)  # 8 x uint16
    return metas

def render_subtile(dst, ox, oy, entry, prim_tiles, sec_tiles, pals):
    tid = entry & 0x3FF
    flip_x = bool(entry & 0x400)
    flip_y = bool(entry & 0x800)
    pal = (entry >> 12) & 0xF
    tile = get_tile(tid, prim_tiles, sec_tiles)
    if tile is None:
        return
    palette = pals[pal]
    for y in range(8):
        sy = 7 - y if flip_y else y
        for x in range(8):
            sx = 7 - x if flip_x else x
            v = tile[sy][sx]
            if v == 0:
                continue  # index 0 = transparent
            dst.putpixel((ox + x, oy + y), palette[v])

def render_metatile(entries, prim_tiles, sec_tiles, pals):
    """16x16 RGBA. Tiles 0-3 = couche bas, 4-7 = couche haut. Ordre 2x2."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pos = [(0, 0), (8, 0), (0, 8), (8, 8)]
    for half in range(2):           # 0 = bas, 1 = haut
        for i in range(4):
            e = entries[half*4 + i]
            ox, oy = pos[i]
            render_subtile(img, ox, oy, e, prim_tiles, sec_tiles, pals)
    return img

def main():
    prim = PRET / "data/tilesets/primary/general"
    sec = PRET / "data/tilesets/secondary/pallet_town"
    pals = load_palettes(prim, sec)
    prim_tiles = load_tiles(prim / "tiles.png")
    sec_tiles = load_tiles(sec / "tiles.png")
    prim_meta = load_metatiles(prim / "metatiles.bin")
    sec_meta = load_metatiles(sec / "metatiles.bin")
    print(f"tuiles: {len(prim_tiles)} prim / {len(sec_tiles)} sec")
    print(f"metatiles: {len(prim_meta)} prim / {len(sec_meta)} sec")

    # cache de rendu par metatile id
    cache = {}
    def meta_img(mid):
        if mid in cache:
            return cache[mid]
        if mid < NUM_METATILES_PRIMARY:
            entries = prim_meta[mid] if mid < len(prim_meta) else None
        else:
            idx = mid - NUM_METATILES_PRIMARY
            entries = sec_meta[idx] if idx < len(sec_meta) else None
        img = render_metatile(entries, prim_tiles, sec_tiles, pals) if entries else Image.new("RGBA", (16,16))
        cache[mid] = img
        return img

    # parse map.bin
    W, H = 24, 20
    blocks = (PRET / "data/layouts/PalletTown/map.bin").read_bytes()
    grid = struct.unpack(f"<{W*H}H", blocks)

    out = Image.new("RGBA", (W*16, H*16), (0, 0, 0, 255))
    for i, v in enumerate(grid):
        mid = v & 0x3FF
        cx, cy = (i % W) * 16, (i // W) * 16
        out.alpha_composite(meta_img(mid), (cx, cy))

    out_path = Path(__file__).parent / "pallet_render.png"
    out.save(out_path)
    print("rendu ->", out_path, out.size)

if __name__ == "__main__":
    main()
