# キャラ絵1枚をパーツ（体・腕・脚2本・つるはし）に分ける
import json, sys
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFilter

SRC, OUT = sys.argv[1], sys.argv[2]
S = 0.12  # 書き出しの縮小率
im = Image.open(SRC).convert("RGBA")
W, H = im.size
a = np.array(im)
a[a[:, :, 3] < 16] = 0
FEET = (670, 1197)  # 足元の中心（原寸座標）

def mask_poly(pts, grow=0):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    if grow:
        m = m.filter(ImageFilter.MaxFilter(grow * 2 + 1))
    return np.array(m) > 0

# 腕（ひじの袖口から先）
arm_m = mask_poly([(498, 690), (505, 676), (530, 666), (575, 663), (600, 680), (606, 705), (598, 728),
                   (586, 742), (584, 800), (572, 818), (570, 866), (540, 874), (500, 862), (486, 832),
                   (494, 806), (520, 798), (520, 742), (504, 730)], grow=3)
arm_m &= a[:, :, 3] > 0
# 脚（スカートの下）
CUT = 1000
yy, xx = np.mgrid[0:H, 0:W]
legs_m = (yy >= CUT) & (a[:, :, 3] > 0) & (xx > 480) & (xx < 870)
back_m = legs_m & (xx < 660)
front_m = legs_m & (xx >= 660)

def piece(m):
    p = a.copy()
    p[~m] = 0
    return p

def extend_up(p, n=40):
    # 回したときに隙間が出ないよう、脚の上端を上へ伸ばす（スカートの陰に隠れる）
    ys = np.where(p[:, :, 3].max(axis=1) > 0)[0]
    top = ys.min()
    row = p[top + 4].copy()
    for k in range(1, n):
        p[top - k] = np.where(row[:, 3:4] > 0, row, p[top - k])
    return p

body = a.copy()
body[legs_m] = 0
# 腕を抜いた穴を周りの色で埋める
hole = (arm_m).astype(np.uint8) * 255
rgb = cv2.inpaint(np.ascontiguousarray(body[:, :, :3]), hole, 7, cv2.INPAINT_TELEA)
alpha = cv2.inpaint(np.ascontiguousarray(body[:, :, 3]), hole, 7, cv2.INPAINT_TELEA)
body = np.dstack([rgb, alpha])
body[legs_m] = 0

parts = {
    "body": (body, FEET),
    "arm": (piece(arm_m), (552, 688)),
    "leg_back": (extend_up(piece(back_m)), (585, 1000)),
    "leg_front": (extend_up(piece(front_m)), (748, 1000)),
}

# つるはし（絵の画風に合わせて描く：木の柄と石の刃、縄の巻き）
PW, PH = 420, 460
pk = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
d = ImageDraw.Draw(pk)
ol = (52, 30, 18, 255)
d.line([(210, 440), (210, 70)], fill=ol, width=30)
d.line([(210, 436), (210, 74)], fill=(140, 92, 52, 255), width=18)
d.line([(204, 430), (204, 80)], fill=(176, 124, 76, 255), width=5)
head = [(20, 120), (90, 70), (210, 48), (330, 70), (400, 120), (330, 98), (210, 86), (90, 98)]
d.polygon(head, fill=ol)
inner = [(42, 112), (96, 80), (210, 60), (324, 80), (378, 112), (326, 92), (210, 76), (94, 92)]
d.polygon(inner, fill=(150, 156, 164, 255))
d.line([(100, 84), (210, 66), (320, 84)], fill=(205, 210, 216, 255), width=5)
for y in range(96, 140, 12):
    d.line([(190, y), (230, y + 6)], fill=(214, 190, 140, 255), width=6)
pk_a = np.array(pk)
parts["pickaxe"] = (pk_a, (210, 400))

meta = {"scale": S, "parts": {}}
for name, (arr, pivot) in parts.items():
    img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    bbox = img.getbbox()
    img = img.crop(bbox)
    w, h = img.size
    img = img.resize((max(1, round(w * S)), max(1, round(h * S))), Image.LANCZOS)
    img.save(f"{OUT}/{name}.png")
    # 回転の軸を、切り抜いた絵の左上からの位置（縮小後）で記録
    meta["parts"][name] = {
        "pivot": [round((pivot[0] - bbox[0]) * S, 2), round((pivot[1] - bbox[1]) * S, 2)],
        "origin": [round((pivot[0] - FEET[0]) * S, 2), round((pivot[1] - FEET[1]) * S, 2)] if name != "pickaxe" else [0, 0],
        "size": [img.size[0], img.size[1]],
    }
# 手の中でつるはしを握る位置（腕の軸から見た位置）
meta["grip"] = [round((530 - 552) * S, 2), round((838 - 688) * S, 2)]
json.dump(meta, open(f"{OUT}/rig.json", "w"), indent=1)
print(json.dumps(meta, indent=1))
