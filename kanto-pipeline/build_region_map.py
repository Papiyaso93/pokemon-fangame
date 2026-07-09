#!/usr/bin/env python3
"""Décode la vraie carte de Kanto du Town Map FRLG (tileset region_map.png +
tilemap kanto.bin, format GBA standard : tile_id (bits 0-9) | flipX(10) |
flipY(11) | palette(12-15)) en une image composée, sans les Iles Sevii
(kanto.bin ne contient que Kanto, contrairement à sevii_*.bin séparés).
Résolution native confirmée : 30x20 tuiles = 240x160px = un écran GBA exact.

Vrai bug trouvé et corrigé (pas un calque manquant, cf. HANDOFF.md) :
region_map.png stocke les pixels en index GLOBAUX 0-79 (5 palettes de 16
couleurs mises bout à bout dans le PNG), pas en index local 0-15. Il faut
prendre `v & 0xF` (les 4 bits bas, la vraie valeur GBA 4bpp) avant de
chercher la couleur dans la palette sélectionnée par la tuile — sinon tout
pixel avec un index >= 16 (typiquement les tuiles de chemin) était rejeté et
laissé transparent. Une fois ce fix appliqué, kanto.bin seul suffit : plus
aucun trou, plus besoin de background.bin (qui n'est de toute façon pas
utilisé par le vrai jeu pour l'écran de carte normal — vérifié dans
src/region_map.c, LoadRegionMapGfx : le calque background.4bpp/.bin n'est
chargé que si `type != REGIONMAP_TYPE_NORMAL`, càd pour l'écran Voler/switch
uniquement, jamais pour la vraie Carte de Kanto).
"""
import struct
from pathlib import Path
from PIL import Image

PRET = Path(__file__).parent / "pokefirered" / "graphics" / "region_map"
OUT = Path(__file__).parent.parent / "assets" / "ui" / "region_map.png"

W, H = 30, 20
GRID_COLS, GRID_ROWS = 22, 15   # grille de sections MAPSEC (RegionMapData.gd)
SECTION_TILE = 8                # 1 case de section = 8x8px sur le canvas natif
CROP = (36, 36, 36 + GRID_COLS * SECTION_TILE, 36 + GRID_ROWS * SECTION_TILE)
SCALE = 3


def load_pal(path):
    lines = path.read_text().splitlines()
    n = int(lines[2])
    colors = [tuple(map(int, ln.split())) for ln in lines[3:3 + n]]
    return [colors[i:i + 16] for i in range(0, len(colors), 16)]


def load_tiles(png_path):
    im = Image.open(png_path).convert("P")
    w, h = im.size
    cols, rows = w // 8, h // 8
    px = im.load()
    tiles = []
    for ty in range(rows):
        for tx in range(cols):
            tiles.append([[px[tx * 8 + x, ty * 8 + y] for x in range(8)] for y in range(8)])
    return tiles


def render_layer(entries, tiles, pals, base):
    """Peint les tuiles de `entries` sur `base` (index local 0 = transparent,
    ne peint rien pour laisser voir la couche déjà présente en dessous)."""
    for i, e in enumerate(entries):
        tx, ty = i % W, i // W
        tid = e & 0x3FF
        flip_x, flip_y = bool(e & 0x400), bool(e & 0x800)
        pal = pals[(e >> 12) & 0xF]
        tile = tiles[tid]
        ox, oy = tx * 8, ty * 8
        for y in range(8):
            sy = 7 - y if flip_y else y
            for x in range(8):
                sx = 7 - x if flip_x else x
                v = tile[sy][sx] & 0xF  # index LOCAL 4bpp (voir docstring)
                if v == 0:
                    continue
                base.putpixel((ox + x, oy + y), (*pal[v], 255))


def main():
    pals = load_pal(PRET / "region_map.pal")
    tiles = load_tiles(PRET / "region_map.png")

    def read_entries(name):
        data = (PRET / name).read_bytes()
        return struct.unpack("<%dH" % (len(data) // 2), data)

    img = Image.new("RGBA", (W * 8, H * 8), (0, 0, 0, 0))
    render_layer(read_entries("kanto.bin"), tiles, pals, img)

    # Le canvas 240x160 déborde d'une bordure décorative hors-écran (visible
    # dans src/region_map.c : sprite->x = 8*col + 36 pour le curseur —
    # confirme que la grille de sections 22x15 démarre à (36,36)px, pas à
    # (0,0)). On recadre pile sur cette zone : la grille de sections devient
    # alors exactement alignée 8px/case, plus besoin de décalage particulier
    # pour positionner une icône dessus (simple fraction col/22, row/15).
    img = img.crop(CROP)

    img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"Sauvé : {OUT} ({img.size[0]}x{img.size[1]}, x{SCALE})")


if __name__ == "__main__":
    main()
