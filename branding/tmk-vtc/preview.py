"""Planche de comparaison des pictogrammes : python3 preview.py <sortie.png>"""
import sys
from PIL import Image, ImageDraw, ImageFont
from build_logo import SRC_DIR, find_inner_disc, paint_badge
from pictos import VARIANTS

src = Image.open(SRC_DIR / "logo_tmk_icon.png")
cx, cy, r = find_inner_disc(src.convert("RGBA"), (832, 646))
cell, pad = 460, 30
sheet = Image.new("RGB", (cell * len(VARIANTS) + pad, cell + 260), "white")
d = ImageDraw.Draw(sheet)
font = ImageFont.load_default(size=34)
for i, (name, fn) in enumerate(VARIANTS.items()):
    out = paint_badge(src, cx, cy, r, fn)
    zoom = out.crop((int(cx - 105), int(cy - 105), int(cx + 105), int(cy + 105))).resize((cell - pad, cell - pad), Image.LANCZOS)
    x = pad + i * cell
    sheet.paste(zoom, (x, pad))
    small = out.resize((180, 180), Image.LANCZOS)
    sheet.paste(small, (x + 20, cell + 20))
    d.text((x + 220, cell + 90), name.split("_", 1)[0], fill=(40, 40, 40), font=font)
    d.text((x + 220, cell + 130), name.split("_", 1)[1], fill=(120, 120, 120), font=font)
sheet.save(sys.argv[1])
