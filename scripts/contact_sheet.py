"""
Tile a folder of images into one contact sheet, so a whole capture run can be checked at a
glance. Do this after EVERY capture run -- most problems only show up here.

    python contact_sheet.py raw/phone sheet.png            # 7 columns, 300px wide tiles
    python contact_sheet.py raw/tablet-10 sheet.png 5 480
"""
import sys
from pathlib import Path

from PIL import Image


def sheet(folder, out, cols=7, tile_w=300):
    files = sorted(p for p in Path(folder).glob("*.png") if not p.name.startswith("_"))
    if not files:
        raise SystemExit(f"no PNGs in {folder}")
    ims = [Image.open(f).convert("RGB") for f in files]
    tile_h = int(tile_w * ims[0].height / ims[0].width)
    rows = (len(ims) + cols - 1) // cols
    s = Image.new("RGB", (cols * (tile_w + 10) + 10, rows * (tile_h + 10) + 10), (40, 40, 40))
    for i, im in enumerate(ims):
        s.paste(im.resize((tile_w, tile_h), Image.LANCZOS),
                (10 + (i % cols) * (tile_w + 10), 10 + (i // cols) * (tile_h + 10)))
    s.save(out)
    print(f"{out}  {len(ims)} images")
    for n, f in enumerate(files, 1):
        print(f"  {n:2d}  {f.name}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    sheet(sys.argv[1], sys.argv[2], *(int(a) for a in sys.argv[3:5]))
