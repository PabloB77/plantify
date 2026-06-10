#!/usr/bin/env python3
"""
Plantify pixel-art generator.

Draws every sprite on a small pixel grid (mostly 48x48) with a shared,
Stardew-Valley-inspired palette, auto-outlines them with a chunky dark
border, then nearest-neighbour upscales for crisp retro pixels.

Run:  python3 Tools/generate_sprites.py
Outputs into  Tools/out/  (the repo already contains the results inside
Plantify/Assets.xcassets — re-run this only if you want to tweak art).
"""
import math, os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- palette --
P = {
    "outline":   (43, 29, 24),
    "soil_d":    (74, 48, 32),  "soil":   (107, 68, 43), "soil_l": (143, 95, 58),
    "wood_d":    (114, 70, 38), "wood":   (158, 102, 54),"wood_l": (196, 138, 78),
    "tan":       (222, 178, 114),"cream": (246, 238, 214),
    "leaf_d":    (37, 92, 53),  "leaf":   (62, 137, 72), "leaf_l": (118, 187, 92),
    "leaf_pale": (170, 219, 128),
    "stem":      (88, 124, 60),
    "red_d":     (146, 42, 56), "red":    (199, 62, 64), "red_l":  (233, 111, 92),
    "pink_d":    (171, 64, 110),"pink":   (219, 98, 145),"pink_l": (243, 158, 188),
    "yel_d":     (197, 138, 38),"yel":    (236, 180, 62),"yel_l":  (250, 222, 116),
    "org_d":     (178, 92, 28), "org":    (219, 130, 44),"org_l":  (243, 173, 84),
    "sky":       (132, 198, 234),"sky_l": (177, 226, 247),"sky_d": (98, 168, 216),
    "cloud":     (250, 250, 244),
    "hill_d":    (66, 124, 70), "hill":   (96, 158, 84),
    "melon_d":   (32, 86, 48),  "melon":  (58, 126, 66),
    "white":     (255, 255, 255),
    "purple":    (122, 84, 161),
    "navy":      (40, 52, 84),
}

# ------------------------------------------------------------------ canvas --
class Px:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [[None] * w for _ in range(h)]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.g[int(y)][int(x)] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[int(y)][int(x)]
        return None

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def disc(self, cx, cy, r, c):
        self.ellipse(cx, cy, r, r, c)

    def ellipse(self, cx, cy, rx, ry, c, angle=0.0):
        ca, sa = math.cos(-angle), math.sin(-angle)
        x0, x1 = int(cx - max(rx, ry) - 1), int(cx + max(rx, ry) + 2)
        y0, y1 = int(cy - max(rx, ry) - 1), int(cy + max(rx, ry) + 2)
        for y in range(y0, y1):
            for x in range(x0, x1):
                dx, dy = (x + 0.5) - cx, (y + 0.5) - cy
                u, v = dx * ca - dy * sa, dx * sa + dy * ca
                if (u / rx) ** 2 + (v / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

    def ring(self, cx, cy, r0, r1, c, a0=-10.0, a1=10.0):
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x + 0.5) - cx, (y + 0.5) - cy
                d = math.hypot(dx, dy)
                if r0 <= d <= r1:
                    a = math.atan2(dy, dx)
                    if a0 <= a <= a1:
                        self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c, w=1):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) * 2 + 1
        for i in range(steps + 1):
            t = i / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if w == 1:
                self.put(round(x), round(y), c)
            else:
                self.disc(x, y, w / 2.0, c)

    def sphere_shade(self, cx, cy, r, base, light, dark, pale=None):
        """Classic SDV 4-tone ball: base disc, lower-right shadow crescent,
        upper-left light band, small pale glint."""
        self.disc(cx, cy, r, base)
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x + 0.5) - cx, (y + 0.5) - cy
                d = math.hypot(dx, dy)
                if d <= r:
                    if d >= r * 0.72 and dx + dy > r * 0.35:
                        self.put(x, y, dark)
                    elif d <= r * 0.86 and (dx * 0.8 + dy) < -r * 0.30:
                        self.put(x, y, light)
        if pale:
            self.disc(cx - r * 0.38, cy - r * 0.42, max(1.2, r * 0.16), pale)

    def outline(self, c=None):
        c = c or P["outline"]
        edge = []
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] is None:
                    for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                        if self.get(nx, ny) not in (None, c):
                            edge.append((x, y)); break
        for x, y in edge:
            self.put(x, y, c)

    def save(self, name, scale=10, bg=None):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0) if bg is None else bg + (255,))
        for y in range(self.h):
            for x in range(self.w):
                c = self.g[y][x]
                if c is not None:
                    img.putpixel((x, y), c + (255,))
        img = img.resize((self.w * scale, self.h * scale), Image.NEAREST)
        img.save(os.path.join(OUT, name + ".png"))
        return img

