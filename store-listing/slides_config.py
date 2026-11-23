"""
Slides for Simple Body Log. Run from the repo root:

    python scripts/make_slides.py store-listing/slides_config.py --list
    python scripts/make_slides.py store-listing/slides_config.py
"""
from pathlib import Path

SCREENSHOTS = Path("store-listing/screenshots")

FORMATS = {
    "phone": dict(size=(1440, 2560), wide=False, raw="phone", themes="themes"),
    "tablet_7": dict(size=(2560, 1440), wide=True, raw="tablet-7/landscape", themes="themes/tablet"),
    "tablet_10": dict(size=(2560, 1440), wide=True, raw="tablet-10", themes="themes/tablet"),
}

# The app's own faces (assets/fonts): Barlow Condensed Black Italic is its display face.
HEADLINE_FONT = Path("assets/fonts/BarlowCondensed-BlackItalic.ttf")
BODY_FONT = Path("assets/fonts/Barlow-Medium.ttf")
HEADLINE_WEIGHT = None
BODY_WEIGHT = None

# lib/theme.dart: grounds 0x111112 / 0xF5F2EF, brandOrange 0xFF4D1A, brandOrangeDeep 0xE2340A.
PALETTE = {
    "dark": dict(ground=(0x11, 0x11, 0x12), text=(0xF2, 0xEE, 0xEA), accent=(0xFF, 0x4D, 0x1A)),
    "light": dict(ground=(0xF5, 0xF2, 0xEF), text=(0x1A, 0x16, 0x14), accent=(0xE2, 0x34, 0x0A)),
}

# (gradient top, gradient bottom, bloom). Warm hues from the app's orange, plus its green.
HUES = {
    "dark": {
        "body":    ((0x4A, 0x1A, 0x0C), (0x16, 0x0C, 0x0A), (0xFF, 0x4D, 0x1A)),
        "log":     ((0x4A, 0x2A, 0x0A), (0x17, 0x10, 0x08), (0xFF, 0x9A, 0x1A)),
        "trend":   ((0x10, 0x3A, 0x22), (0x08, 0x14, 0x10), (0x16, 0xA3, 0x4A)),
        "goal":    ((0x4C, 0x12, 0x18), (0x17, 0x0A, 0x0C), (0xFF, 0x4D, 0x4D)),
    },
    "light": {
        "numbers": ((0xCF, 0xEA, 0xD8), (0xEE, 0xF3, 0xEF), (0x16, 0xA3, 0x4A)),
        "data":    ((0xF8, 0xD9, 0xC8), (0xF6, 0xEE, 0xE8), (0xFF, 0x4D, 0x1A)),
        "custom":  ((0xF6, 0xE3, 0xBE), (0xF6, 0xF0, 0xE4), (0xE8, 0x8A, 0x0A)),
        "yours":   ((0xF3, 0xCF, 0xC8), (0xF5, 0xEC, 0xEA), (0xE2, 0x34, 0x0A)),
    },
}

SCANLINES = False

# Short two-line headlines leave room: start the phone devices higher than the default 0.35.
PAIR_TOP_PORTRAIT = 0.27

SLIDES = [
    dict(name="body-map", head=["YOUR BODY,", "MEASURED"], accent_word="MEASURED",
         sub="Weight and every measurement on one body map.",
         shots=[("01-home", "dark"), ("01-home", "light")], hue="body", ground="dark", layout="pair"),
    dict(name="log", head=["LOG IT IN", "SECONDS"], accent_word="SECONDS",
         sub="Weigh in, or tap a body part and slide the ruler.",
         shots=[("02-weight", "dark"), ("02-ruler", "light")], hue="log", ground="dark", layout="pair"),
    dict(name="trend", head=["WATCH THE", "TREND"], accent_word="TREND",
         sub="Charts for your weight and every measurement.",
         shots=[("03-trend", "dark"), ("03-trend", "light")], hue="trend", ground="dark", layout="pair"),
    dict(name="goal", head=["SET A", "GOAL"], accent_word="GOAL",
         sub="See how far you've come since your start date.",
         shots=[("04-goal", "dark"), ("04-start", "light")], hue="goal", ground="dark", layout="pair"),
    dict(name="numbers", head=["KNOW YOUR", "NUMBERS"], accent_word="NUMBERS",
         sub="BMI, waist-to-height and waist-to-hip, on one Health screen.",
         shots=[("05-health", "dark"), ("05-numbers", "light")], hue="numbers", ground="light", layout="pair"),
    dict(name="data", head=["EVERY ENTRY", "KEPT"], accent_word="KEPT",
         sub="Browse, edit or add past entries.",
         shots=[("06-data", "dark"), ("06-edit", "light")], hue="data", ground="light", layout="pair"),
    dict(name="custom", head=["TRACK WHAT", "MATTERS"], accent_word="MATTERS",
         sub="Pick from 16 measurements or name 3 of your own.",
         shots=[("07-female", "dark"), ("07-settings", "light")], hue="custom", ground="light", layout="pair"),
    dict(name="yours", head=["YOUR DATA,", "YOUR WAY"], accent_word="WAY",
         sub="Kg or lb. Import and export CSV. Stays on your phone.",
         shots=[("08-imperial", "dark"), ("08-units", "light")], hue="yours", ground="light", layout="pair"),
]
