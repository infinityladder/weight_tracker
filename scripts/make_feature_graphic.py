"""
Play feature graphic: 1024x500, 24-bit PNG (no alpha), from the newest generation's raw phone
captures. Reuses make_slides' backdrop, fonts and palette so it matches the slides.

    python scripts/make_feature_graphic.py slides_config.py

Reads FEATURE from the slides config (see slides_config.example.py):

    FEATURE = dict(
        icon="logo/app-icon-512.png",          # square app icon, any size
        head=["SIMPLE", "BODY LOG"],           # 1-2 lines; the line at accent_line is in the accent
        accent_line=1,
        sub=["Weight and body measurements,", "on one body map."],   # 0-2 short lines
        shots=[("07-female", "light"), ("01-home", "dark")],          # back phone, front phone
        hue="body", ground="dark",
    )

Writes <screenshots>/<newest generation>/marketing/feature-graphic.png.
Layout: icon, name and sub on the left; two angled phones on the right, bleeding off the
bottom edge. The centre stays fairly clear because Play puts a play button there when the
listing has a promo video.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_slides as ms  # noqa: E402
import shot_sets  # noqa: E402

W, H = 1024, 500


def phone(src, height, bezel, radius):
    """The slides' generic frame without the camera dot (at this size it covers the app bar).
    Sized by screen height so portrait and landscape captures both fit the band."""
    px = ms.px
    fh = px(height)
    fw = int(round(fh * src.width / src.height))
    bw, bh = fw + px(bezel) * 2, fh + px(bezel) * 2
    layer = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    layer.paste(Image.new("RGB", (bw, bh), (0x0C, 0x0E, 0x11)), (0, 0), ms.rounded((bw, bh), px(radius)))
    layer.paste(src.resize((fw, fh), Image.LANCZOS), (px(bezel), px(bezel)),
                ms.rounded((fw, fh), px(radius - bezel)))
    ImageDraw.Draw(layer).rounded_rectangle([0, 0, bw - 1, bh - 1], radius=px(radius),
                                            outline=(0x3A, 0x40, 0x48, 255), width=px(1.5))
    return layer


def build(config_path):
    ms.C = C = ms.load_config(config_path)
    F = C.FEATURE
    ms.W, ms.H = W, H
    px = ms.px
    gen = shot_sets.current(C.SCREENSHOTS)
    phone_raw = next(f["raw"] for f in C.FORMATS.values() if not f["wide"])
    ms.RAW = gen / "raw" / phone_raw

    cv = ms.Canvas(F.get("ground", "dark"))
    ms.backdrop(cv, F["hue"], 0.05)
    P = cv.P

    back_key, front_key = F["shots"]
    back = phone(ms.source(*back_key), 437, bezel=8, radius=30)
    front = phone(ms.source(*front_key), 478, bezel=9, radius=32)
    ms.place(cv, back, px(790), px(92), F["hue"], angle=-6)
    ms.place(cv, front, px(605), px(58), F["hue"], angle=4)

    x, y = 64, 84
    if F.get("icon"):
        icon = Image.open(F["icon"]).convert("RGB").resize((px(84), px(84)), Image.LANCZOS)
        cv.base.paste(icon, (px(x), px(y)), ms.rounded(icon.size, px(20)))
        y += 106
    size = F.get("head_size", 76)
    f = ms.font(size, True)
    for n, line in enumerate(F["head"]):
        accent = n == F.get("accent_line", len(F["head"]) - 1)
        cv.d.text((px(x), px(y)), line, font=f, fill=ms.rgba(P["accent"] if accent else P["text"]), anchor="lt")
        y += size * 1.03
    y += 26
    fs = ms.font(23, False)
    for line in F.get("sub", []):
        cv.d.text((px(x), px(y)), line, font=fs, fill=ms.rgba(P["text"], 0.8), anchor="lt")
        y += 31

    img = cv.base.resize((W, H), Image.LANCZOS).convert("RGB")
    out = gen / "marketing" / "feature-graphic.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, "PNG", optimize=True)
    print(f"{out}  {img.size[0]}x{img.size[1]} {img.mode}  -- LOOK AT IT")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    build(sys.argv[1])