# ------------------------------------------------------------ leaf helper --
def leaf(px, cx, cy, length, width, angle, base="leaf", lite="leaf_l"):
    """Pointed leaf: two arcs meeting; approximated by tapered ellipse + tip."""
    ca, sa = math.cos(angle), math.sin(angle)
    midx, midy = cx + ca * length * 0.45, cy + sa * length * 0.45
    px.ellipse(midx, midy, length * 0.5, width * 0.5, P[base], angle)
    px.ellipse(midx - ca * 0.5 + sa * width * 0.18,
               midy - sa * 0.5 - ca * width * 0.18,
               length * 0.34, width * 0.28, P[lite], angle)

# =================================================================== tiers ==
S = 48
CX = CY = S / 2

def t00_seed():
    px = Px(S, S)
    px.ellipse(CX, CY + 1, 13, 17, P["soil"])
    # shading
    px.ellipse(CX - 3, CY - 3, 9, 12, P["soil_l"])
    px.ellipse(CX - 5, CY - 6, 4, 6, P["tan"])
    for y in range(int(CY), int(CY + 16)):
        for x in range(int(CX + 4), int(CX + 13)):
            dx, dy = x - CX, y - CY - 1
            if (dx/13)**2 + (dy/17)**2 <= 1 and dx + dy*0.6 > 8:
                px.put(x, y, P["soil_d"])
    px.line(CX, CY - 14, CX, CY + 8, P["soil_d"])      # seam
    px.line(CX, CY - 14, CX - 1, CY - 16, P["stem"])   # tiny shoot nub
    px.outline()
    return px

def t01_sprout():
    px = Px(S, S)
    px.sphere_shade(CX, CY + 6, 13, P["soil"], P["soil_l"], P["soil_d"], P["tan"])
    # speckles
    for sx, sy in ((CX-6, CY+9), (CX+4, CY+12), (CX+8, CY+4), (CX-2, CY+15)):
        px.put(sx, sy, P["soil_d"])
    px.line(CX, CY + 2, CX, CY - 10, P["stem"], 2)
    leaf(px, CX, CY - 9, 13, 7, math.radians(205))
    leaf(px, CX, CY - 9, 13, 7, math.radians(-25))
    px.disc(CX, CY - 11, 2.2, P["leaf_pale"])
    px.outline()
    return px

def t02_clover():
    px = Px(S, S)
    px.line(CX, CY + 8, CX + 2, CY + 19, P["stem"], 2)
    for ang, r in ((90, 10.5), (210, 10.5), (330, 10.5)):
        a = math.radians(ang)
        lx, ly = CX + math.cos(a) * 8.5, CY - 2 + math.sin(a) * -8.5
        px.sphere_shade(lx, ly, r, P["leaf"], P["leaf_l"], P["leaf_d"], None)
    # creases between the three leaves + heart notches at each tip
    for ang in (30, 150, 270):
        a = math.radians(ang)
        px.line(CX, CY - 2, CX + math.cos(a) * 17, CY - 2 - math.sin(a) * 17, P["leaf_d"], 2)
    for ang in (90, 210, 330):
        a = math.radians(ang)
        tx, ty = CX + math.cos(a) * 15.0, CY - 2 - math.sin(a) * 15.0
        px.line(tx, ty, CX + math.cos(a) * 11, CY - 2 - math.sin(a) * 11, P["leaf_d"], 1)
    px.disc(CX, CY - 2, 2.6, P["leaf_d"])
    px.disc(CX - 7, CY - 11, 2.0, P["leaf_pale"])
    px.disc(CX + 9, CY - 8, 1.6, P["leaf_pale"])
    px.outline()
    return px

