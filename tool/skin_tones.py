"""Makes the skin-tone versions of the body pictures.

Run from the project root after changing a body picture:

    python tool/skin_tones.py

Needs Pillow and numpy. Only skin is recoloured: pixels whose colour is a
moderately saturated warm tone. The saturated orange kit, black/white kit,
hair and eyes fall outside that range and stay as they are. Shading is kept by
shifting each pixel's lightness by its distance from the picture's typical skin colour.
Writes images/body_log_<body>_<tone>.webp for every tone except light (the
original picture).
"""

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Target skin colour for each tone (sRGB); keep in step with SkinTone in
# lib/models.dart.
TONES = {
    'medium': (198, 142, 104),
    'tan': (166, 108, 72),
    'brown': (120, 74, 48),
    'deep': (78, 48, 32),
}


def srgb_to_lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def lab_to_srgb(lab):
    fy = (lab[..., 0] + 16) / 116
    fx, fz = fy + lab[..., 1] / 500, fy - lab[..., 2] / 200
    f = np.stack([fx, fy, fz], -1)
    xyz = np.where(f > 0.206893, f ** 3, (f - 16 / 116) / 7.787) * np.array([0.95047, 1.0, 1.08883])
    m = np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]])
    c = np.clip(xyz @ m.T, 0, 1)
    c = np.where(c > 0.0031308, 1.055 * c ** (1 / 2.4) - 0.055, 12.92 * c)
    return np.clip(c * 255 + 0.5, 0, 255).astype(np.uint8)


def skin_weight(rgb):
    """0..1 per pixel: how much a pixel is skin."""
    r, g, b = [rgb[..., i] / 255.0 for i in range(3)]
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    warm = (r >= g) & (g >= b * 0.85) & (r - b > 0.06)
    # Skin is warm and moderately saturated; the orange kit is far more saturated.
    s = np.clip((0.80 - sat) / 0.10, 0, 1) * np.clip((sat - 0.10) / 0.08, 0, 1)
    v = np.clip((mx - 0.18) / 0.12, 0, 1)
    return warm * s * v


def recolour(img, target):
    a = np.asarray(img.convert('RGBA')).astype(np.float64)
    rgb, alpha = a[..., :3], a[..., 3]
    w = skin_weight(rgb) * (alpha > 0)
    lab = srgb_to_lab(rgb)
    core = (w > 0.9) & (alpha > 200)
    ref = np.median(lab[core], axis=0)
    tgt = srgb_to_lab(np.array(target, dtype=np.float64))
    new = lab.copy()
    # Shift lightness rather than scale it, so darker tones keep their shading.
    new[..., 0] = tgt[0] + (lab[..., 0] - ref[0]) * 0.9
    new[..., 1] = lab[..., 1] + (tgt[1] - ref[1])
    new[..., 2] = lab[..., 2] + (tgt[2] - ref[2])
    out = lab_to_srgb(new).astype(np.float64)
    mixed = rgb * (1 - w[..., None]) + out * w[..., None]
    return Image.fromarray(np.dstack([mixed, alpha]).astype(np.uint8), 'RGBA')


def main(dest=None):
    for body in ['male', 'female']:
        img = Image.open(os.path.join(ROOT, 'images', f'body_log_{body}.png'))
        for name, target in TONES.items():
            path = os.path.join(dest or os.path.join(ROOT, 'images'), f'body_log_{body}_{name}.webp')
            recolour(img, target).save(path, 'WEBP', quality=88, method=6)
            print('wrote', path, os.path.getsize(path) // 1024, 'KB')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else None)
