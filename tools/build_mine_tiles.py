# 坑道の素材（岩肌と縁の部品）から、ゲームが使う地面タイルを組み立てて art/mine/ に置く。
#
#   python3 tools/build_mine_tiles.py <素材フォルダ> art/mine
#
# 素材フォルダには「坑道グラフィック制作要件」の名前のPNGを置く
# （rock_texture / edge_top / edge_bottom / edge_side と、そのまま使う素材）。
# corners.png は岩の描き方がほかの縁と合わなかったので使わず、角は丸く削って作る。
#
# 出力：
#   terrain.png      512×1024。行 = つながりの番号（上1 + 右2 + 下4 + 左8 が地面）、列 = 柄 8 通り
#   terrain_fill.png rock_texture を縁に合わせた版。8×8 マスに切って、位置で選ぶ（どこでも継ぎ目なし）
#   ほかの素材はそのままコピー
#
# 柄は「横に続く縁なら x % 8、縦に続く縁なら y % 8」で選ぶので、帯の素材が途切れずにつながる。
import os, shutil, sys
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
C = 64
V = 8  # 柄の数（512 / 64）

COPY = [
    "far", "ladder", "bridge_post", "platform_root", "platform_plank",
    "ore_rock", "ore_amber", "ore_bark", "ore_root", "ore_bedrock",
    "deco_moss", "deco_moss_v2", "deco_pebbles", "deco_pebbles_v2",
    "deco_crystal", "deco_crystal_v2", "deco_lantern", "deco_lantern_v2",
    "deco_basket", "deco_basket_v2", "deco_roots_hang", "deco_roots_hang_v2",
    "mid_rock_wall", "mid_root_arch", "mid_tunnel", "mid_pulley", "mid_workshop",
    "fg_roots", "fg_vines",
]


def load(name):
    return np.array(Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")).astype(np.float32) / 255.0


top = load("edge_top")
bottom = load("edge_bottom")
side = load("edge_side")  # 右側が空気に面する


def fit_rock(img):
    """岩肌は縁の部品より石が大きく色も明るいので、半分に縮めて 2×2 に並べ、縁の岩の色に合わせる"""
    small = np.array(Image.fromarray((img * 255).astype(np.uint8)).resize((256, 256), Image.LANCZOS)).astype(np.float32) / 255.0
    r = np.tile(small, (2, 2, 1))
    ref = np.concatenate([top[24:, :, :3].reshape(-1, 3), side[:, :40, :3].reshape(-1, 3)])
    cur = r[:, :, :3].reshape(-1, 3)
    r[:, :, :3] = (r[:, :, :3] - cur.mean(0)) / (cur.std(0) + 1e-6) * ref.std(0) + ref.mean(0)
    r[:, :, :3] = np.clip(r[:, :, :3], 0, 1)
    r[:, :, 3] = 1.0
    return r


rock = fit_rock(load("rock_texture"))

# 二辺が空気に面する外側の角は、この半径で丸く削る
RADIUS = 18
yy, xx = np.mgrid[0:C, 0:C].astype(np.float32) + 0.5


def round_corner(alpha, cx, cy):
    """(cx, cy) の角を丸める。cx, cy は 0 か C"""
    ox = RADIUS if cx == 0 else C - RADIUS
    oy = RADIUS if cy == 0 else C - RADIUS
    inx = (xx < ox) if cx == 0 else (xx > ox)
    iny = (yy < oy) if cy == 0 else (yy > oy)
    d = np.sqrt((xx - ox) ** 2 + (yy - oy) ** 2)
    keep = np.clip(RADIUS + 0.5 - d, 0, 1)
    alpha *= np.where(inx & iny, keep, 1.0)


def over(dst, src):
    """src を dst の上に重ねる（どちらも RGBA の 0〜1）"""
    a = src[:, :, 3:4]
    dst[:, :, :3] = src[:, :, :3] * a + dst[:, :, :3] * (1 - a)


def tile(mask, v):
    n, e, s, w = mask & 1, mask & 2, mask & 4, mask & 8
    # 横に続く縁なら x 方向、縦に続く縁なら y 方向の柄を使う
    vertical = bool(n and s)
    rx, ry = (v * 3 % V, v) if vertical else (v, v * 5 % V)
    t = rock[ry * C:(ry + 1) * C, rx * C:(rx + 1) * C].copy()
    alpha = np.ones((C, C), np.float32)
    band = slice(v * C, (v + 1) * C)
    if not e:
        sd = side[band, :]
        over(t, sd)
        alpha *= sd[:, :, 3]
    if not w:
        sd = side[band, ::-1]
        over(t, sd)
        alpha *= sd[:, :, 3]
    if not s:
        # 下の縁の一番上の数行は透明なので、その分だけ上に詰める
        b = np.zeros((C, C, 4), np.float32)
        b[:C - 4] = bottom[4:, band]
        b[:2, :, 3] = 1.0
        over(t, b)
        alpha *= b[:, :, 3]
    if not n:
        tp = top[:, band]
        over(t, tp)
        alpha *= tp[:, :, 3]
    if not n and not w:
        round_corner(alpha, 0, 0)
    if not n and not e:
        round_corner(alpha, C, 0)
    if not s and not w:
        round_corner(alpha, 0, C)
    if not s and not e:
        round_corner(alpha, C, C)
    t[:, :, 3] = alpha
    return t


os.makedirs(OUT, exist_ok=True)
sheet = np.zeros((16 * C, V * C, 4), np.float32)
for m in range(16):
    for v in range(V):
        sheet[m * C:(m + 1) * C, v * C:(v + 1) * C] = tile(m, v)
Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "terrain.png"))
print("wrote terrain.png")
Image.fromarray((rock * 255).astype(np.uint8)).save(os.path.join(OUT, "terrain_fill.png"))
print("wrote terrain_fill.png")
for name in COPY:
    shutil.copy(os.path.join(SRC, name + ".png"), os.path.join(OUT, name + ".png"))
print("copied", len(COPY), "files")
