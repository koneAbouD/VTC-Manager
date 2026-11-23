"""Pictogrammes du badge TMK VTC.

Chaque fonction reçoit la taille n (px) du disque vert intérieur et renvoie un
masque « L » n×n : 255 = blanc, 0 = laisse voir le vert du badge.
Les coordonnées sont exprimées en unités 0→100 du disque.
"""
import math

from PIL import Image, ImageDraw


def _bezier(p0, p1, p2, p3, steps=24):
    out = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * t * (1 - t) ** 2, 3 * t * t * (1 - t), t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


class Pen:
    def __init__(self, n, dx=0.0, dy=0.0, scale=1.0, cx=50, cy=50):
        self.m = Image.new("L", (n, n), 0)
        self.d = ImageDraw.Draw(self.m)
        self.u = n / 100.0
        self.dx, self.dy, self.s, self.cx, self.cy = dx, dy, scale, cx, cy

    def pt(self, x, y):
        x = self.cx + (x - self.cx) * self.s + self.dx
        y = self.cy + (y - self.cy) * self.s + self.dy
        return (x * self.u, y * self.u)

    def poly(self, pts, fill=255):
        self.d.polygon([self.pt(*p) for p in pts], fill=fill)

    def circle(self, x, y, r, fill=255):
        (a, b), r = self.pt(x, y), r * self.s * self.u
        self.d.ellipse((a - r, b - r, a + r, b + r), fill=fill)

    def rrect(self, x0, y0, x1, y1, rad, fill=255):
        self.d.rounded_rectangle((*self.pt(x0, y0), *self.pt(x1, y1)),
                                 radius=rad * self.s * self.u, fill=fill)

    def ring(self, x, y, r_out, r_in):
        self.circle(x, y, r_out, 255)
        self.circle(x, y, r_in, 0)


# ── Berline de profil ────────────────────────────────────────────────────────
def _sedan_body():
    """Contour d'une berline basse vue de profil (avant à droite)."""
    pts = []
    pts += _bezier((13, 59), (12.5, 54), (14, 50.5), (19, 49.5))     # arrière
    pts += _bezier((19, 49.5), (25, 48.5), (31, 48), (35, 47))       # coffre
    pts += _bezier((35, 47), (39, 40.5), (43, 37.5), (51, 37))       # lunette
    pts += _bezier((51, 37), (58, 36.7), (62, 38.5), (69, 46.5))     # toit/pare-brise
    pts += _bezier((69, 46.5), (77, 47.3), (84, 48.5), (86.5, 51.5)) # capot
    pts += _bezier((86.5, 51.5), (88, 54), (88, 57.5), (87, 60.5))   # avant
    pts += [(86.5, 62), (13.5, 62)]
    return pts


def _sedan(p):
    p.poly(_sedan_body())
    # vitres latérales (montant central)
    p.poly(_bezier((38.8, 46), (42, 41.2), (45, 39.7), (50.3, 39.5)) + [(50.3, 46)], 0)
    p.poly([(53.2, 39.5)] + _bezier((53.2, 39.5), (58, 39.5), (61, 41), (65.3, 46)) + [(53.2, 46)], 0)
    # roues : passage de roue (vert) puis roue blanche + moyeu
    for x in (28, 72):
        p.circle(x, 62, 9, 0)
        p.circle(x, 62, 6.8, 255)
        p.circle(x, 62, 2.4, 0)


def side_sedan(n):
    p = Pen(n, dy=-0.5)
    _sedan(p)
    return p.m


def side_sedan_speed(n):
    p = Pen(n, dx=5, dy=-0.5, scale=0.86)
    _sedan(p)
    # traits de vitesse derrière la voiture
    for y, x0, x1 in ((44, 4, 13), (51.5, 0, 11), (59, 4, 11)):
        p.rrect(x0, y - 1.6, x1, y + 1.6, 1.6)
    return p.m


# ── Repère de localisation avec voiture ──────────────────────────────────────
def pin_car(n):
    p = Pen(n)
    # repère : tête ronde + pointe
    cx, cy, r = 50, 42, 25
    p.circle(cx, cy, r)
    a = math.radians(38)
    left = (cx - r * math.cos(a), cy + r * math.sin(a))
    right = (cx + r * math.cos(a), cy + r * math.sin(a))
    p.poly([left] + _bezier(left, (40, 66), (47, 74), (50, 81))
           + _bezier((50, 81), (53, 74), (60, 66), right))
    # voiture vue de face, découpée en vert dans la tête du repère
    q = Pen(n, scale=0.52, cx=50, cy=50, dy=-10)
    q.d = p.d  # même calque
    q.poly(_bezier((31, 49), (33, 36), (35, 32), (40, 31.5))
           + _bezier((60, 31.5), (65, 32), (67, 36), (69, 49)), 0)
    q.rrect(22, 47, 78, 68, 7, 0)
    q.rrect(25, 64, 37, 76, 3.5, 0)
    q.rrect(63, 64, 75, 76, 3.5, 0)
    q.poly(_bezier((36.5, 46), (38, 38.5), (39.5, 36), (43, 35.8))
           + _bezier((57, 35.8), (60.5, 36), (62, 38.5), (63.5, 46)), 255)
    q.circle(31.5, 56.5, 4.2, 255)
    q.circle(68.5, 56.5, 4.2, 255)
    return p.m


# ── Volant ───────────────────────────────────────────────────────────────────
def steering_wheel(n):
    p = Pen(n)
    ro, ri = 30, 23
    p.ring(50, 50, ro, ri)
    p.rrect(50 - ri - 1, 46.5, 50 + ri + 1, 54, 2)     # branche horizontale
    p.rrect(46, 50, 54, 50 + ri + 1, 2)                 # branche basse
    p.circle(50, 51.5, 9.5)                             # moyeu
    p.circle(50, 51.5, 3.2, 0)
    return p.m


VARIANTS = {
    "A_profil": side_sedan,
    "B_profil_vitesse": side_sedan_speed,
    "C_repere": pin_car,
    "D_volant": steering_wheel,
}
