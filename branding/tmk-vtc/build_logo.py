"""Génère le logo « TMK VTC » à partir du logo « TMK Immobilier ».

Même modèle : on reprend les PNG Immobilier tels quels, on repeint uniquement
le disque vert intérieur du badge (dégradé + reflet) et on remplace le
pictogramme immeuble par une voiture blanche vue de face.

Usage : python3 build_logo.py
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
SRC_DIR = HERE.parents[2] / "Imobilier Manager/mobile/assets/images"

# fichier -> centre approximatif du badge (affiné automatiquement)
SOURCES = {
    "logo_tmk_icon.png": (832, 646),
    "logo_tmk_icon_foreground.png": (832, 646),
    "logo_tmk.png": (1025, 543),
}

GREEN_TOP = (0x34, 0xD3, 0x78)
GREEN_BOTTOM = (0x12, 0x8C, 0x48)
SS = 4


def is_green(p):
    return p[3] > 128 and p[1] > p[0] + 50 and p[1] > p[2] + 20 if len(p) == 4 else \
        p[1] > p[0] + 50 and p[1] > p[2] + 20


def fit_circle(pts):
    """Cercle par moindres carrés (méthode de Kåsa), sans numpy."""
    # x² + y² + D x + E y + F = 0
    s = [[0.0] * 4 for _ in range(3)]
    for x, y in pts:
        row = (x, y, 1.0)
        rhs = -(x * x + y * y)
        for i in range(3):
            for j in range(3):
                s[i][j] += row[i] * row[j]
            s[i][3] += row[i] * rhs
    for i in range(3):  # Gauss
        piv = s[i][i]
        for j in range(i, 4):
            s[i][j] /= piv
        for k in range(3):
            if k != i:
                f = s[k][i]
                for j in range(i, 4):
                    s[k][j] -= f * s[i][j]
    d, e, f = s[0][3], s[1][3], s[2][3]
    cx, cy = -d / 2, -e / 2
    return cx, cy, (cx * cx + cy * cy - f) ** 0.5


def find_inner_disc(im, approx, r_guess=81):
    """Bords droit et bas du disque vert (l'arc n'y passe pas), puis ajustement."""
    px = im.load()
    cx, cy = approx
    pts = []
    for dy in range(-int(r_guess * 0.6), int(r_guess * 0.6) + 1, 4):
        y = cy + dy
        x = cx + int(r_guess * 1.5)
        while x > cx and not is_green(px[x, y]):
            x -= 1
        pts.append((x + 0.5, y))
    for dx in range(-int(r_guess * 0.6), int(r_guess * 0.6) + 1, 4):
        x = cx + dx
        y = cy + int(r_guess * 1.5)
        while y > cy and not is_green(px[x, y]):
            y -= 1
        pts.append((x, y + 0.5))
    return fit_circle(pts)


def vertical_gradient(w, h, top, bottom):
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return g.resize((w, h))


def car_mask(n):
    """Voiture vue de face, silhouette blanche ; vitres/phares découpés (0)."""
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    u = n / 100.0
    P = lambda pts: [(x * u, y * u) for x, y in pts]
    R = lambda x0, y0, x1, y1: (x0 * u, y0 * u, x1 * u, y1 * u)
    dy = -2.5  # recentrage vertical
    def p(pts):
        return P([(x, y + dy) for x, y in pts])
    def r(x0, y0, x1, y1):
        return R(x0, y0 + dy, x1, y1 + dy)

    # Habitacle (trapèze) + caisse
    d.polygon(p([(30, 50), (35.5, 30), (64.5, 30), (70, 50)]), fill=255)
    d.rounded_rectangle(r(35.5, 28, 64.5, 34), radius=3 * u, fill=255)
    d.rounded_rectangle(r(22, 47, 78, 71), radius=6 * u, fill=255)
    # Rétroviseurs
    d.rounded_rectangle(r(17, 44, 25, 49.5), radius=2 * u, fill=255)
    d.rounded_rectangle(r(75, 44, 83, 49.5), radius=2 * u, fill=255)
    # Roues
    d.rounded_rectangle(r(26, 66, 37, 78), radius=3 * u, fill=255)
    d.rounded_rectangle(r(63, 66, 74, 78), radius=3 * u, fill=255)
    # Découpes : pare-brise, phares, calandre
    d.polygon(p([(36, 46), (39.5, 34.5), (60.5, 34.5), (64, 46)]), fill=0)
    d.ellipse(r(26.5, 53, 35.5, 62), fill=0)
    d.ellipse(r(64.5, 53, 73.5, 62), fill=0)
    d.rounded_rectangle(r(41, 60, 59, 64.5), radius=2 * u, fill=0)
    return m


def paint_badge(im, cx, cy, r, picto=None):
    rr = r + 1.0  # recouvre l'anticrénelage du bord d'origine
    n = int(2 * rr) + 4
    N = n * SS
    ox, oy = cx - n / 2, cy - n / 2
    c = N / 2
    R = rr * SS

    disc = Image.new("L", (N, N), 0)
    ImageDraw.Draw(disc).ellipse((c - R, c - R, c + R, c + R), fill=255)

    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    grad = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    grad.paste(vertical_gradient(int(2 * R), int(2 * R), GREEN_TOP, GREEN_BOTTOM),
               (int(c - R), int(c - R)))
    layer.paste(grad, (0, 0), disc)

    # Reflet brillant en haut
    D = 2 * R
    gw, gh = D * 0.78, D * 0.46
    gx0, gy0 = c - gw / 2, c - R + D * 0.03
    gloss = Image.new("L", (N, N), 0)
    ImageDraw.Draw(gloss).ellipse((gx0, gy0, gx0 + gw, gy0 + gh), fill=255)
    fade = Image.new("L", (1, N), 0)
    for y in range(N):
        t = (y - gy0) / gh
        fade.putpixel((0, y), int(85 * (1 - t) ** 1.6) if 0 <= t <= 1 else 0)
    gloss = ImageChops.multiply(ImageChops.multiply(gloss, fade.resize((N, N))), disc)
    layer.paste((255, 255, 255, 255), (0, 0), gloss.filter(ImageFilter.GaussianBlur(D * 0.01)))

    # Pictogramme voiture, à l'échelle du disque
    cm = (picto or car_mask)(int(D))
    car = Image.new("L", (N, N), 0)
    car.paste(cm, (int(c - R), int(c - R)))
    layer.paste((255, 255, 255, 255), (0, 0), car)

    layer = layer.resize((n, n), Image.LANCZOS)
    base = im.convert("RGBA")
    # position sous-pixel : on arrondit l'origine
    base.alpha_composite(layer, (round(ox), round(oy)))
    return base if im.mode == "RGBA" else base.convert(im.mode)


def main(picto=None, out_dir=HERE):
    for name, approx in SOURCES.items():
        src = Image.open(SRC_DIR / name)
        rgba = src.convert("RGBA")
        cx, cy, r = find_inner_disc(rgba, approx)
        out = paint_badge(src, cx, cy, r, picto)
        out.save(Path(out_dir) / name, optimize=True)
        print(f"{name}: disque ({cx:.1f}, {cy:.1f}) r={r:.1f} -> {out.size} {out.mode}")


if __name__ == "__main__":
    import sys
    from pictos import VARIANTS
    # python3 build_logo.py [variante]  (sans argument : voiture de face d'origine)
    main(VARIANTS[sys.argv[1]] if len(sys.argv) > 1 else None)