def t03_tulip():
    px = Px(S, S)
    px.line(CX, CY + 2, CX, CY + 20, P["stem"], 2)
    leaf(px, CX - 1, CY + 16, 14, 6, math.radians(215))
    leaf(px, CX + 1, CY + 13, 13, 6, math.radians(-35))
    # cup
    px.ellipse(CX, CY - 4, 13, 14, P["pink"])
    px.ellipse(CX - 4, CY - 7, 7, 9, P["pink_l"])
    for y in range(int(CY - 18), int(CY + 11)):
        for x in range(int(CX + 3), int(CX + 14)):
            dx, dy = x - CX, y - (CY - 4)
            if (dx/13)**2 + (dy/14)**2 <= 1 and dx > 6:
                px.put(x, y, P["pink_d"])
    # petal splits (three points on top)
    px.ellipse(CX - 8, CY - 13, 5, 7, P["pink"])
    px.ellipse(CX,     CY - 15, 5, 8, P["pink_l"])
    px.ellipse(CX + 8, CY - 13, 5, 7, P["pink_d"])
    px.line(CX - 4, CY - 12, CX - 3, CY - 2, P["pink_d"])
    px.line(CX + 4, CY - 12, CX + 3, CY - 2, P["pink_d"])
    px.outline()
    return px

def t04_rose():
    px = Px(S, S)
    px.line(CX, CY + 6, CX - 2, CY + 21, P["stem"], 2)
    leaf(px, CX - 2, CY + 16, 13, 7, math.radians(200))
    leaf(px, CX - 1, CY + 12, 12, 6, math.radians(-30))
    px.sphere_shade(CX, CY - 2, 15, P["red"], P["red_l"], P["red_d"], None)
    # spiral petals
    px.ring(CX, CY - 2, 10.5, 12.5, P["red_d"], math.radians(-160), math.radians(60))
    px.ring(CX - 1, CY - 3, 6.5, 8.0, P["red_d"], math.radians(-40), math.radians(180))
    px.ring(CX, CY - 2, 3.0, 4.2, P["red_d"], math.radians(-180), math.radians(90))
    px.disc(CX + 1, CY - 3, 1.6, P["red_l"])
    # outer petal tips
    px.ellipse(CX - 11, CY + 6, 5, 4, P["red_d"])
    px.ellipse(CX + 10, CY + 6, 5, 4, P["red_d"])
    px.outline()
    return px

def t05_sunflower():
    px = Px(S, S)
    n = 12
    for i in range(n):
        a = i / n * math.tau
        lx, ly = CX + math.cos(a) * 14.5, CY + math.sin(a) * 14.5
        px.ellipse(lx, ly, 8.5, 4.4, P["yel"], a)
    for i in range(n):
        a = (i + 0.5) / n * math.tau
        lx, ly = CX + math.cos(a) * 12.5, CY + math.sin(a) * 12.5
        px.ellipse(lx, ly, 7.0, 3.6, P["yel_d"], a)
    for i in range(n):
        a = i / n * math.tau
        lx, ly = CX + math.cos(a) * 13.5, CY + math.sin(a) * 13.5
        px.ellipse(lx, ly, 6.0, 2.6, P["yel_l"], a)
    px.sphere_shade(CX, CY, 9.5, P["soil"], P["soil_l"], P["soil_d"], None)
    for sx, sy in ((CX-4,CY-2),(CX+1,CY-4),(CX+4,CY+1),(CX-1,CY+4),(CX-5,CY+3),(CX+5,CY-4),(CX,CY)):
        px.put(sx, sy, P["soil_d"])
    px.outline()
    return px

