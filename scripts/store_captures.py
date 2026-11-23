"""
Captures the raw screens for the Play Store slides (store-listing/slides_config.py), in both
themes, into the newest generation under store-listing/screenshots/.

    python scripts/store_captures.py phone seed        # fresh install: real data, off camera
    python scripts/store_captures.py phone             # every group, both themes
    python scripts/store_captures.py tablet_10 trend --light

Run from the repo root with the release build installed and `scripts/device.py prep` done.
The app follows the system theme, so themes are switched with `cmd uimode night`.
Set MSYS_NO_PATHCONV=1 in Git Bash (it rewrites /sdcard paths otherwise).
"""
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import adb_ui as ui  # noqa: E402
import device  # noqa: E402
import shot_sets  # noqa: E402

ROOT = HERE.parent
SCREENSHOTS = ROOT / "store-listing" / "screenshots"
DEMO_CSV = ROOT / "store-listing" / "demo_data.csv"
PACKAGE = "com.simplebodylog.app"

FORMATS = {"phone": "phone", "tablet_7": "tablet-7/landscape", "tablet_10": "tablet-10"}
HOME_MARKER = "VIEW DATA"

fmt = next((a for a in sys.argv[1:] if a in FORMATS), "phone")
GEN = shot_sets.current(SCREENSHOTS) if shot_sets.generations(SCREENSHOTS) else shot_sets.new(SCREENSHOTS)
OUT = GEN / "raw" / FORMATS[fmt]


def dp(v):
    """dp -> px for this device."""
    m = re.findall(r"(\d+)", ui.sh("shell", "wm", "density"))
    return int(v * int(m[-1]) / 160)


def name(key, theme):
    return OUT / f"{key}-{theme}.png"


def shot(path):
    time.sleep(0.8)
    ui.shot(str(path))
    if fmt != "phone":
        from PIL import Image
        w, h = Image.open(path).size
        if h > w:
            raise SystemExit(f"{path} came out portrait on a tablet format: re-lock rotation")
    print("  ", path.relative_to(ROOT))


def expect(label, starts=False):
    nodes = ui.dump()
    hit = [n for n in nodes if (n[0].startswith(label) if starts else n[0] == label)]
    if not hit:
        raise SystemExit(f"expected {label!r} on screen; have {[n[0][:30] for n in nodes][:15]}")
    return hit[0]


def tap_node(label, starts=False, wait=1.2):
    n = expect(label, starts)
    ui.tap(n[1], n[2], wait)
    return n


def tap_contains(sub, wait=1.2):
    """First node whose label contains `sub` (case-sensitive), e.g. a value inside a card."""
    nodes = ui.dump()
    hit = [n for n in nodes if sub in n[0]]
    if not hit:
        raise SystemExit(f"nothing containing {sub!r}; have {[n[0][:30] for n in nodes][:15]}")
    ui.tap(hit[0][1], hit[0][2], wait)
    return hit[0]


