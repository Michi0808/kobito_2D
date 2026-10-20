"""森（ベリーの森）の手描き素材を、ゲームで使う大きさに整えて art/forest/ に書き出す。

    python3 tools/build_forest_art.py art_src art/forest

元の素材は art_src/ の下の berry_forest_all_images_36/（森）、berry_transport_11_4/（運ぶ道具）、
berry_mid_trees/（中景の木。1本ずつ完結して描いたもの）、berry_climb_tree/（登れる大木の幹・枝・葉の房）から読む。

- 透明な余白を切り落とし、ゲームの中で表示する大きさの 2 倍に縮める（ゲームでは 0.5 倍で表示）。
- 籠の奥（back）と手前（front）は、重ねたときにずれないよう同じ枠で切る。
- 地面の縁（edge_top）は横につないでも継ぎ目が目立たないよう、両端を混ぜる。
- 登れる大木のパーツ（CLIMB）は余白を切らずに半分の大きさにするだけ。幹のつなぎ目や枝の上面・
  実を吊る茎の位置は元の絵の px で scripts/forest_art.gd に書いてあるので、切ると合わなくなる。
- 当たり判定の位置（枝の上面・籠の縁・葉の坂）は scripts/forest_art.gd に数値で書いてある。
  素材を描き直して形が大きく変わったら、そこも合わせる。

Pillow と numpy が必要。
"""
import os
import sys

import numpy as np
from PIL import Image

# 出力名: (元の場所 f=森 / t=運ぶ道具 / m=中景の木, 元のファイル名, 横幅か高さの上限 px（2 倍の大きさ）, 余白を切るか)
FILES = {
    # 背景
    "far": ("f", "11.1_backgrounds/berry_far.png", 1672, False),
    "mid_bush_01": ("f", "11.1_backgrounds/berry_mid_bush_01.png", 1000, True),
    "mid_bush_02": ("f", "11.1_backgrounds/berry_mid_bush_02.png", 1000, True),
    "mid_old_arch": ("f", "11.1_backgrounds/berry_mid_old_arch.png", 1000, True),
    # 中景の木（端で切れない 1 本ずつの木。光の差す隙間・枝の絵は端で幹が切れるので使わない）
    "mid_tree_a": ("m", "tree_a.png", 1100, True),
    "mid_tree_b": ("m", "tree_b.png", 1100, True),
    "mid_tree_c": ("m", "tree_c.png", 1100, True),
    "mid_tree_d": ("m", "tree_d.png", 1100, True),
    "mid_branch_a": ("m", "branch_a.png", 800, True),
    "fg_leaf_01": ("f", "11.1_backgrounds/berry_fg_leaf_01.png", 800, True),
    "fg_vine_01": ("f", "11.1_backgrounds/berry_fg_vine_01.png", 900, True),
    # 地形・足場
    "ground_texture": ("f", "11.2_terrain/berry_ground_texture.png", 512, False),
    "edge_top": ("f", "11.2_terrain/berry_edge_top.png", 1024, False),
    "platform_branch": ("f", "11.2_terrain/berry_platform_branch.png", 640, False),
    "thin_branch_base": ("f", "11.2_terrain/berry_thin_branch_base.png", 480, True),
    "rock_01": ("f", "11.2_terrain/berry_rock_01.png", 420, True),
    "root_slope": ("f", "11.2_terrain/berry_root_slope.png", 640, True),
    # 実
    "fruit_black_ripe_s": ("f", "11.3_fruits/berry_fruit_black_ripe_s.png", 128, True),
    "fruit_black_ripe_m_01": ("f", "11.3_fruits/berry_fruit_black_ripe_m_01.png", 128, True),
    "fruit_black_ripe_m_02": ("f", "11.3_fruits/berry_fruit_black_ripe_m_02.png", 128, True),
    "fruit_black_ripe_l": ("f", "11.3_fruits/berry_fruit_black_ripe_l.png", 128, True),
    "fruit_black_unripe_m": ("f", "11.3_fruits/berry_fruit_black_unripe_m.png", 128, True),
    "fruit_red_ripe_m": ("f", "11.3_fruits/berry_fruit_red_ripe_m.png", 128, True),
    "fruit_red_unripe_m": ("f", "11.3_fruits/berry_fruit_red_unripe_m.png", 128, True),
    "fruit_straw_ripe_l": ("f", "11.3_fruits/berry_fruit_straw_ripe_l.png", 160, True),
    "fruit_straw_calyx": ("f", "11.3_fruits/berry_fruit_straw_calyx.png", 160, True),
    "fruit_stem": ("f", "11.3_fruits/berry_fruit_stem.png", 96, True),
    # 運ぶ道具
    "leaf_ramp": ("t", "berry_leaf_ramp.png", 360, True),
}
# 登れる大木のパーツ（余白を切らず、元の絵の半分の大きさで書き出す）
CLIMB = ["trunk_base", "trunk_mid", "trunk_top", "branch_long", "branch_short",
         "leaf_cluster_a", "leaf_cluster_b", "leaf_cluster_c"]
CLIMB_EXPORT = 0.5
# 同じ枠で切る組（奥・手前）
PAIRS = {
    "basket": ("berry_basket_back.png", "berry_basket_front.png", 400),
}


def alpha_bbox(im):
    return im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()


def fit(im, limit):
    w, h = im.size
    s = limit / max(w, h)
    if s >= 1.0:
        return im
    return im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


def seamless_x(im, band=96):
    """右端の band px を左端に重ねて混ぜ、横に並べたとき継ぎ目が出ないようにする。"""
    a = np.asarray(im).astype(np.float32)
    w = a.shape[1]
    left = a[:, :band].copy()
    right = a[:, w - band:]
    t = np.linspace(0.0, 1.0, band)[None, :, None]
    a[:, :band] = right * (1 - t) + left * t
    a = a[:, : w - band]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), im.mode)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    root = sys.argv[1]
    src = {
        "f": os.path.join(root, "berry_forest_all_images_36"),
        "t": os.path.join(root, "berry_transport_11_4"),
        "m": os.path.join(root, "berry_mid_trees"),
        "c": os.path.join(root, "berry_climb_tree"),
    }
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for name, (where, path, limit, crop) in FILES.items():
        im = Image.open(os.path.join(src[where], path))
        im = im.convert("RGBA" if "A" in im.mode else "RGB")
        if crop:
            im = im.crop(alpha_bbox(im))
        if name == "edge_top":
            im = seamless_x(im)
        im = fit(im, limit)
        im.save(os.path.join(out, name + ".png"), optimize=True)
        print(name, im.size)
    for name in CLIMB:
        im = Image.open(os.path.join(src["c"], name + ".png")).convert("RGBA")
        w, h = im.size
        im = im.resize((round(w * CLIMB_EXPORT), round(h * CLIMB_EXPORT)), Image.LANCZOS)
        im.save(os.path.join(out, "climb_" + name + ".png"), optimize=True)
        print("climb_" + name, im.size)
    for name, (back, front, limit) in PAIRS.items():
        b = Image.open(os.path.join(src["t"], back)).convert("RGBA")
        f = Image.open(os.path.join(src["t"], front)).convert("RGBA")
        bb, fb = alpha_bbox(b), alpha_bbox(f)
        box = (min(bb[0], fb[0]), min(bb[1], fb[1]), max(bb[2], fb[2]), max(bb[3], fb[3]))
        for suffix, im in (("back", b), ("front", f)):
            im = fit(im.crop(box), limit)
            im.save(os.path.join(out, "%s_%s.png" % (name, suffix)), optimize=True)
            print(name + "_" + suffix, im.size)


if __name__ == "__main__":
    main()
