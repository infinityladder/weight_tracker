"""Writes store-listing/demo_data.csv: ~12 weeks of demo history ending on the
capture day, imported into the emulator through the app's own Import button.

    python store-listing/make_demo_csv.py [YYYY-MM-DD end date, default today]
"""
import csv, random, sys
from datetime import date, timedelta
from pathlib import Path

end = date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else date.today()
rng = random.Random(7)
days = 84
start = end - timedelta(days=days)
measures = {  # start -> end, cm
    "Chest": (106.0, 102.5), "Waist": (94.5, 88.0), "Hips": (104.0, 100.5),
    "L-Bicep": (36.0, 35.4), "R-Bicep": (36.5, 35.9),
    "L-Thigh": (60.5, 58.0), "R-Thigh": (61.0, 58.4),
}
rows = []
for i in range(days + 1):
    d = start + timedelta(days=i)
    t = i / days
    weigh = i == 0 or i == days or rng.random() < 0.68
    measure = i % 14 == 0
    if not (weigh or measure):
        continue
    w = 86.4 - 5.4 * t + rng.uniform(-0.35, 0.35)
    row = {"date": d.isoformat(), "time": f"07:{rng.randint(2, 40):02d}",
           "weight_kg": f"{w:.1f}" if weigh else ""}
    for k, (a, b) in measures.items():
        row[f"{k} (cm)"] = f"{a + (b - a) * t + rng.uniform(-0.2, 0.2):.1f}" if measure else ""
    rows.append(row)
# An evening weigh-in today: shows as a note beside the main morning one.
rows.append({"date": end.isoformat(), "time": "19:30", "weight_kg": "81.6",
             **{f"{k} (cm)": "" for k in measures}})
out = Path(__file__).with_name("demo_data.csv")
with out.open("w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=list(rows[0]))
    wr.writeheader()
    wr.writerows(rows)
print(out, len(rows), "rows")
