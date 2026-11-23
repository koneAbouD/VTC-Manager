"""Génère le logo « TMK Immobilier » à partir du logo TMK d'origine.

Le logo TMK n'est pas redessiné : ses pixels sont repris tels quels depuis
mobile/assets/images/logo_tmk.png. Seul le badge immeuble est dessiné ici.

Usage : python3 build_logo.py
Sorties : tmk_immobilier_icon_1024.png, tmk_immobilier_horizontal.png
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parents[1] / "mobile/assets/images/logo_tmk.png"

# Géométrie mesurée sur logo_tmk.png (1109×613) : texte TMK x 18→962.
TEXT_WIDTH = 962 - 18
BADGE_D = round(TEXT_WIDTH * 0.30)          # ≈ 283 px, liseré compris
BADGE_CENTER = (838, 628)                   # sous le K, sur la fin de l'arc

GREEN_TOP = (0x34, 0xD3, 0x78)
GREEN_BOTTOM = (0x12, 0x8C, 0x48)
SS = 4                                      # suréchantillonnage anti-aliasing


def clean_source() -> Image.Image:
    """Logo d'origine en RGBA, fond quasi-blanc rendu transparent."""
    im = Image.open(SOURCE).convert("RGB")
    # alpha = « distance au blanc » : préserve les bords anti-aliasés.
    r, g, b = im.split()
    darkest = ImageChops.darker(ImageChops.darker(r, g), b)
    alpha = darkest.point(lambda v: 0 if v > 242 else min(255, int((255 - v) * 255 / 60)))
    out = im.copy()
    out.putalpha(alpha)
    return out


def vertical_gradient(size: int, top, bottom) -> Image.Image:
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        grad.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return grad.resize((size, size))


def draw_badge() -> Image.Image:
    """Badge (avec marge pour l'ombre) en RGBA, à la taille finale."""
    d = BADGE_D * SS
    pad = int(d * 0.25)
    canvas = d + 2 * pad
    c0 = pad  # coin haut-gauche du disque
    badge = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))

    # Ombre portée douce vers le bas.
    shadow = Image.new("L", (canvas, canvas), 0)
    off = int(d * 0.045)
    ImageDraw.Draw(shadow).ellipse((c0, c0 + off, c0 + d, c0 + d + off), fill=95)
    shadow = shadow.filter(ImageFilter.GaussianBlur(d * 0.045))
    badge.paste(Image.new("RGBA", (canvas, canvas), (10, 60, 30, 255)), (0, 0), shadow)

    # Liseré blanc épais.
    ring = int(d * 0.075)
    disc = Image.new("L", (canvas, canvas), 0)
    ImageDraw.Draw(disc).ellipse((c0, c0, c0 + d, c0 + d), fill=255)
    badge.paste((255, 255, 255, 255), (0, 0), disc)

    # Disque intérieur en dégradé vertical.
    inner_d = d - 2 * ring
    i0 = c0 + ring
    inner_mask = Image.new("L", (canvas, canvas), 0)
    ImageDraw.Draw(inner_mask).ellipse((i0, i0, i0 + inner_d, i0 + inner_d), fill=255)
    grad = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    grad.paste(vertical_gradient(inner_d, GREEN_TOP, GREEN_BOTTOM), (i0, i0))
    badge.paste(grad, (0, 0), inner_mask)

    # Reflet brillant en haut : ellipse blanche qui s'estompe vers le bas.
    gloss_alpha = Image.new("L", (canvas, canvas), 0)
    gw, gh = inner_d * 0.78, inner_d * 0.46
    gx0 = i0 + (inner_d - gw) / 2
    gy0 = i0 + inner_d * 0.03
    ImageDraw.Draw(gloss_alpha).ellipse((gx0, gy0, gx0 + gw, gy0 + gh), fill=255)
    fade = Image.new("L", (1, canvas), 0)
    for y in range(canvas):
        t = (y - gy0) / gh
        fade.putpixel((0, y), max(0, min(255, int(85 * (1 - t) ** 1.6))) if 0 <= t <= 1 else 0)
    fade = fade.resize((canvas, canvas))
    gloss_alpha = ImageChops.multiply(ImageChops.multiply(gloss_alpha, fade), inner_mask)
    gloss_alpha = gloss_alpha.filter(ImageFilter.GaussianBlur(d * 0.01))
    badge.paste((255, 255, 255, 255), (0, 0), gloss_alpha)

    # Pictogramme immeuble : silhouette blanche, fenêtres/porte découpées.
    u = inner_d / 100.0                      # unité relative au disque intérieur
    ox, oy = i0, i0
    def box(x0, y0, x1, y1):
        return (ox + x0 * u, oy + y0 * u, ox + x1 * u, oy + y1 * u)

    ground = 78
    tower = (25, 19, 56, ground)
    annex = (56, 42, 76, ground)
    bld = Image.new("L", (canvas, canvas), 0)
    dr = ImageDraw.Draw(bld)
    dr.rectangle(box(*tower), fill=255)
    dr.rectangle(box(*annex), fill=255)
    # Fenêtres de la tour : 2 colonnes × 4 rangées.
    win = 7.0
    cols = [30.5, 43.5]
    rows = [25, 35.5, 46]
    for x in cols:
        for y in rows:
            dr.rectangle(box(x, y, x + win, y + win), fill=0)
    # Porte centrée en bas de la tour.
    dr.rectangle(box(36, 60, 45, ground), fill=0)
    # Fenêtres de l'annexe : 1 colonne × 2 rangées.
    for y in (49, 61):
        dr.rectangle(box(62.5, y, 62.5 + win, y + win), fill=0)
    badge.paste((255, 255, 255, 255), (0, 0), bld)

    final = canvas // SS
    return badge.resize((final, final), Image.LANCZOS), pad // SS


def compose() -> Image.Image:
    logo = clean_source()
    badge, pad = draw_badge()
    bx = BADGE_CENTER[0] - BADGE_D // 2 - pad
    by = BADGE_CENTER[1] - BADGE_D // 2 - pad
    w = max(logo.width, bx + badge.width)
    h = max(logo.height, by + badge.height)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(logo, (0, 0))
    out.alpha_composite(badge, (bx, by))
    return out.crop(out.getbbox())


def on_white(im: Image.Image, size, offset) -> Image.Image:
    bg = Image.new("RGBA", size, (255, 255, 255, 255))
    bg.alpha_composite(im, offset)
    return bg.convert("RGB")


def main():
    mark = compose()

    # 1. Icône carrée 1024 : logo ≈ 84 % de la largeur, centré.
    target_w = round(1024 * 0.84)
    scale = target_w / mark.width
    scaled = mark.resize((target_w, round(mark.height * scale)), Image.LANCZOS)
    icon = on_white(scaled, (1024, 1024), ((1024 - scaled.width) // 2, (1024 - scaled.height) // 2))
    icon.save(HERE / "tmk_immobilier_icon_1024.png", optimize=True)

    # 2. Version horizontale, taille native, marge blanche ≈ 12 % de la largeur.
    m = round(mark.width * 0.12)
    horiz = on_white(mark, (mark.width + 2 * m, mark.height + 2 * m), (m, m))
    horiz.save(HERE / "tmk_immobilier_horizontal.png", optimize=True)
    print("icon", icon.size, "horizontal", horiz.size)


if __name__ == "__main__":
    main()
