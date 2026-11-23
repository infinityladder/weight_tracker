"""
Get an emulator ready for store captures, and put it back afterwards.

    python device.py boot Pixel_10_Pro            # boot an AVD and wait until it is ready
    python device.py install app-release.apk com.example.app   # install + print versionName
    python device.py prep                         # clean status bar: demo mode + snooze notifications
    python device.py landscape                    # lock to landscape (7" tablet AVDs boot portrait)
    python device.py restore                      # demo mode off, rotation unlocked
    python device.py kill                         # shut the emulator down

What `prep` does and why:
  * Demo mode: the status bar shows 12:00, a full battery, full wifi, no notification icons.
  * Status icons hidden (Do Not Disturb, alarm, location, ...).
  * Every posted notification snoozed for a day. Demo mode alone did NOT hide Safety
    Center's "no screen lock" shield next to the clock -- zoom into the first capture's
    status bar to check before batching.
"""
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import adb_ui as ui  # noqa: E402

DEMO = [
    "command enter",
    "command clock -e hhmm 1200",
    "command battery -e level 100 -e plugged false",
    "command network -e wifi show -e level 4 -e fully true",
    "command network -e mobile hide",
    "command notifications -e visible false",
    "command status -e volume hide -e bluetooth hide -e location hide -e alarm hide "
    "-e mute hide -e sync hide -e hotspot hide -e cast hide -e speakerphone hide "
    "-e managed_profile hide -e zen none",
]


def emulator_exe():
    for var in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        root = os.environ.get(var)
        if root:
            return os.path.join(root, "emulator", "emulator")
    return os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk", "emulator", "emulator")


def boot(avd):
    """Boot an AVD (one at a time is easiest) and wait for boot_completed."""
    subprocess.Popen([emulator_exe(), "-avd", avd, "-no-snapshot-save", "-no-boot-anim"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ui.sh("wait-for-device")
    for _ in range(120):
        if ui.sh("shell", "getprop", "sys.boot_completed").strip() == "1":
            break
        time.sleep(3)
    print(ui.sh("shell", "getprop", "ro.boot.qemu.avd_name").strip(), ui.screen_size())


def install(apk, package):
    """Install and print the version that is now on the device. Always check it: an AVD you
    have not used for a while may still carry an old build of the app."""
    print(ui.sh("install", "-r", apk).strip().splitlines()[-1])
    out = ui.sh("shell", "dumpsys", "package", package)
    m = re.search(r"versionName=(\S+)", out)
    print("versionName", m[1] if m else "NOT INSTALLED")


def prep():
    ui.sh("shell", "settings", "put", "global", "sysui_demo_allowed", "1")
    for c in DEMO:
        ui.sh("shell", "am broadcast -a com.android.systemui.demo -e " + c)
    keys = set(re.findall(r"key=(-?\d+\|[^\s:]+)", ui.sh("shell", "dumpsys", "notification")))
    for key in keys:
        ui.sh("shell", f"cmd notification snooze --for 86400000 '{key}'")
    print(f"demo mode on, {len(keys)} notifications snoozed")


def landscape_rotation():
    """0 on AVDs that are landscape by nature (Pixel Tablet), 1 on portrait-first ones (7")."""
    w, h = map(int, re.findall(r"Physical size: (\d+)x(\d+)", ui.sh("shell", "wm", "size"))[0])
    return "0" if w > h else "1"


def landscape():
    """`settings put system user_rotation` did not take on a 7" tablet AVD; this does."""
    ui.sh("shell", "settings", "put", "system", "accelerometer_rotation", "0")
    ui.sh("shell", "wm", "user-rotation", "lock", landscape_rotation())
    time.sleep(2)
    print(ui.screen_size())


def restore():
    ui.sh("shell", "am broadcast -a com.android.systemui.demo -e command exit")
    ui.sh("shell", "settings", "put", "global", "sysui_demo_allowed", "0")
    ui.sh("shell", "settings", "put", "system", "show_touches", "0")
    ui.sh("shell", "wm", "user-rotation", "free")
    print("demo mode off, rotation free")


def kill():
    ui.sh("emu", "kill")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    cmd, args = sys.argv[1], sys.argv[2:]
    {"boot": boot, "install": install, "prep": prep, "landscape": landscape,
     "restore": restore, "kill": kill}[cmd](*args)