def t06_mushroom():
    px = Px(S, S)
    # stem
    px.rect(CX - 7, CY + 2, CX + 7, CY + 19, P["cream"])
    px.ellipse(CX, CY + 19, 8, 4, P["cream"])
    px.rect(CX + 3, CY + 2, CX + 7, CY + 19, P["tan"])
    px.ellipse(CX, CY + 3, 9, 3, P["tan"])
    # cap
    px.ellipse(CX, CY - 4, 19, 13, P["red"])
    px.ellipse(CX, CY - 9, 15, 8, P["red_l"])
    for y in range(S):
        for x in range(S):
            dx, dy = x - CX, y - (CY - 4)
            if (dx/19)**2 + (dy/13)**2 <= 1 and dy > 6:
                px.put(x, y, P["red_d"])
    # spots
    for sx, sy, r in ((CX-9, CY-7, 3.2), (CX+7, CY-9, 2.6), (CX, CY-1, 2.4), (CX+13, CY-2, 2.0), (CX-14, CY, 1.8)):
        px.disc(sx, sy, r, P["cream"])
        px.put(sx + 1, sy + 1, P["tan"])
    px.outline()
    return px

def t07_pumpkin():
    px = Px(S, S)
    px.sphere_shade(CX, CY + 2, 19, P["org"], P["org_l"], P["org_d"], None)
    # ribs
    for off in (-11, 0, 11):
        for y in range(S):
            for x in range(S):
                dx, dy = x - CX, y - (CY + 2)
                if (dx/19)**2 + (dy/19)**2 <= 1:
                    rib = CX + off * math.sqrt(max(0.0, 1 - (dy/19)**2))
                    if abs(x + 0.5 - rib) < 0.9 and off != 0:
                        px.put(x, y, P["org_d"])
                    if off == 0 and abs(x + 0.5 - CX) < 0.9:
                        px.put(x, y, P["org_d"])
    px.disc(CX - 7, CY - 5, 2.0, P["yel_l"])
    # stem + curl
    px.rect(CX - 2, CY - 21, CX + 2, CY - 14, P["stem"])
    px.put(CX - 2, CY - 21, None)
    px.line(CX + 4, CY - 19, CX + 9, CY - 17, P["leaf_d"])
    px.line(CX + 9, CY - 17, CX + 8, CY - 13, P["leaf_d"])
    leaf(px, CX - 3, CY - 17, 11, 6, math.radians(195))
    px.outline()
    return px

def t08_watermelon():
    px = Px(S, S)
    px.sphere_shade(CX, CY, 21, P["melon"], P["leaf_l"], P["melon_d"], None)
    # jagged dark stripes following sphere curvature
    for off in (-14, -7, 0, 7, 14):
        for y in range(S):
            for x in range(S):
                dx, dy = x - CX, y - CY
                if dx*dx + dy*dy <= 21*21:
                    sx = CX + off * math.sqrt(max(0.0, 1 - (dy/21)**2))
                    wob = 1.4 + 0.9 * math.sin(y * 1.7 + off)
                    if abs(x + 0.5 - sx) < wob:
                        px.put(x, y, P["melon_d"])
    px.disc(CX - 8, CY - 9, 2.2, P["leaf_pale"])
    px.put(CX, CY - 21, P["stem"]); px.put(CX, CY - 22, P["stem"]); px.put(CX + 1, CY - 22, P["stem"])
    px.outline()
    return px

