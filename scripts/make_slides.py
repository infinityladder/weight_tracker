"""
Turn raw captures into Play Store screenshot slides.

    python make_slides.py slides_config.py                    # every format, every slide
    python make_slides.py slides_config.py phone              # one format
    python make_slides.py slides_config.py --only 3,share     # some slides (number or name)
    python make_slides.py slides_config.py --list             # the plan, with headlines

Everything app-specific is in the config file (copy slides_config.example.py): where the
generations live, the formats, the palette, the font, the backdrop hues and the slides.

Reads   <screenshots>/<newest generation>/raw/<format raw folder>/<key>-<theme>.png
Writes  <screenshots>/<newest generation>/marketing/<format>/01-<name>.png ... 08
        plus _thumbnail-test.png (the set at Play's search-result size -- the gate)

Each slide: a gradient backdrop in the slide's hue, a two-line headline with ONE word in the
accent colour, a sub line, and the real screens in drawn device frames. Layouts:

    single   one device                      (portrait: centred under the type;
                                              landscape: type column left, device right)
    pair     two devices side by side         (e.g. the same screen dark + light, or two
                                              screens of one feature, one per theme)
    fan      3-4 small devices in an arc      (e.g. every palette at once)

Rendered at 2x and downsampled (corners and hairlines alias otherwise). Output is RGB --
Play rejects alpha. Also prints how much of each slide the text covers: Play's rule for
recommendation placements is 20% at most.
"""
import importlib.util
import re
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shot_sets  # noqa: E402

S = 2                      # render scale
W = H = 0                  # current frame, set per format
C = None                   # the loaded config


def px(v):
    return int(round(v * S))


def rgba(c, a=1.0):
    return (*c, int(round(a * 255)))


def font(size, bold=True):
    path = C.HEADLINE_FONT if bold else getattr(C, "BODY_FONT", C.HEADLINE_FONT)
    f = ImageFont.truetype(str(path), px(size))
    axes = getattr(C, "HEADLINE_WEIGHT" if bold else "BODY_WEIGHT", None)
    if axes is not None:
        try:
            f.set_variation_by_axes([axes])
        except Exception:
            pass                               # a static font has no axes
    return f


# --- canvas and ground -------------------------------------------------------------------

class Canvas:
    def __init__(self, ground):
        self.P = C.PALETTE[ground]
        self.dark = ground == "dark"
        self.base = Image.new("RGB", (W * S, H * S), self.P["ground"])
        self.d = ImageDraw.Draw(self.base, "RGBA")
        self.text_box = None

    def finish(self, path):
        img = self.base.resize((W, H), Image.LANCZOS)
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path, "PNG", optimize=True)
        share = 0.0
        if self.text_box:
            x0, y0, x1, y1 = self.text_box
            share = (x1 - x0) * (y1 - y0) / (W * H * S * S)
        flag = "  <-- over Play's 20% text limit" if share > 0.20 else ""
        print(f"  {path.name:28} {img.size[0]}x{img.size[1]}  text {share:4.0%}{flag}")


def backdrop(cv, hue, bloom_at):
    """Diagonal two-stop gradient in the slide's hue, plus a soft bloom behind the subject."""
    top, bottom, bloom_colour = C.HUES["dark" if cv.dark else "light"][hue]
    grad = Image.new("RGB", (W * S, H * S))
    d = ImageDraw.Draw(grad)
    span = (W + H) * S
    for i in range(span):
        f = i / span
        d.line([(i, 0), (0, i)], fill=tuple(int(top[k] + (bottom[k] - top[k]) * f) for k in range(3)))
    cv.base.paste(grad, (0, 0))
    bloom = Image.new("RGB", (W * S, H * S), (0, 0, 0) if cv.dark else (255, 255, 255))
    r = min(W, H) * 0.45
    ImageDraw.Draw(bloom).ellipse(
        [px(W / 2 - r), px(H * bloom_at), px(W / 2 + r), px(H * bloom_at + r * 1.7)],
        fill=tuple(int(c * 0.42) if cv.dark else 255 - int((255 - c) * 0.22) for c in bloom_colour))
    op = ImageChops.screen if cv.dark else ImageChops.multiply
    cv.base.paste(op(cv.base, bloom.filter(ImageFilter.GaussianBlur(px(150)))), (0, 0))


