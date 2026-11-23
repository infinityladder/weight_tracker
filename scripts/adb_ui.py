"""
Drive an Android app through its accessibility tree (uiautomator), over adb.

The tree is a reliable read of the screen as long as the app labels its controls for
TalkBack (contentDescription / text). Label everything you need to tap or read -- it is
good accessibility anyway, and it makes this driver work without coordinates or OCR.

    python adb_ui.py dump            # every labelled node with its tap point
    python adb_ui.py tap "Settings"  # tap the first node whose label contains the text
    python adb_ui.py shot out.png    # screenshot to a file
    python adb_ui.py back

As a module:
    import adb_ui as ui
    nodes = ui.dump()                 # [(label, cx, cy, (x1, y1, x2, y2)), ...]
    ui.tap_exact("PLAY")              # exact label match (safer than substring)
    ui.reveal("How to play")          # scroll until the label is on screen
    ui.shot("raw/phone/01-home-dark.png")

Picks the device from ANDROID_SERIAL if set (adb's own variable), else the only one attached.
On Windows consoles set PYTHONIOENCODING=utf-8 before printing labels with symbols in them.
"""
import os
import re
import shutil
import subprocess
import sys
import time


def _adb():
    for var in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        root = os.environ.get(var)
        if root:
            for exe in ("adb.exe", "adb"):
                cand = os.path.join(root, "platform-tools", exe)
                if os.path.exists(cand):
                    return cand
    local = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk", "platform-tools", "adb.exe")
    if os.path.exists(local):
        return local
    return shutil.which("adb") or "adb"


ADB = _adb()


def sh(*args, binary=False):
    """Run `adb <args>` and return stdout. One string with spaces is passed as one argument."""
    r = subprocess.run([ADB] + list(args), capture_output=True)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def dump():
    """Every labelled node on screen: (label, centre x, centre y, bounds)."""
    # Delete the last dump first: uiautomator only writes when the screen is idle, and a
    # stale file would otherwise be read back as if it were this screen.
    sh("shell", "rm", "-f", "/sdcard/ui.xml")
    sh("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    xml = sh("exec-out", "cat", "/sdcard/ui.xml")
    out = []
    for m in re.finditer(r"<node[^>]*>", xml):
        s = m.group(0)
        t = re.search(r'text="([^"]*)"', s)
        c = re.search(r'content-desc="([^"]*)"', s)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        label = (t.group(1) if t else "") or (c.group(1) if c else "")
        if label and b:
            x1, y1, x2, y2 = map(int, b.groups())
            label = label.replace("&gt;", ">").replace("&lt;", "<").replace("&amp;", "&").replace("&quot;", '"')
            out.append((label, (x1 + x2) // 2, (y1 + y2) // 2, (x1, y1, x2, y2)))
    return out


def find(sub, nodes=None):
    """First node whose label contains `sub` (case-insensitive), or None."""
    for node in nodes or dump():
        if sub.lower() in node[0].lower():
            return node
    return None


def find_exact(label, nodes=None, lowest=True):
    """Node whose label is exactly `label`; the lowest on screen if several (e.g. a button
    under a heading with the same word)."""
    hits = [n for n in (nodes or dump()) if n[0] == label]
    if not hits:
        return None
    return max(hits, key=lambda n: n[2]) if lowest else hits[0]


def tap(x, y, wait=0.6):
    sh("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def tap_text(sub, wait=0.9):
    n = find(sub)
    if not n:
        raise SystemExit(f"not on screen: {sub!r}")
    tap(n[1], n[2], wait)
    return n


def tap_exact(label, wait=0.9):
    """Exact match. Substring matching taps the wrong thing surprisingly often
    ("Play" inside "How to play", "Level 2, next to play")."""
    n = find_exact(label)
    if not n:
        raise SystemExit(f"not on screen: {label!r}")
    tap(n[1], n[2], wait)
    return n


def screen_size():
    m = re.search(r"(\d+)x(\d+)", sh("shell", "wm", "size").split("Override size:")[-1])
    w, h = int(m[1]), int(m[2])
    # wm size reports the natural (portrait) size; swap if the display is rotated.
    rot = sh("shell", "dumpsys", "window", "displays")
    cur = re.search(r"cur=(\d+)x(\d+)", rot)
    return (int(cur[1]), int(cur[2])) if cur else (w, h)


def swipe_up(fraction=0.4, ms=500):
    w, h = screen_size()
    sh("shell", "input", "swipe", str(w // 2), str(int(h * 0.75)), str(w // 2),
       str(int(h * (0.75 - fraction))), str(ms))
    time.sleep(0.8)


def reveal(label, tries=5):
    """Scroll down until a node labelled exactly `label` is on screen. Short landscape
    screens push rows below the fold that are visible on a phone. The screen stays scrolled
    afterwards: scroll back up before tapping anything near the top."""
    for _ in range(tries):
        if find_exact(label):
            return
        swipe_up()
    raise SystemExit(f"never came on screen: {label!r}")


def back(wait=0.8):
    sh("shell", "input", "keyevent", "4")
    time.sleep(wait)


def shot(path, rgb=True):
    """Screenshot to `path`. RGB by default: Play rejects images with an alpha channel."""
    d = os.path.dirname(os.path.abspath(path))
    os.makedirs(d, exist_ok=True)
    with open(path, "wb") as f:
        f.write(sh("exec-out", "screencap", "-p", binary=True))
    if rgb:
        from PIL import Image
        Image.open(path).convert("RGB").save(path)
    return path


def brightness(path=None):
    """Mean brightness of the screen (0-255): a reliable dark/light theme check when a
    theme switch does not label its state. Dark themes read under ~100, light over ~140."""
    from PIL import Image, ImageStat
    import tempfile
    p = path or os.path.join(tempfile.gettempdir(), "_adb_ui_probe.png")
    shot(p, rgb=False)
    return ImageStat.Stat(Image.open(p).convert("L")).mean[0]


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "dump"
    if cmd == "dump":
        for label, cx, cy, _ in dump():
            print("%-50s @%5d,%5d" % (repr(label)[:50], cx, cy))
    elif cmd == "tap":
        tap_text(sys.argv[2])
    elif cmd == "shot":
        print(shot(sys.argv[2]))
    elif cmd == "back":
        back()
    else:
        raise SystemExit(__doc__)
