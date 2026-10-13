# 坑道の仮の絵（型紙）を書き出す。
# 書き出した PNG は「この大きさ・この並びで描けば差し替わる」見本を兼ねる。
# 手描きの絵ができたら、同じ名前・同じ大きさで上書きすればよい（このスクリプトはもう流さない）。
#
#   python3 tools/make_mine_placeholders.py art/mine
#
# 寸法の決まりは art/mine/README.md を参照。
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1]
GUIDE = os.path.join(OUT, "_guide")
os.makedirs(GUIDE, exist_ok=True)
open(os.path.join(GUIDE, ".gdignore"), "w").close()
rng = np.random.default_rng(11)
C = 64  # 1マスの絵の大きさ（ゲーム内では 32 に縮めて使う）

STONE = (74, 72, 76)
STONE_DARK = (40, 38, 44)
MOSS = (96, 120, 52)
MOSS_LIGHT = (142, 160, 70)
ROOT = (122, 78, 46)
ROOT_LIGHT = (160, 108, 64)
AMBER = (255, 170, 60)
AMBER_LIGHT = (255, 226, 150)


def noise(w, h, scale, seed):
    r = np.random.default_rng(seed)
    small = r.random((max(2, h // scale + 2), max(2, w // scale + 2)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.array(img).astype(np.float32) / 255.0


def save(img, name):
    img.save(os.path.join(OUT, name))
    print("wrote", name)


def stones(d, x0, y0, w, h, seed, base=STONE, n=6):
    """丸っこい石を並べて岩肌っぽくする"""
    r = np.random.default_rng(seed)
    for _ in range(n):
        rw = r.integers(18, 34)
        rh = r.integers(14, 26)
        x = x0 + r.integers(-6, max(1, w - rw + 6))
        y = y0 + r.integers(-6, max(1, h - rh + 6))
        shade = r.integers(-12, 14)
        col = tuple(int(c + shade) for c in base)
        d.ellipse([x, y, x + rw, y + rh], fill=col + (255,), outline=STONE_DARK + (255,), width=2)
        d.arc([x + 3, y + 2, x + rw - 4, y + rh - 4], 200, 300, fill=tuple(min(255, c + 30) for c in col) + (255,), width=2)


# ---- 地形（4×4 = 16 通り） ----
# 番号 = 上が続く 1 + 右が続く 2 + 下が続く 4 + 左が続く 8。
# 並びは 番号 % 4 が列、番号 // 4 が行。

def terrain_tile(mask, seed):
    n, e, s, w = mask & 1, mask & 2, mask & 4, mask & 8
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    # 形：続いていない辺は少し内側に削り、角を丸める
    inset = 5
    x0 = 0 if w else inset
    x1 = C if e else C - inset
    y0 = 0 if n else inset + 6
    y1 = C if s else C - inset
    shape = Image.new("L", (C, C), 0)
    sd = ImageDraw.Draw(shape)
    rad = 14
    sd.rounded_rectangle([x0, y0, x1 - 1, y1 - 1], radius=rad, fill=255)
    # 続いている辺は角を丸めない
    if n:
        sd.rectangle([x0, 0, x1 - 1, C // 2], fill=255)
    if s:
        sd.rectangle([x0, C // 2, x1 - 1, C - 1], fill=255)
    if w:
        sd.rectangle([0, y0, C // 2, y1 - 1], fill=255)
    if e:
        sd.rectangle([C // 2, y0, C - 1, y1 - 1], fill=255)
    # 縁を少しでこぼこに
    nz = noise(C, C, 6, seed)
    edge = shape.filter(ImageFilter.MinFilter(5))
    sh = np.array(shape).astype(np.float32)
    ed = np.array(edge).astype(np.float32)
    rim = (sh > 0) & (ed == 0)
    sh[rim & (nz < 0.45)] = 0
    shape = Image.fromarray(sh.astype(np.uint8))

    body = Image.new("RGBA", (C, C), STONE_DARK + (255,))
    bd = ImageDraw.Draw(body)
    stones(bd, 0, 0, C, C, seed, n=7)
    # 下側ほど暗く
    grad = np.linspace(1.05, 0.75, C)[:, None, None]
    arr = np.array(body).astype(np.float32)
    arr[:, :, :3] *= grad
    body = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    img.paste(body, (0, 0), shape)
    d = ImageDraw.Draw(img)
    # 上が開いていれば苔の縁
    if not n:
        r = np.random.default_rng(seed + 5)
        d.rounded_rectangle([x0 - 1, y0 - 2, x1, y0 + 9], radius=5, fill=MOSS + (255,))
        for _ in range(9):
            x = r.integers(x0, max(x0 + 1, x1 - 6))
            d.ellipse([x, y0 - 5, x + r.integers(6, 12), y0 + 4], fill=MOSS_LIGHT + (255,))
    # 下が開いていれば垂れた影
    if not s:
        d.line([x0 + 6, y1 - 3, x1 - 6, y1 - 3], fill=(24, 22, 26, 255), width=4)
    return img


sheet = Image.new("RGBA", (C * 4, C * 4), (0, 0, 0, 0))
for m in range(16):
    sheet.paste(terrain_tile(m, 100 + m), ((m % 4) * C, (m // 4) * C))
save(sheet, "terrain.png")

# 中身（四方とも続いているマス）の柄違い 4 枚。15番の代わりにランダムで使う
fills = Image.new("RGBA", (C * 4, C), (0, 0, 0, 0))
for i in range(4):
    fills.paste(terrain_tile(15, 300 + i), (i * C, 0))
save(fills, "terrain_fill.png")


# ---- 鉱脈など（地形の上に重ねる。2枚ずつ柄違い） ----

def overlay(kind, seed):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(seed)
    if kind == "rock":
        for _ in range(3):
            x, y = r.integers(6, 30), r.integers(8, 30)
            w, h = r.integers(22, 32), r.integers(18, 26)
            d.ellipse([x, y, x + w, y + h], fill=(118, 116, 124, 255), outline=(52, 50, 58, 255), width=3)
            d.arc([x + 4, y + 3, x + w - 5, y + h - 6], 190, 290, fill=(170, 168, 176, 255), width=3)
    elif kind == "amber":
        d.ellipse([8, 14, 56, 56], fill=(46, 36, 34, 255))
        for _ in range(4):
            cx, cy = r.integers(16, 48), r.integers(22, 48)
            hgt = r.integers(14, 24)
            pts = [(cx, cy - hgt), (cx + 6, cy - hgt // 3), (cx + 4, cy + 6), (cx - 4, cy + 6), (cx - 6, cy - hgt // 3)]
            d.polygon(pts, fill=AMBER + (255,), outline=(150, 80, 20, 255))
            d.line([(cx, cy - hgt + 3), (cx - 2, cy + 2)], fill=AMBER_LIGHT + (255,), width=2)
    elif kind == "bark":
        d.rounded_rectangle([4, 10, 60, 56], radius=10, fill=(112, 76, 46, 255), outline=(60, 38, 22, 255), width=3)
        for y in range(16, 54, 7):
            d.arc([6, y - 4, 58, y + 6], 0, 180, fill=(80, 52, 30, 255), width=2)
    elif kind == "root":
        d.rectangle([0, 0, C, C], fill=ROOT + (255,))
        for x in range(4, C, 11):
            off = r.integers(-3, 4)
            d.line([(x + off, 0), (x - off, C)], fill=ROOT_LIGHT + (255,), width=3)
            d.line([(x + 5 + off, 0), (x + 5 - off, C)], fill=(84, 52, 30, 255), width=2)
    elif kind == "bedrock":
        d.rectangle([0, 0, C, C], fill=(26, 24, 30, 255))
        stones(d, 0, 0, C, C, seed, base=(44, 42, 50), n=6)
    return img


for kind in ["rock", "amber", "bark", "root", "bedrock"]:
    s = Image.new("RGBA", (C * 2, C), (0, 0, 0, 0))
    for i in range(2):
        s.paste(overlay(kind, 500 + i * 7 + len(kind)), (i * C, 0))
    save(s, f"ore_{kind}.png")


# ---- 足場（下からすり抜け）：左端・まん中・右端の 3 マス ----

def platform(kind):
    s = Image.new("RGBA", (C * 3, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(s)
    if kind == "leaf":
        d.rounded_rectangle([6, 4, C * 3 - 6, 22], radius=9, fill=(70, 112, 48, 255), outline=(38, 64, 26, 255), width=2)
        for x in range(10, C * 3 - 10, 9):
            d.ellipse([x, 0, x + 14, 12], fill=(110, 150, 66, 255))
        d.line([(C * 1.5, 22), (C * 1.5, 34)], fill=(60, 90, 40, 255), width=4)
    else:  # plank（吊り橋の板）
        for i in range(C * 3 // 14):
            x = 2 + i * 14
            d.rounded_rectangle([x, 6, x + 11, 22], radius=2, fill=(150, 104, 60, 255), outline=(80, 52, 28, 255), width=2)
        d.line([(0, 4), (C * 3, 4)], fill=(196, 160, 104, 255), width=3)
    return s


save(platform("leaf"), "platform_leaf.png")
save(platform("plank"), "platform_plank.png")

# 吊り橋の両端の柱（下端が床の高さ）
post = Image.new("RGBA", (32, 96), (0, 0, 0, 0))
d = ImageDraw.Draw(post)
d.rounded_rectangle([10, 8, 22, 95], radius=4, fill=(132, 90, 52, 255), outline=(70, 44, 24, 255), width=2)
d.ellipse([8, 2, 24, 16], fill=(150, 104, 60, 255), outline=(70, 44, 24, 255), width=2)
d.line([(16, 30), (31, 64)], fill=(196, 160, 104, 255), width=3)
save(post, "bridge_post.png")

# はしご（縦につなげて使う 1 マスぶん）
lad = Image.new("RGBA", (C, C), (0, 0, 0, 0))
d = ImageDraw.Draw(lad)
d.rectangle([12, 0, 19, C], fill=(150, 104, 60, 255), outline=(80, 52, 28, 255))
d.rectangle([44, 0, 51, C], fill=(150, 104, 60, 255), outline=(80, 52, 28, 255))
for y in (12, 44):
    d.rounded_rectangle([10, y, 54, y + 7], radius=2, fill=(176, 126, 74, 255), outline=(80, 52, 28, 255))
    d.line([(14, y + 3), (18, y + 3)], fill=(196, 160, 104, 255), width=3)
save(lad, "ladder.png")


# ---- 飾り（足場の縁に自動で置く。下端の中央が置く位置） ----

def deco(name, w, h, fn):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fn(ImageDraw.Draw(img), w, h)
    save(img, f"deco_{name}.png")


def moss(d, w, h):
    for i in range(14):
        x = 4 + i * (w - 12) / 14
        hh = rng.integers(10, h - 2)
        d.ellipse([x, h - hh, x + 12, h], fill=(MOSS if i % 2 else MOSS_LIGHT) + (255,))
    for i in range(5):
        x = rng.integers(8, w - 8)
        d.line([(x, h - 4), (x + rng.integers(-6, 6), h - 22)], fill=(120, 150, 60, 255), width=2)


def pebbles(d, w, h):
    for i in range(4):
        x = rng.integers(2, w - 18)
        rw = rng.integers(10, 18)
        d.ellipse([x, h - rw * 0.7, x + rw, h], fill=(96, 94, 100, 255), outline=(44, 42, 48, 255), width=2)


def crystal(d, w, h):
    for cx, ch, cw in [(w // 2, h - 6, 12), (w // 2 - 14, h - 30, 8), (w // 2 + 14, h - 24, 8)]:
        pts = [(cx, h - ch), (cx + cw, h - ch * 0.6), (cx + cw * 0.7, h), (cx - cw * 0.7, h), (cx - cw, h - ch * 0.6)]
        d.polygon(pts, fill=AMBER + (255,), outline=(150, 80, 20, 255))
        d.line([(cx, h - ch + 4), (cx - 2, h - 4)], fill=AMBER_LIGHT + (255,), width=2)


def lantern(d, w, h):
    d.rectangle([w // 2 - 3, 10, w // 2 + 3, h], fill=(110, 76, 44, 255))
    d.line([(w // 2, 10), (w - 10, 10)], fill=(110, 76, 44, 255), width=5)
    lx = w - 14
    d.line([(lx, 10), (lx, 22)], fill=(60, 40, 24, 255), width=2)
    d.polygon([(lx, 22), (lx + 10, 34), (lx + 7, 50), (lx - 7, 50), (lx - 10, 34)], fill=(255, 196, 96, 255), outline=(90, 56, 26, 255))
    d.ellipse([lx - 4, 32, lx + 4, 42], fill=(255, 245, 200, 255))


def roots_hang(d, w, h):
    # 天井から垂れる根（上端の中央が天井につく位置）
    for i in range(4):
        x = 8 + i * (w - 16) / 3
        pts = [(x + rng.integers(-4, 4), 0)]
        for k in range(1, 6):
            pts.append((x + rng.integers(-8, 8), k * (h - 10) / 5 * rng.uniform(0.6, 1.0)))
        d.line(pts, fill=ROOT + (255,), width=6 - i % 2 * 2, joint="curve")


def basket(d, w, h):
    d.polygon([(6, h - 30), (w - 6, h - 30), (w - 12, h), (12, h)], fill=(160, 112, 62, 255), outline=(80, 52, 28, 255))
    for y in range(h - 26, h, 6):
        d.line([(10, y), (w - 10, y)], fill=(120, 80, 40, 255), width=2)
    for i in range(5):
        x = 12 + i * (w - 28) / 4
        d.polygon([(x, h - 30), (x + 6, h - 42), (x + 12, h - 30)], fill=AMBER + (255,))


deco("moss", 64, 28, moss)
deco("pebbles", 64, 20, pebbles)
deco("crystal", 64, 64, crystal)
deco("lantern", 48, 96, lantern)
deco("roots_hang", 64, 96, roots_hang)
deco("basket", 56, 48, basket)


# ---- 中景（足場の後ろ。大きな岩壁と根） ----

def mid_rock(seed):
    w, h = 384, 384
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(seed)
    for _ in range(26):
        rw, rh = r.integers(50, 120), r.integers(40, 100)
        x, y = r.integers(0, w - rw), r.integers(0, h - rh)
        if (x + rw / 2 - w / 2) ** 2 + (y + rh / 2 - h / 2) ** 2 > (w * 0.45) ** 2:
            continue
        sh = r.integers(-10, 10)
        d.ellipse([x, y, x + rw, y + rh], fill=(70 + sh, 66 + sh, 72 + sh, 255), outline=(36, 34, 40, 255), width=4)
    return img


def mid_root(seed):
    w, h = 512, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(seed)
    pts = [(0, h * 0.7)]
    for k in range(1, 9):
        pts.append((k * w / 8, h * 0.5 + r.integers(-60, 60)))
    d.line(pts, fill=(96, 62, 38, 255), width=46, joint="curve")
    d.line([(x, y - 12) for x, y in pts], fill=(130, 88, 54, 255), width=10, joint="curve")
    return img


for i in range(3):
    save(mid_rock(700 + i), f"mid_rock_{i + 1}.png")
save(mid_root(720), "mid_root_1.png")


# ---- 遠景（横につながる 1 枚。左端と右端がつながるように描く） ----
W, H = 1280, 720
far = np.zeros((H, W, 3), np.float32)
ys = np.linspace(0, 1, H)[:, None]
top = np.array([30, 34, 44], np.float32)
bot = np.array([12, 13, 18], np.float32)
far[:] = top * (1 - ys[:, :, None]) + bot * ys[:, :, None]
im = Image.fromarray(far.astype(np.uint8)).convert("RGBA")
d = ImageDraw.Draw(im)
r = np.random.default_rng(900)
# 奥の岩の柱（左右の端でつながるよう、はみ出したら反対側にも描く）
for _ in range(9):
    x = r.integers(0, W)
    pw = r.integers(120, 260)
    col = tuple(int(v) for v in (r.integers(34, 48), r.integers(38, 52), r.integers(48, 62)))
    for ox in (-W, 0, W):
        d.rounded_rectangle([x + ox, r.integers(-40, 120), x + ox + pw, H + 20], radius=60, fill=col + (255,))
# 滝
for ox in (0, W):
    d.rectangle([860 - ox + 0, 0, 878 - ox, H], fill=(70, 96, 120, 255))
im = im.filter(ImageFilter.GaussianBlur(3))
save(im, "far.png")


# ---- 前景（画面の手前を通る根。暗く塗られる） ----
fg = Image.new("RGBA", (256, 512), (0, 0, 0, 0))
d = ImageDraw.Draw(fg)
pts = [(128 + r.integers(-40, 40), k * 64) for k in range(9)]
d.line(pts, fill=(70, 46, 30, 255), width=70, joint="curve")
d.line([(x - 20, y) for x, y in pts], fill=(100, 66, 40, 255), width=12, joint="curve")
save(fg, "fg_root_1.png")


# ---- 型紙：地形 16 マスの並び ----
font = ImageFont.truetype("/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf", 15)
G = 160
guide = Image.new("RGB", (G * 4, G * 4), (235, 230, 220))
d = ImageDraw.Draw(guide)
for m in range(16):
    gx, gy = (m % 4) * G, (m // 4) * G
    d.rectangle([gx, gy, gx + G - 1, gy + G - 1], outline=(150, 140, 130))
    t = terrain_tile(m, 100 + m).resize((96, 96), Image.NEAREST)
    guide.paste(t, (gx + 32, gy + 30), t)
    # 開いている辺（空気に面する辺）を赤で示す
    x0, y0, x1, y1 = gx + 32, gy + 30, gx + 128, gy + 126
    if not m & 1:
        d.line([x0, y0 - 4, x1, y0 - 4], fill=(220, 40, 40), width=4)
    if not m & 2:
        d.line([x1 + 4, y0, x1 + 4, y1], fill=(220, 40, 40), width=4)
    if not m & 4:
        d.line([x0, y1 + 4, x1, y1 + 4], fill=(220, 40, 40), width=4)
    if not m & 8:
        d.line([x0 - 4, y0, x0 - 4, y1], fill=(220, 40, 40), width=4)
    d.text((gx + 6, gy + 4), f"{m}", font=font, fill=(40, 40, 40))
    d.text((gx + 6, gy + G - 22), "赤＝空気に面する辺", font=font, fill=(160, 40, 40)) if m == 0 else None
guide.save(os.path.join(GUIDE, "terrain_guide.png"))
print("wrote _guide/terrain_guide.png")