def scanlines(cv):
    if not getattr(C, "SCANLINES", False):
        return
    a = 26 if cv.dark else 13
    for y in range(0, H, 3):
        cv.d.line([(0, px(y)), (px(W), px(y))], fill=(0, 0, 0, a), width=px(1))


def headline(cv, slide, x, y, size, sub_size):
    """Two lines, one word in the accent. Records the text's bounding box for the 20% check."""
    P = cv.P
    f = font(size, True)
    lead = 1.1
    right = x
    for n, line in enumerate(slide["head"]):
        ly = y + n * size * lead
        wx = x
        for word in line.split(" "):
            hit = word.strip(",.!?").upper() == slide["accent_word"].upper()
            cv.d.text((px(wx), px(ly)), word, font=f, fill=rgba(P["accent"] if hit else P["text"]), anchor="lt")
            wx += cv.d.textlength(word + " ", font=f) / S
        right = max(right, wx)
    bottom = y + len(slide["head"]) * size * lead
    if slide.get("sub"):
        sy = bottom + size * 0.22
        fs = font(sub_size, False)
        cv.d.text((px(x), px(sy)), slide["sub"], font=fs, fill=rgba(P["text"], 0.78), anchor="lt")
        right = max(right, x + cv.d.textlength(slide["sub"], font=fs) / S)
        bottom = sy + sub_size * 1.3
    cv.text_box = (px(x), px(y), px(right), px(bottom))


# --- devices -------------------------------------------------------------------------------

