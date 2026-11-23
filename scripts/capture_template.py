"""
TEMPLATE -- copy into the app's repo (e.g. scripts/store_captures.py) and fill in the TODOs.

Captures every raw screen the slides need, in BOTH themes, as <key>-dark.png / <key>-light.png,
into the newest dated generation:

    python store_captures.py phone                    # every group, both themes
    python store_captures.py tablet_10 records        # one group
    python store_captures.py phone checkout --light   # one group, one theme
    python store_captures.py phone seed               # seed real data off camera first

The structure is the reusable part:
  * one function per GROUP of screens (a group = what one slide needs), taking `theme`;
  * every group starts from Home and ends back on Home, with nothing open;
  * every group FAILS LOUDLY if an expected screen did not appear, instead of capturing
    whatever happens to be on screen;
  * the app is used for real -- a game is played, a form is filled, a list is populated --
    so every number on screen was earned. Write that "use it like a person" code here
    (for a game: read the board from the accessibility tree and play it; for an app:
    create the sample records through the UI or an import the app really offers).
"""
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import adb_ui as ui  # noqa: E402   (copy adb_ui.py and shot_sets.py next to this file)
import shot_sets  # noqa: E402

SCREENSHOTS = Path("store-listing/screenshots")          # TODO: where generations live
PACKAGE = "com.example.app"                              # TODO

# Raw folder per format, under <generation>/raw/.
FORMATS = {"phone": "phone", "tablet_7": "tablet-7/landscape", "tablet_10": "tablet-10"}

# The theme switch, as (dark half, light half) tap points per format. Switches often only
# label themselves when ON, so they are tapped by position -- measure once per AVD from a
# screenshot of the screen that holds it. The result is checked by brightness, not trusted.
THEME_SWITCH = {                                         # TODO: measure
    "phone": ((1206, 291), (1051, 291)),
    "tablet_10": ((2176, 197), (2110, 197)),
    "tablet_7": ((1848, 145), (1783, 145)),
}

# A label that only exists on Home and never changes (not one that is below the fold on a
# short screen, and not one that changes with state -- e.g. a card that says "Locked").
HOME_MARKER = "TODO: a stable Home-only label"

fmt = next((a for a in sys.argv[1:] if a in FORMATS), "phone")
GEN = shot_sets.new(SCREENSHOTS)                         # today's generation
OUT = GEN / "raw" / FORMATS[fmt]


def name(key, theme):
    return OUT / f"{key}-{theme}.png"


def shot(path):
    ui.shot(str(path))
    print("  ", path)


def home():
    """Back to Home, answering any 'leave / discard?' prompt on the way."""
    for _ in range(6):
        if ui.find_exact(HOME_MARKER):
            return
        ui.back(1.0)
        for leave in ("DISCARD", "LEAVE", "DISCARD RUN"):      # TODO: the app's exit prompts
            n = ui.find_exact(leave)
            if n:
                ui.tap(n[1], n[2], 1.2)
    raise SystemExit("could not get back to Home")


def set_theme(dark):
    home()
    for _ in range(3):
        if (ui.brightness() < 100) == dark:
            return
        ui.tap(*THEME_SWITCH[fmt][0 if dark else 1], 1.5)
    raise SystemExit("could not set the theme")


def expect(label):
    """Stop if the screen we are about to capture is not the one we think it is."""
    if not ui.find_exact(label):
        raise SystemExit(f"expected {label!r} on screen; have {[n[0] for n in ui.dump()][:15]}")


# --- groups: one per slide (or per pair of screens a slide shows) ---------------------

def seed(theme=None):
    """Off camera: create the real data the data screens need on a fresh install
    (play a few levels, finish some runs, add records). TODO."""
    home()


def main_screen(theme):
    """TODO: the core screen, mid-use, looking its best (a game mid-run with a streak; an
    app with a populated list)."""
    set_theme(theme == "dark")
    # ui.tap_exact("Start"); ...use it for real...
    # expect("Some label only that screen has")
    shot(name("01-main", theme))
    home()


def share(theme):
    """Example of a two-screen group: the share sheet, then what the friend sees."""
    set_theme(theme == "dark")
    # ...open a record, tap SHARE...
    # Floating buttons can cover part of another button: tap a button on its uncovered
    # side if needed, and confirm the right screen opened:
    # s = ui.find_exact("SHARE"); ui.tap(s[3][0] + 20, s[2]); expect("Share")
    shot(name("04-share", theme))
    # ...open the link as the friend: ui.sh("shell", "am", "start", "-a",
    #    "android.intent.action.VIEW", "-d", f"'{link}'", PACKAGE)
    shot(name("04-result", theme))
    home()


GROUPS = {"seed": seed, "main": main_screen, "share": share}     # TODO: every group

if __name__ == "__main__":
    picked = [a for a in sys.argv[1:] if a in GROUPS] or [g for g in GROUPS if g != "seed"]
    themes = [t for t in ("dark", "light") if f"--{t}" in sys.argv] or ["dark", "light"]
    print(f"{fmt} -> {OUT}")
    try:
        for g in picked:
            for theme in (themes if g != "seed" else [None]):
                print(g, theme or "")
                GROUPS[g](theme)
    finally:
        set_theme(True)                                  # TODO: the app's default theme
