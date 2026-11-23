"""
Example config for make_slides.py -- copy to the app's repo and edit.

    python make_slides.py slides_config.py --list
    python make_slides.py slides_config.py
"""
from pathlib import Path

# Where the dated generations live (relative to where you run the script).
SCREENSHOTS = Path("store-listing/screenshots")

# Output frame per format, whether it is landscape, and its raw folder under <gen>/raw/.
# A slide can name a different raw folder (e.g. the palette shots) with "raw": "<key>".
FORMATS = {
    "phone": dict(size=(1440, 2560), wide=False, raw="phone", themes="themes"),
    "tablet_7": dict(size=(2560, 1440), wide=True, raw="tablet-7/landscape", themes="themes/tablet"),
    "tablet_10": dict(size=(2560, 1440), wide=True, raw="tablet-10", themes="themes/tablet"),
}

# One heavy face the app already ships (a decorative/brand face blurs at thumbnail size --
# keep that for the feature graphic). A variable font takes a weight axis value.
HEADLINE_FONT = Path("app/src/main/res/font/manrope_variable.ttf")   # or C:/Windows/Fonts/arialbd.ttf
HEADLINE_WEIGHT = 800
BODY_WEIGHT = 500

# Copied from the app's own palette, so the slides and the screens look like one set.
PALETTE = {
    "dark": dict(ground=(0x0A, 0x0C, 0x0B), text=(0xE9, 0xED, 0xEA), accent=(0x44, 0xE2, 0x8A)),
    "light": dict(ground=(0xF7, 0xFA, 0xF8), text=(0x13, 0x19, 0x16), accent=(0x0B, 0x7A, 0x3E)),
}

# Backdrop per hue: (gradient top, gradient bottom, bloom colour). One hue per feature/mode,
# taken from the app's own colours. Dark grounds stay well clear of the app's own ground so a
# dark screen still reads as separate; light grounds stay off pure white for the same reason.
HUES = {
    "dark": {
        "core":    ((0x3A, 0x15, 0x47), (0x0D, 0x10, 0x30), (0xDE, 0x7B, 0xE8)),
        "second":  ((0x10, 0x2C, 0x5C), (0x08, 0x0E, 0x26), (0x6F, 0xB4, 0xFF)),
        "social":  ((0x24, 0x1F, 0x5C), (0x0B, 0x0E, 0x2C), (0x8F, 0x8C, 0xFF)),
        "accent":  ((0x0A, 0x3D, 0x2B), (0x06, 0x16, 0x2B), (0x44, 0xE2, 0x8A)),
    },
    "light": {
        "core":    ((0xE4, 0xD2, 0xEE), (0xEC, 0xEA, 0xF6), (0x9A, 0x3B, 0xA8)),
        "calm":    ((0xC6, 0xE6, 0xE9), (0xE7, 0xF1, 0xF2), (0x0A, 0x75, 0x80)),
        "accent":  ((0xC6, 0xE9, 0xD4), (0xE8, 0xF1, 0xEC), (0x0B, 0x7A, 0x3E)),
    },
}

SCANLINES = False          # a faint CRT veil; only if it suits the app's look

# The eight slots, in upload order (Play orders by filename). Rules:
#   head          two lines, five words or fewer in total
#   accent_word   exactly one word of `head`, drawn in the accent colour
#   sub           one short factual line the store listing already backs up
#   shots         [(capture key, theme), ...] -> raw/<format>/<key>-<theme>.png
#   ground        "dark" or "light" -- the slide's own background family
#   layout        single | pair | fan
# For a game, slots 1-3 must show gameplay (Play's rule for games).
SLIDES = [
    dict(name="main", head=["GETS YOUR", "HEART POUNDING"], accent_word="HEART",
         sub="The one-line promise, backed by the listing.",
         shots=[("01-main", "dark"), ("01-main", "light")], hue="core", ground="dark", layout="pair"),
    dict(name="second-mode", head=["THE GAME IS", "CHASING YOU"], accent_word="CHASING",
         sub="What the second core feature does.",
         shots=[("02-second", "dark"), ("02-second", "light")], hue="second", ground="dark", layout="pair"),
    dict(name="share", head=["CHALLENGE A", "FRIEND"], accent_word="FRIEND",
         sub="Share it. They get the same thing to beat.",
         shots=[("04-share", "dark"), ("04-result", "light")], hue="social", ground="dark", layout="pair"),
    dict(name="calm", head=["OR JUST TAKE", "YOUR TIME"], accent_word="TIME",
         sub="The calm counterpoint.",
         shots=[("06-calm", "dark")], hue="calm", ground="light", layout="single"),
    dict(name="themes", head=["FOUR LOOKS,", "ONE APP"], accent_word="FOUR",
         sub="Light or dark. No ads. Fully offline.",
         # raw/themes/emerald-dark.png, ... -- "raw" names the FORMATS key holding that folder
         shots=[("emerald", "dark"), ("emerald", "light"), ("azure", "light"), ("azure", "dark")],
         raw="themes", swatches=[(0x44, 0xE2, 0x8A), (0x0B, 0x7A, 0x3E), (0x0E, 0x6B, 0xD4), (0x5A, 0xA9, 0xFF)],
         hue="accent", ground="dark", layout="fan"),
]