def t09_pine():
    px = Px(S, S)
    # trunk
    px.rect(CX - 4, CY + 12, CX + 4, CY + 22, P["wood"])
    px.rect(CX + 1, CY + 12, CX + 4, CY + 22, P["wood_d"])
    # three tiers of boughs, widest ~ fills circle
    layers = ((CY + 9, 21), (CY - 1, 17), (CY - 10, 12.5))
    for base_y, half in layers:
        top_y = base_y - half * 1.05
        for y in range(int(top_y), int(base_y) + 1):
            t = (y - top_y) / (base_y - top_y)
            w = half * t
            jag = 1.5 * math.sin(y * 2.1)
            for x in range(int(CX - w - jag), int(CX + w + jag) + 1):
                px.put(x, y, P["leaf_d"])
            for x in range(int(CX - w - jag), int(CX - w * 0.1)):
                px.put(x, y, P["leaf"])
            for x in range(int(CX - w - jag), int(CX - w * 0.55)):
                px.put(x, y, P["leaf_l"])
    px.put(CX, CY - 23, P["leaf_l"]); px.put(CX, CY - 22, P["leaf"])
    # snow-ish glints
    px.disc(CX - 6, CY - 13, 1.4, P["leaf_pale"])
    px.disc(CX + 5, CY - 3, 1.2, P["leaf_pale"])
    px.outline()
    return px

def t10_great_oak():
    px = Px(S, S)
    # trunk
    px.rect(CX - 5, CY + 8, CX + 5, CY + 22, P["wood"])
    px.rect(CX + 1, CY + 8, CX + 5, CY + 22, P["wood_d"])
    px.rect(CX - 5, CY + 8, CX - 3, CY + 22, P["wood_l"])
    px.line(CX - 8, CY + 22, CX - 6, CY + 16, P["wood"], 2)
    px.line(CX + 8, CY + 22, CX + 6, CY + 17, P["wood_d"], 2)
    # canopy: cluster of lobes
    lobes = ((CX, CY - 8, 15), (CX - 12, CY - 2, 10), (CX + 12, CY - 2, 10),
             (CX - 7, CY - 14, 9), (CX + 7, CY - 14, 9), (CX, CY + 1, 12))
    for lx, ly, r in lobes:
        px.disc(lx, ly, r, P["leaf"])
    for lx, ly, r in lobes:
        px.disc(lx - r * 0.25, ly - r * 0.3, r * 0.6, P["leaf_l"])
    # bottom shadow
    for y in range(S):
        for x in range(S):
            if px.get(x, y) in (P["leaf"], P["leaf_l"]):
                dx, dy = x - CX, y - (CY - 6)
                if dy > 6 and dx > -4:
                    px.put(x, y, P["leaf_d"])
    # texture dots + tiny golden acorns
    for sx, sy in ((CX-10,CY-10),(CX+3,CY-16),(CX+12,CY-6),(CX-3,CY-3),(CX+8,CY+2)):
        px.put(sx, sy, P["leaf_pale"])
    for sx, sy in ((CX-13, CY+1), (CX+9, CY-12), (CX+1, CY+4)):
        px.disc(sx, sy, 1.4, P["yel"])
        px.put(sx, sy - 2, P["soil_d"])
    px.outline()
    return px