def launch():
    ui.sh("shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(4)
    if fmt != "phone":                 # relaunching can drop the rotation lock
        device.landscape()
        time.sleep(1.5)


def home():
    for _ in range(6):
        if ui.find_exact(HOME_MARKER):
            return
        top = re.search(r"topResumedActivity=\S+ \S+ (\S+)/", ui.sh("shell", "dumpsys", "activity", "activities"))
        if top and top[1] != PACKAGE:
            launch()                   # Back went past the app to the launcher
            continue
        ui.back(1.0)
    raise SystemExit("could not get back to Home")


def set_theme(dark):
    home()
    ui.sh("shell", "cmd", "uimode", "night", "yes" if dark else "no")
    time.sleep(1.5)
    b = ui.brightness()
    if (b < 100) != dark:
        raise SystemExit(f"theme did not switch (brightness {b:.0f})")


def to_top():
    for _ in range(4):
        w, h = ui.screen_size()
        ui.sh("shell", "input", "swipe", str(w // 2), str(int(h * 0.3)), str(w // 2), str(int(h * 0.85)), "300")
    time.sleep(0.6)


def to_bottom():
    for _ in range(5):
        ui.swipe_up(0.6, 300)


def hide_keyboard():
    """Back closes the on-screen keyboard, but only press it when one is up: some tablet AVDs
    show none, and Back would then close the sheet or the app."""
    if "mInputShown=true" in ui.sh("shell", "dumpsys", "input_method"):
        ui.back(1.0)


def type_text(text):
    ui.sh("shell", "input", "text", text)
    time.sleep(0.5)


# --- seed: real data through the app's own UI ----------------------------------------------

def seed(theme=None):
    """Fresh install: import the demo CSV with the app's Import button, set the height, set a
    goal from the first weigh-in, and name + log a custom measurement."""
    home()
    ui.sh("push", str(DEMO_CSV), "/sdcard/Download/body_log_demo.csv")
    tap_node("VIEW DATA", wait=1.5)
    tap_node("Import CSV", wait=2.5)
    # The picker opens wherever it was last; get to the Downloads folder either through the
    # roots menu or through the "Download" folder of the storage root.
    for _ in range(4):
        if ui.find_exact("body_log_demo.csv"):
            break
        if ui.find_exact("Download"):
            tap_node("Download", wait=2.0)
        elif ui.find_exact("Downloads"):
            tap_node("Downloads", wait=2.0)
        else:
            tap_node("Show roots", wait=1.5)
    if not ui.find_exact("body_log_demo.csv"):
        ui.reveal("body_log_demo.csv")
    tap_node("body_log_demo.csv", wait=2.5)
    expect("Import done")
    tap_node("OK")
    home()

    # Height: the field has no label until it holds a value; it sits under its help line.
    tap_node("Settings", wait=1.5)
    # On short screens the field sits under the pinned DONE button: scroll until the next
    # section's heading shows, which brings the field fully into view.
    ui.reveal("STANDARD")
    label = expect("Height")         # under HEALTH, shown while BMI or waist-to-height is on
    ui.tap(label[1], label[3][3] + dp(36), 1.0)
    type_text("182")
    hide_keyboard()
    expect("182")

    # Custom measurement "Wrist", switched on.
    ui.reveal("Custom 1")
    field = expect("Custom 1")
    ui.tap(field[1], field[2], 1.0)
    ui.sh("shell", "input", "keyevent", "KEYCODE_MOVE_END")
    for _ in range(10):
        ui.sh("shell", "input", "keyevent", "KEYCODE_DEL")
    type_text("Wrist")
    hide_keyboard()
    field = expect("Wrist")
    ui.tap(field[3][2] + dp(43), field[2], 1.0)
    tap_node("DONE", wait=1.5)
    tap_node("Wrist&#10;", starts=True, wait=1.5)
    expect("CONFIRM")
    tap_contains(" cm")                # the value opens a dialog to type it
    type_text("17.4")
    tap_node("OK")
    tap_node("CONFIRM", wait=1.5)
    expect("Wrist&#10;17.4 cm")

    # Goal: 78 kg, starting from the first weigh-in.
    tap_node("TREND", wait=1.5)
    ui.reveal("SET GOAL")
    tap_node("SET GOAL", wait=1.5)
    tap_node("Pick from history", wait=1.5)
    tap_node("USE AS START", wait=1.5)
    kg = expect("kg")
    ui.tap(ui.screen_size()[0] // 2, kg[2], 1.0)
    type_text("78")
    hide_keyboard()
    tap_node("SAVE GOAL", wait=1.5)
    home()


# --- groups: one per slide ------------------------------------------------------------------

def g01_home(theme):
    set_theme(theme == "dark")
    expect("Wrist&#10;", starts=True)
    shot(name("01-home", theme))


def g02_log(theme):
    set_theme(theme == "dark")
    tap_node("+ LOG", wait=1.5)
    hide_keyboard()
    expect("SAVE")
    # A morning weigh-in, whatever the emulator's clock says: set 7:15 AM in the time picker.
    clock = [n for n in ui.dump() if re.fullmatch(r"\d{1,2}:\d{2} [AP]M", n[0])][0]
    ui.tap(clock[1], clock[2], 1.5)
    tap_node("Switch to text input mode")
    for old, new in ((r"\d{1,2}", "7"), (r"\d{2}", "15")):
        field = [n for n in ui.dump() if re.fullmatch(old, n[0])][0]
        ui.tap(field[1], field[2], 0.6)
        ui.sh("shell", "input", "keyevent", "KEYCODE_MOVE_END")
        for _ in range(3):
            ui.sh("shell", "input", "keyevent", "KEYCODE_DEL")
        type_text(new)
    tap_node("AM", wait=0.8)
    tap_node("OK")
    hide_keyboard()
    expect("Main weigh-in")
    kg = expect("kg")
    ui.tap(ui.screen_size()[0] // 2, kg[2], 1.0)
    type_text("80.6")
    if fmt != "phone":                 # landscape: the keyboard would cover SAVE
        hide_keyboard()
    shot(name("02-weight", theme))
    hide_keyboard()
    ui.back(1.0)                       # sheet, not saved
    home()
    tap_node("Waist&#10;", starts=True, wait=1.5)
    expect("CONFIRM")
    shot(name("02-ruler", theme))
    home()


def g03_trend(theme):
    set_theme(theme == "dark")
    tap_node("TREND", wait=1.5)
    expect("LOG WEIGHT")
    shot(name("03-trend", theme))
    home()


def g04_goal(theme):
    set_theme(theme == "dark")
    tap_node("TREND", wait=1.5)
    # Main weigh-in card just under the app bar, goal card below it. A slow drag doesn't fling,
    # so it scrolls by exactly the distance dragged.
    card = expect("MAIN WEIGH-IN", starts=True)
    target = expect("Back")[3][3] + dp(16)
    x = ui.screen_size()[0] // 2
    start = min(card[3][1] + dp(300), ui.screen_size()[1] - dp(40))
    ui.sh("shell", "input", "swipe", str(x), str(start), str(x), str(start - (card[3][1] - target)), "1500")
    time.sleep(1.0)
    expect("Edit goal")
    shot(name("04-goal", theme))
    home()
    tap_contains("SINCE", wait=1.5)    # the change since the start weigh-in
    expect("USE AS START")
    shot(name("04-start", theme))
    home()


def g05_numbers(theme):
    set_theme(theme == "dark")
    tap_node("HEALTH", wait=1.5)
    expect("BMI", starts=True)
    shot(name("05-health", theme))
    home()
    tap_node("TREND", wait=1.5)
    to_bottom()
    shot(name("05-numbers", theme))
    home()


def g06_data(theme):
    set_theme(theme == "dark")
    tap_node("VIEW DATA", wait=1.5)
    expect("Export CSV")
    shot(name("06-data", theme))
    tap_contains("7:20 AM · MAIN")
    tap_node("EDIT", wait=1.5)
    expect("EDIT ENTRY")               # the form scrolls; UPDATE ENTRY may be below the fold
    shot(name("06-edit", theme))
    home()


def g07_custom(theme):
    set_theme(theme == "dark")
    tap_node("Settings", wait=1.5)
    to_bottom()
    expect("Wrist")
    shot(name("07-settings", theme))
    tap_node("DONE", wait=1.5)
    tap_node("Settings", wait=1.5)
    to_top()
    tap_node("FEMALE")
    tap_node("DONE", wait=1.5)
    shot(name("07-female", theme))
    tap_node("Settings", wait=1.5)
    to_top()
    tap_node("MALE")
    tap_node("DONE", wait=1.5)


def g08_yours(theme):
    set_theme(theme == "dark")

    def in_lb():
        return any("&#10;LB&#10;" in n[0] for n in ui.dump())

    if in_lb():                        # a run that stopped part way left it in lb
        tap_node("KG&#10;LB", wait=1.5)
    tap_node("KG&#10;LB", wait=1.5)
    if not in_lb():
        raise SystemExit("units did not switch to lb")
    try:
        shot(name("08-imperial", theme))
        tap_node("Settings", wait=1.5)
        to_top()
        expect("LB / IN")
        shot(name("08-units", theme))
        tap_node("DONE", wait=1.5)
    finally:
        home()
        if in_lb():
            tap_node("KG&#10;LB", wait=1.5)


GROUPS = {"seed": seed, "home": g01_home, "log": g02_log, "trend": g03_trend, "goal": g04_goal,
          "numbers": g05_numbers, "data": g06_data, "custom": g07_custom, "yours": g08_yours}

if __name__ == "__main__":
    picked = [a for a in sys.argv[1:] if a in GROUPS] or [g for g in GROUPS if g != "seed"]
    themes = [t for t in ("dark", "light") if f"--{t}" in sys.argv] or ["dark", "light"]
    print(f"{fmt} -> {OUT.relative_to(ROOT)}")
    try:
        for g in picked:
            for theme in (themes if g != "seed" else [None]):
                print(g, theme or "")
                GROUPS[g](theme)
    finally:
        ui.sh("shell", "cmd", "uimode", "night", "auto")
