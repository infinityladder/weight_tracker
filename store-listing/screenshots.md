# Screenshots record — Simple Body Log

What the Play screenshots and feature graphic show, what each claims, and how to rebuild them.
Written by `development_readmes/android_store_screenshots/`. The change map is in
[README.md](README.md).

- **Current generation:** `store-listing/screenshots/2026-11-23/` · captured from build 1.0.0 (2)
  (build 3 only adds the Settings → Privacy policy link, which no slide shows)
- **Formats:** phone 1440×2560 (AVD Pixel_10_Pro), 7" tablet 2560×1440 (7_inch_tablet, landscape),
  10" tablet 2560×1440 (Pixel_Tablet_10_inch)
- **Rebuild:** release APK installed fresh, `python scripts/device.py prep`, then
  `python scripts/store_captures.py <phone|tablet_7|tablet_10> seed` and
  `python scripts/store_captures.py <format>`; then
  `python scripts/make_slides.py store-listing/slides_config.py` and
  `python scripts/make_feature_graphic.py store-listing/slides_config.py`.
  Set `MSYS_NO_PATHCONV=1` in Git Bash, and `ANDROID_SERIAL` when more than one emulator runs.
- **Demo data:** `store-listing/demo_data.csv` (from `make_demo_csv.py`: 12 weeks to 23 Nov 2026,
  86.4 → 80.8 kg), imported through Settings → Import; the seed step also sets height 182 cm,
  a custom "Wrist" measurement and a 78 kg goal from the first weigh-in.

## Slides

| # | Headline | Sub line | Screens (key, theme) | Claim backed by |
| --- | --- | --- | --- | --- |
| 1 | YOUR BODY, MEASURED | Weight and every measurement on one body map. | 01-home dark + light | Listing: body map |
| 2 | LOG IT IN SECONDS | Weigh in, or tap a body part and slide the ruler. | 02-weight dark, 02-ruler light | Listing: log weight; ruler |
| 3 | WATCH THE TREND | Charts for your weight and every measurement. | 03-trend dark + light | Listing: trend charts |
| 4 | SET A GOAL | See how far you've come since your start date. | 04-goal dark, 04-start light | Listing: goal and start date |
| 5 | KNOW YOUR NUMBERS | BMI, waist-to-height and waist-to-hip, on one Health screen. | 05-health dark, 05-numbers light | Listing: Health screen |
| 6 | EVERY ENTRY KEPT | Browse, edit or add past entries. | 06-data dark, 06-edit light | Listing: browse, edit, add |
| 7 | TRACK WHAT MATTERS | Pick from 16 measurements or name 3 of your own. | 07-female dark, 07-settings light | Listing: 16 + 3 custom; male/female |
| 8 | YOUR DATA, YOUR WAY | Kg or lb. Import and export CSV. Stays on your phone. | 08-imperial dark, 08-units light | Listing: units, CSV, "stay on your phone" |

## Feature graphic

`marketing/feature-graphic.png`, 1024×500: icon, "SIMPLE / **BODY LOG**", "Weight and body
measurements, on one body map."; the female body (07-female, light) behind the male body
(01-home, dark). Config: `FEATURE` in `slides_config.py`.

## Claims that would break if the app changed

| Claim | Where it appears | Breaks when |
| --- | --- | --- |
| "Stays on your phone" | Slide 8 sub | Cloud sync, backup to a server, web version |
| BMI, waist-to-height, waist-to-hip | Slide 5 | Health analyses removed or renamed |
| 16 measurements, 3 custom | Slide 7 | The measurement list changes |
| Kg or lb; CSV import/export | Slide 8 | Units or CSV removed |
| Home screen layout (HEALTH tile, body map) | Slides 1, 7, 8, feature graphic | Home redesign → new generation |

## Uploaded

- Play Console → Main store listing: {{date and formats — fill in when uploaded}}
- Website product page gallery: 01-home-dark, 02-ruler-light, 03-trend-dark, 04-goal-light,
  05-health-dark, 07-female-light (phone raw captures, via `make_product_images.py`); feature
  graphic as the page's social preview image.