# ============================================================ environment ==
def bg_farm():
    W, H = 180, 320
    px = Px(W, H)
    # sky bands
    for y in range(H):
        if y < 60: c = P["sky_l"]
        elif y < 130: c = P["sky"]
        else: c = P["sky_d"]
        for x in range(W):
            px.put(x, y, c)
    # dither band seams
    for y, ca, cb in ((60, "sky_l", "sky"), (130, "sky", "sky_d")):
        for x in range(W):
            if (x + y) % 2 == 0: px.put(x, y, P[ca])
            if (x + y) % 3 == 0: px.put(x, y - 1, P[cb])
    # sun
    px.disc(150, 38, 13, P["yel_l"])
    px.disc(146, 34, 6, P["cream"])
    # clouds
    for cx, cy, s in ((34, 50, 1.0), (104, 26, 0.8), (66, 90, 0.7), (150, 96, 0.9)):
        for ox, oy, r in ((0,0,9),(10,2,7),(-10,3,7),(4,-5,6),(-4,-4,5)):
            px.disc(cx + ox * s, cy + oy * s, r * s, P["cloud"])
        for ox in range(-int(14*s), int(14*s)):
            px.put(cx + ox, cy + int(6*s), P["sky_l"])
    # distant hills
    for x in range(W):
        h1 = 196 + int(14 * math.sin(x * 0.045) + 6 * math.sin(x * 0.11 + 2))
        for y in range(h1, H):
            px.put(x, y, P["hill"])
        px.put(x, h1, P["leaf_pale"])
    for x in range(W):
        h2 = 226 + int(10 * math.sin(x * 0.06 + 4))
        for y in range(h2, H):
            px.put(x, y, P["hill_d"])
    # tilled field rows at the bottom
    for y in range(258, H):
        for x in range(W):
            px.put(x, y, P["soil"])
    for x in range(W):
        px.put(x, 258 + (x // 6) % 2, P["soil_l"])
    for ry in range(264, H, 8):
        for x in range(W):
            px.put(x, ry + ((x // 9) % 2), P["soil_d"])
    # little fence on the field line
    for fx in range(6, W, 22):
        px.rect(fx, 246, fx + 1, 258, P["wood"])
        px.put(fx, 246, P["wood_l"])
    for x in range(0, W):
        if (x % 22) not in (20, 21):
            px.put(x, 250, P["wood_d"]); px.put(x, 251, P["wood"])
    # scattered crops dots
    for i, fx in enumerate(range(4, W, 13)):
        px.disc(fx, 272 + (i % 3) * 12, 2.2, P["leaf"] if i % 2 else P["leaf_l"])
    px.save("bg_farm", scale=4)
    return px

def crate_tile():
    px = Px(24, 24)
    px.rect(0, 0, 23, 23, P["wood"])
    for y in (0, 8, 16):
        for x in range(24):
            px.put(x, y, P["wood_d"])
            px.put(x, y + 1, P["wood_l"])
    for x in (3, 13, 19):
        for y in range(24):
            if y % 8 not in (0,):
                px.put(x, y, P["wood_d"])
    # nails
    for nx, ny in ((6, 4), (17, 12), (9, 20)):
        px.put(nx, ny, P["outline"]); px.put(nx + 1, ny, P["tan"])
    px.save("crate_tile", scale=10)

def soil_tile():
    px = Px(24, 24)
    px.rect(0, 0, 23, 23, P["soil"])
    for i, (sx, sy) in enumerate(((2,3),(8,7),(15,2),(20,9),(5,14),(12,17),(19,19),(3,21),(16,13),(9,1))):
        px.put(sx, sy, P["soil_d"] if i % 2 else P["soil_l"])
        px.put(sx + 1, sy, P["soil_d"] if i % 3 else P["soil_l"])
    for x in range(24):
        px.put(x, 0, P["soil_l"])
        if x % 3: px.put(x, 1, P["soil_l"])
    px.save("soil_tile", scale=10)

def panel():
    px = Px(48, 48)
    px.rect(0, 0, 47, 47, P["tan"])
    px.rect(2, 2, 45, 45, P["wood_l"])
    px.rect(5, 5, 42, 42, P["cream"])
    for x in range(0, 48):
        px.put(x, 0, P["outline"]); px.put(x, 47, P["outline"])
    for y in range(0, 48):
        px.put(0, y, P["outline"]); px.put(47, y, P["outline"])
    for cx, cy in ((3, 3), (44, 3), (3, 44), (44, 44)):
        px.rect(cx - 1, cy - 1, cx + 1, cy + 1, P["wood_d"])
        px.put(cx, cy, P["yel"])
    px.save("panel", scale=8)

def button():
    px = Px(48, 24)
    px.rect(1, 1, 46, 22, P["leaf"])
    px.rect(1, 1, 46, 4, P["leaf_l"])
    px.rect(1, 19, 46, 22, P["leaf_d"])
    for x in range(48):
        px.put(x, 0, P["outline"]); px.put(x, 23, P["outline"])
    for y in range(24):
        px.put(0, y, P["outline"]); px.put(47, y, P["outline"])
    px.put(1, 1, P["outline"]); px.put(46, 1, P["outline"])
    px.put(1, 22, P["outline"]); px.put(46, 22, P["outline"])
    px.save("button", scale=8)

def icon_coin():
    px = Px(16, 16)
    px.sphere_shade(8, 8, 6.5, P["yel"], P["yel_l"], P["yel_d"], None)
    px.rect(7, 5, 8, 10, P["yel_d"])
    px.rect(6, 5, 9, 5, P["yel_d"]); px.rect(6, 10, 9, 10, P["yel_d"])
    px.outline()
    px.save("icon_coin", scale=10)

def icon_flame():
    px = Px(16, 16)
    for y in range(2, 15):
        t = (y - 2) / 12
        w = 1 + 5.5 * math.sin(t * math.pi * 0.62)
        off = 1.6 * math.sin(t * 5)
        for x in range(int(8 - w + off), int(8 + w + off) + 1):
            px.put(x, y, P["org"])
    for y in range(6, 14):
        t = (y - 6) / 8
        w = 0.5 + 3 * math.sin(t * math.pi * 0.6)
        for x in range(int(8 - w), int(8 + w) + 1):
            px.put(x, y, P["yel"])
    px.rect(7, 11, 9, 13, P["yel_l"])
    px.outline()
    px.save("icon_flame", scale=10)

def icon_freeze():
    px = Px(16, 16)
    for a in range(6):
        ang = a * math.tau / 6
        px.line(8, 8, 8 + math.cos(ang) * 6, 8 + math.sin(ang) * 6, P["sky"], 1)
        px.put(round(8 + math.cos(ang) * 6), round(8 + math.sin(ang) * 6), P["sky_l"])
    px.disc(8, 8, 1.6, P["sky_l"])
    px.outline()
    px.save("icon_freeze", scale=10)

def app_icon():
    px = Px(64, 64)
    for y in range(64):
        c = P["sky_l"] if y < 16 else (P["sky"] if y < 40 else P["sky_d"])
        for x in range(64):
            px.put(x, y, c)
    for x in range(64):
        h = 44 + int(3 * math.sin(x * 0.2))
        for y in range(h, 64):
            px.put(x, y, P["hill"])
    for y in range(52, 64):
        for x in range(64):
            px.put(x, y, P["soil"])
    for x in range(64):
        px.put(x, 52 + (x // 5) % 2, P["soil_l"])
    # big sprout
    px.sphere_shade(32, 46, 9, P["soil"], P["soil_l"], P["soil_d"], P["tan"])
    px.line(32, 42, 32, 26, P["stem"], 3)
    leaf(px, 32, 27, 18, 10, math.radians(207))
    leaf(px, 32, 27, 18, 10, math.radians(-27))
    px.disc(32, 24, 3, P["leaf_pale"])
    # sun
    px.disc(53, 9, 7, P["yel_l"]); px.disc(51, 7, 3, P["cream"])
    img = Image.new("RGBA", (64, 64))
    for y in range(64):
        for x in range(64):
            c = px.g[y][x]
            img.putpixel((x, y), (c + (255,)) if c else (0, 0, 0, 255))
    img.resize((1024, 1024), Image.NEAREST).convert("RGB").save(os.path.join(OUT, "app_icon.png"))

# ------------------------------------------------------------------- main --
TIERS = [t00_seed, t01_sprout, t02_clover, t03_tulip, t04_rose, t05_sunflower,
         t06_mushroom, t07_pumpkin, t08_watermelon, t09_pine, t10_great_oak]

def main():
    sheets = []
    for i, fn in enumerate(TIERS):
        px = fn()
        img = px.save(f"tier_{i:02d}", scale=10)
        sheets.append(img.resize((96, 96), Image.NEAREST))
    bg_farm(); crate_tile(); soil_tile(); panel(); button()
    icon_coin(); icon_flame(); icon_freeze(); app_icon()
    # contact sheet for review
    sheet = Image.new("RGBA", (96 * 6, 96 * 2), (60, 60, 70, 255))
    for i, im in enumerate(sheets):
        sheet.paste(im, ((i % 6) * 96, (i // 6) * 96), im)
    sheet.save(os.path.join(OUT, "_contact_sheet.png"))
    print("done ->", OUT)

if __name__ == "__main__":
    main()
