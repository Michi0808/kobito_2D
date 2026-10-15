"""森（ベリーの森）の手描き素材を、ゲームで使う大きさに整えて art/forest/ に書き出す。

    python3 tools/build_forest_art.py art_src/berry_forest_all_images_36 art_src/berry_transport_11_4 art/forest

- 透明な余白を切り落とし、ゲームの中で表示する大きさの 2 倍に縮める（ゲームでは 0.5 倍で表示）。
- 籠の奥（back）と手前（front）は、重ねたときにずれないよう同じ枠で切る。
- 地面の縁（edge_top）は横につないでも継ぎ目が目立たないよう、両端を混ぜる。
- 当たり判定の位置（枝の上面・籠の縁・葉の坂）は scripts/forest_art.gd に数値で書いてある。
  素材を描き直して形が大きく変わったら、そこも合わせる。

Pillow と numpy が必要。
"""
import os
import sys

import numpy as np
from PIL import Image

# 出力名: (元の場所 f=森 / t=運ぶ道具, 元のファイル名, 横幅か高さの上限 px（2 倍の大きさ）, 余白を切るか)
FILES = {
    # 背景
    "far": ("f", "11.1_backgrounds/berry_far.png", 1672, False),
    "mid_bush_01": ("f", "11.1_backgrounds/berry_mid_bush_01.png", 1000, True),
    "mid_bush_02": ("f", "11.1_backgrounds/berry_mid_bush_02.png", 1000, True),
    "mid_light_gap": ("f", "11.1_backgrounds/berry_mid_light_gap.png", 1000, True),
    "mid_old_arch": ("f", "11.1_backgrounds/berry_mid_old_arch.png", 1000, True),
    "mid_branch_01": ("f", "11.1_backgrounds/berry_mid_branch_01.png", 1000, True),
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
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)
    src = {"f": sys.argv[1], "t": sys.argv[2]}
    out = sys.argv[3]
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