def rounded(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def source(key, theme):
    path = RAW / f"{key}-{theme}.png"
    if not path.exists():
        raise SystemExit(f"missing capture: {path}")
    return Image.open(path).convert("RGB")


def device(src, width, bezel=24, radius=70, keys="right"):
    """A generic device (no brand or model) around the screen: bezel, punch-hole camera on the
    current top edge, and buttons on the edge they really sit on for the orientation."""
    nub = 7
    fw = px(width)
    fh = int(round(fw * src.height / src.width))
    bw, bh = fw + px(bezel) * 2, fh + px(bezel) * 2
    pad_x, pad_y = (px(nub), 0) if keys == "right" else (0, px(nub)) if keys == "top" else (0, 0)
    layer = Image.new("RGBA", (bw + pad_x, bh + pad_y), (0, 0, 0, 0))
    body = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    body.paste(Image.new("RGB", (bw, bh), (0x0C, 0x0E, 0x11)), (0, 0), rounded((bw, bh), px(radius)))
    body.paste(src.resize((fw, fh), Image.LANCZOS), (px(bezel), px(bezel)), rounded((fw, fh), px(max(radius - bezel, 8))))
    dd = ImageDraw.Draw(body)
    dd.ellipse([bw // 2 - px(14), px(bezel) + px(18), bw // 2 + px(14), px(bezel) + px(46)], fill=(4, 5, 6, 255))
    dd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=px(radius), outline=(0x3A, 0x40, 0x48, 255), width=px(2))
    layer.paste(body, (0, pad_y))
    d = ImageDraw.Draw(layer)
    if keys == "right":
        for at, run in ((px(430), px(210)), (px(680), px(120))):
            d.rounded_rectangle([bw - px(4), at, bw + px(nub), at + run], radius=px(4), fill=(0x53, 0x59, 0x62, 255))
    elif keys == "top":
        for at, run in ((int(bw * 0.58), px(210)), (int(bw * 0.74), px(120))):
            d.rounded_rectangle([at, 0, at + run, px(nub) + px(4)], radius=px(4), fill=(0x53, 0x59, 0x62, 255))
    return layer


def place(cv, layer, x, y, hue, angle=0.0):
    """Drop a device on the ground: a halo of the hue under it on dark grounds, a cast shadow
    on light ones (a near-black screen on a dark ground has no edge without the halo)."""
    if angle:
        layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    full = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    full.paste(layer, (x, y))
    if cv.dark:
        bloom_colour = C.HUES["dark"][hue][2]
        halo = Image.new("RGB", (W * S, H * S), (0, 0, 0))
        ImageDraw.Draw(halo).rounded_rectangle([x, y, x + layer.size[0], y + layer.size[1]], radius=px(60),
                                               fill=tuple(int(c * 0.55) for c in bloom_colour))
        cv.base.paste(ImageChops.screen(cv.base, halo.filter(ImageFilter.GaussianBlur(px(46)))), (0, 0))
    m = Image.new("L", (W * S, H * S), 0)
    m.paste(full.split()[3], (0, px(30)))
    cv.base.paste((0, 0, 0), (0, 0), m.filter(ImageFilter.GaussianBlur(px(34))).point(
        lambda v: int(v * (0.45 if cv.dark else 0.30))))
    cv.base.paste(full, (0, 0), full)


# --- layouts -------------------------------------------------------------------------------
# Portrait frames put the type on top; landscape frames have little height, so a single
# device goes beside a type column and pairs go under a headline that runs across the top.

def l_single(cv, slide, wide):
    if not wide:
        backdrop(cv, slide["hue"], 0.44)
        headline(cv, slide, 104, 196, 124, 46)
        body = device(source(*slide["shots"][0]), width=int(W * 0.75))
        place(cv, body, px(W / 2) - body.size[0] // 2, px(H * 0.32), slide["hue"])
    else:
        backdrop(cv, slide["hue"], 0.30)
        headline(cv, slide, 150, H * 0.39, 104, 42)
        body = device(source(*slide["shots"][0]), width=int(W * 0.58), bezel=20, radius=46, keys="top")
        place(cv, body, px(W * 0.45), px(H / 2) - body.size[1] // 2, slide["hue"])
    scanlines(cv)


def l_pair(cv, slide, wide):
    if not wide:
        backdrop(cv, slide["hue"], 0.42)
        headline(cv, slide, 104, 196, 124, 46)
        top = getattr(C, "PAIR_TOP_PORTRAIT", 0.35)    # where the left device starts (x H)
        width, gap, ys, kw = int(W * 0.445), 36, (H * top, H * (top + 0.056)), dict(bezel=22, radius=64)
    else:
        backdrop(cv, slide["hue"], 0.36)
        headline(cv, slide, 150, 96, 104, 42)
        width, gap, ys, kw = int(W * 0.453), 56, (H * 0.347, H * 0.389), dict(bezel=20, radius=46, keys="top")
    bodies = [device(source(k, t), width=width, **kw) for k, t in slide["shots"]]
    x = px(W / 2) - (sum(b.size[0] for b in bodies) + px(gap)) // 2
    for i, body in enumerate(bodies):
        place(cv, body, x, px(ys[i]), slide["hue"])
        x += body.size[0] + px(gap)
    scanlines(cv)


def swatches(cv, x, y, colours, d=50, gap=68):
    for i, c in enumerate(colours):
        cv.d.ellipse([px(x + i * gap), px(y), px(x + i * gap + d), px(y + d)], fill=rgba(c))


def l_fan(cv, slide, wide):
    shots = slide["shots"]
    n = len(shots)
    if not wide:
        backdrop(cv, slide["hue"], 0.38)
        headline(cv, slide, 104, 188, 118, 46)
        if slide.get("swatches"):
            swatches(cv, 104, 620, slide["swatches"])
        angles = [(-5, -2, 2, 5)[i] if n == 4 else (i - (n - 1) / 2) * 3 for i in range(n)]
        step = W * 0.242
        for i, (k, t) in enumerate(shots):
            body = device(source(k, t), width=int(W * 0.444), bezel=18, radius=54)
            turned = body.rotate(angles[i], resample=Image.BICUBIC, expand=True)
            x = px(W / 2 + (i - (n - 1) / 2) * step) - turned.size[0] // 2
            drop = 58 if i in (0, n - 1) else 0
            full = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
            full.paste(turned, (x, px(800 + drop)))
            m = Image.new("L", (W * S, H * S), 0)
            m.paste(full.split()[3], (0, px(22)))
            cv.base.paste((0, 0, 0), (0, 0), m.filter(ImageFilter.GaussianBlur(px(28))).point(lambda v: int(v * 0.5)))
            cv.base.paste(full, (0, 0), full)
    else:
        backdrop(cv, slide["hue"], 0.30)
        headline(cv, slide, 150, 520, 104, 42)
        if slide.get("swatches"):
            swatches(cv, 150, 870, slide["swatches"])
        cw = 670
        for i, (k, t) in enumerate(shots[:4]):
            body = device(source(k, t), width=cw, bezel=16, radius=42, keys=None)
            ch = body.size[1] / S
            x = px(1120 + (i % 2) * (cw + 72))
            y = px(H / 2 - ch - 26) + (i // 2) * px(ch + 52)
            place(cv, body, x, y, slide["hue"])
    scanlines(cv)


LAYOUTS = {"single": l_single, "pair": l_pair, "fan": l_fan}


# --- build ---------------------------------------------------------------------------------

def slug(slide):
    return re.sub(r"[^a-z0-9]+", "-", slide["name"].lower()).strip("-")


def pick(selectors):
    plan = list(enumerate(C.SLIDES, 1))
    if not selectors:
        return plan, True
    chosen = {}
    for sel in selectors:
        hits = [(n, s) for n, s in plan if str(n) == sel.lstrip("0") or sel.lower() in s["name"].lower()]
        if not hits:
            raise SystemExit(f"no slide matches {sel!r}; have: " + ", ".join(s["name"] for s in C.SLIDES))
        chosen.update({n: s for n, s in hits})
    return sorted(chosen.items(), key=lambda t: t[0]), False


def build(fmt, selectors):
    global W, H, RAW
    f = C.FORMATS[fmt]
    W, H = f["size"]
    RAW = GEN / "raw" / f["raw"]
    out = GEN / "marketing" / fmt
    out.mkdir(parents=True, exist_ok=True)
    plan, whole = pick(selectors)
    if whole:                                   # only a full build sweeps the folder
        for old in out.glob("*.png"):
            old.unlink()
    print(fmt)
    for n, slide in plan:
        global_raw = RAW
        if slide.get("raw"):                    # e.g. the palette shots live in their own folder
            RAW = GEN / "raw" / f.get(slide["raw"], slide["raw"])
        cv = Canvas(slide["ground"])
        LAYOUTS[slide["layout"]](cv, slide, f["wide"])
        cv.finish(out / f"{n:02d}-{slug(slide)}.png")
        RAW = global_raw
    thumbs(out, f["wide"])


def thumbs(out, wide):
    """The gate: the whole set at the width Play shows a search result. If a headline is not
    readable here, the slide fails, however good it looks full size."""
    tiles = sorted(t for t in out.glob("*.png") if not t.name.startswith("_"))
    tw = 200 if wide else 120
    ims = [Image.open(t) for t in tiles]
    th = int(round(tw * ims[0].height / ims[0].width))
    sheet = Image.new("RGB", (len(ims) * (tw + 12) + 12, th + 24), (0x18, 0x18, 0x18))
    for i, im in enumerate(ims):
        sheet.paste(im.resize((tw, th), Image.LANCZOS), (12 + i * (tw + 12), 12))
    sheet.save(out / "_thumbnail-test.png")
    print(f"  _thumbnail-test.png -- LOOK AT IT")


def load_config(path):
    spec = importlib.util.spec_from_file_location("slides_config", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    C = load_config(sys.argv[1])
    args = sys.argv[2:]
    if "--list" in args:
        for n, s in enumerate(C.SLIDES, 1):
            print(f"  {n:02d}  {s['name']:18} {s['layout']:7} {' / '.join(s['head'])}  ({s['accent_word']})")
        raise SystemExit
    only = []
    if "--only" in args:
        i = args.index("--only")
        only = [x for x in args[i + 1].split(",") if x]
        del args[i:i + 2]
    GEN = shot_sets.current(C.SCREENSHOTS)
    RAW = None
    for fmt in [a for a in args if a in C.FORMATS] or list(C.FORMATS):
        build(fmt, only)
