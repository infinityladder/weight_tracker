"""Builds the outfit-colour layers in images/clothes/ from the body pictures.

Run from the project root after changing a body picture:

    python tool/clothes_mask.py [--preview DIR]

Needs Pillow, numpy and scipy. For each picture it finds the dark fabric of
the shorts and top (plus the orange top on the dark-skinned woman), and
writes a same-size PNG holding only that fabric as grey shading. The app
draws it over the picture tinted with the chosen outfit colour
(BlendMode.modulate), so folds and highlights survive the recolour. The
orange and white trim is left alone.
"""

import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Picture -> recolour the orange top too.
PICTURES = {
    'body_log_male': False,
    'body_log_female': False,
    'body_log_male_brown_skin': False,
    'body_log_female_brown_skin': False,
    'body_log_male_dark_skin': False,
    'body_log_female_dark_skin': True,
}


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def build(name, orange_top):
    im = np.asarray(Image.open(os.path.join(ROOT, 'images', name + '.png')).convert('RGBA')).astype(np.float32) / 255
    rgb, a = im[:, :, :3], im[:, :, 3]
    h, w = a.shape
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)

    # Dark, colourless fabric. Soft edge so the tint blends into the trim.
    dark = smoothstep(0.42, 0.30, mx) * smoothstep(0.55, 0.35, sat) * a
    # Orange fabric (only where asked): strongly saturated orange-red hue.
    # Seeds are the vivid orange of the top (skin is far less saturated);
    # the top is the biggest such blob, filled and widened to its darker,
    # shaded edges.
    orange = np.zeros_like(a)
    if orange_top:
        seed = (sat > 0.85) & (mx > 0.6) & (rgb[:, :, 1] > 0.2 * mx) & (rgb[:, :, 2] < 0.15)
        lab, n = ndimage.label(ndimage.binary_opening(seed, iterations=2))
        if n:
            sizes = ndimage.sum(seed, lab, range(1, n + 1))
            top_blob = ndimage.binary_fill_holes(lab == 1 + int(np.argmax(sizes)))
            near = ndimage.binary_dilation(top_blob, iterations=6)
            loose = (sat > 0.75) & (rgb[:, :, 2] < 0.2 * np.maximum(mx, 1e-6) + 0.05)
            orange = ((top_blob | (near & loose)).astype(np.float32)) * a

    # Keep only big blobs in the clothing band (drops hair, eyes, shadows).
    core = (dark > 0.5) | (orange > 0.5)
    core = ndimage.binary_opening(core, iterations=1)
    labels, n = ndimage.label(core)
    keep = np.zeros(n + 1, bool)
    ys = np.arange(h)[:, None].repeat(w, 1)
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        size = (labels[sl] == i).sum()
        cy = ys[sl][labels[sl] == i].mean() / h
        top = sl[0].start / h
        if size > h * w * 0.0015 and 0.2 < cy < 0.75 and top > 0.17:
            keep[i] = True
    region = keep[labels]
    region = ndimage.binary_dilation(region, iterations=3)
    alpha = np.maximum(dark, orange) * region
    # Orange trim on non-orange-top pictures stays; for the orange top,
    # keep its own trim (dark band) as fabric too.

    # Shading: black fabric is very dark, so stretch its lightness into a
    # usable range; orange fabric uses its own lightness.
    shade = np.where(orange > 0.5, 0.35 + 0.5 * lum, 0.42 + 2.2 * lum)
    shade = np.clip(shade, 0, 1)
    out = np.zeros((h, w, 4), np.float32)
    out[:, :, :3] = shade[:, :, None]
    out[:, :, 3] = alpha
    return (out * 255 + 0.5).astype(np.uint8)


def main():
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    os.makedirs(os.path.join(ROOT, 'images', 'clothes'), exist_ok=True)
    for name, orange_top in PICTURES.items():
        layer = build(name, orange_top)
        Image.fromarray(layer, 'RGBA').save(os.path.join(ROOT, 'images', 'clothes', name + '.png'), optimize=True)
        if preview:
            base = Image.open(os.path.join(ROOT, 'images', name + '.png')).convert('RGBA')
            tiles = [base]
            for c in [(0x1E, 0x3A, 0x8A), (0xC0, 0x1F, 0x2E), (0x1F, 0x7A, 0x4D), (0xE0, 0x4E, 0x9A)]:
                f = layer.astype(np.float32) / 255
                tinted = f.copy()
                tinted[:, :, :3] *= np.array(c, np.float32) / 255
                im = base.copy()
                im.alpha_composite(Image.fromarray((tinted * 255).astype(np.uint8), 'RGBA'))
                tiles.append(im)
            H = 600
            tiles = [t.resize((int(t.width * H / t.height), H)) for t in tiles]
            sheet = Image.new('RGBA', (sum(t.width for t in tiles), H), (255, 255, 255, 255))
            x = 0
            for t in tiles:
                sheet.alpha_composite(t, (x, 0))
                x += t.width
            sheet.save(os.path.join(preview, name + '.png'))
    print('wrote', len(PICTURES), 'layers')


if __name__ == '__main__':
    main()
