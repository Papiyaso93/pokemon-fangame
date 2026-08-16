#!/usr/bin/env python3
"""Découpe les frames utiles des bandes de sprites d'effet de combat
(pokefirered/graphics/battle_anims/sprites/*.png, bandes verticales de
frames carrées empilées) pour les animations d'attaque de
trainer_battle.gd (voir la conversation de conception avec Gus : une
animation par capacité, sourcée depuis les vrais sprites du jeu plutôt que
des formes procédurales).

Transparence par couleur clé au pixel (0,0) de chaque frame extraite (même
technique que pokeball_sparkle_*, voir battle_intro.gd) : le pixel (0,0)
n'est jamais utilisé par le dessin lui-même sur ces sprites, donc fiable
comme couleur de fond à effacer, frame par frame (le fond diffère parfois
d'une frame à l'autre dans la même bande).

Usage : python3 build_move_effects.py (depuis kanto-pipeline/, régénère
tout dans ../assets/effects/moves/).
"""
from pathlib import Path
from PIL import Image

SRC = Path(__file__).parent / "pokefirered/graphics/battle_anims/sprites"
DEST = Path(__file__).parent.parent / "assets/effects/moves"

# (fichier source, largeur de frame, hauteur de frame, index de frame) -> nom de sortie
FRAMES = [
    ("impact.png", 32, 32, 0, "impact"),
    ("scratch.png", 32, 32, 2, "scratch_1"),
    ("scratch.png", 32, 32, 4, "scratch_2"),
    ("hands_and_feet.png", 32, 32, 0, "chop_fist"),
    ("rapid_spin.png", 32, 16, 0, "rapid_spin_1"),
    ("rapid_spin.png", 32, 16, 1, "rapid_spin_2"),
    ("small_ember.png", 32, 32, 1, "ember_1"),
    ("small_ember.png", 32, 32, 2, "ember_2"),
    ("small_ember.png", 32, 32, 3, "ember_3"),
    ("water_droplet.png", 32, 32, 2, "water_droplet"),
    ("water_droplet.png", 32, 32, 4, "water_splash"),
    ("vine.png", 32, 32, 3, "vine"),
    ("leaf.png", 16, 16, 0, "leaf_1"),
    ("leaf.png", 16, 16, 3, "leaf_2"),
    ("leaf.png", 16, 16, 6, "leaf_3"),
    ("razor_leaf.png", 32, 16, 0, "razor_leaf"),
    ("rain_drops.png", 16, 16, 0, "raindrop"),
]


def extract_frame(src_path: Path, fw: int, fh: int, index: int) -> Image.Image:
    sheet = Image.open(src_path).convert("RGBA")
    box = (0, index * fh, fw, index * fh + fh)
    frame = sheet.crop(box)
    key = frame.getpixel((0, 0))
    px = frame.load()
    for y in range(fh):
        for x in range(fw):
            if px[x, y] == key:
                px[x, y] = (0, 0, 0, 0)
    return frame


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    for filename, fw, fh, index, out_name in FRAMES:
        frame = extract_frame(SRC / filename, fw, fh, index)
        out_path = DEST / f"{out_name}.png"
        frame.save(out_path)
        print(f"{out_name}.png <- {filename} frame {index}")


if __name__ == "__main__":
    main()
