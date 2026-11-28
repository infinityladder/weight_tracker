# Play Console record — Simple Body Log

Every answer given in Play Console → **App content** and **Store settings**, with the reason
and what would change it. Written by `development_readmes/play-console-checklist/`; the change
map is in [README.md](README.md).

- Package: `com.simplebodylog.app` · Play name: **Simple Body Log** · App · Price: Free
- Last walked through: 2026-11-25 · Build at the time: 1.0.0 (3)

| # | Item | Status | Answer given | Reason (evidence) | Changes when |
| --- | --- | --- | --- | --- | --- |
| 1 | Privacy policy | done 2026-11-25 | https://www.infinityladdertechnologies.com/products/simple-body-log/privacy/ | [privacy-and-product-page.md](privacy-and-product-page.md) | Any data handling change |
| 2 | Sign in details | done 2026-11-25 | **No**, no part of the app is restricted | No sign-in, no purchases, no codes, PINs or biometrics | Paid "remove ads" (planned): Yes + a way for reviewers to see it |
| 3 | Ads | done 2026-11-25 | **No, my app does not contain ads** | No ads SDK; no AD_ID permission | Ads (planned) |
| 4 | Content rating | done 2026-11-25 | Email hello@infinityladdertechnologies.com; *All Other App Types*; every answer No (downloaded content, user content sharing, online content, age-restricted products, location sharing, digital purchases, rewards/crypto, browser, news/educational). Ratings: {{fill in from the Summary}} | Plain tracker; body art is ordinary sportswear; privacy link opens one fixed page | "Remove ads" = digital purchase → Yes |
| 5 | Target audience | **pending** | 13–15, 16–17, 18 and over — **or** 18 and over only (owner to choose); does not appeal to children | Health screen uses adult BMI ranges and says "for adults" | New audience, child-like art |
| 6 | Data safety | done 2026-11-25 | Collect or share required data types: **No** → "No data collected", "No data shared with third parties". Badges skipped | Nothing leaves the device; export/import user-initiated through the system file picker (exempt); privacy link = open web; Auto Backup goes to the user's own Google account | Ads, analytics, cloud, accounts |
| 7 | Government apps | done 2026-11-25 | **No** | Not made by or for a government | — |
| 8 | Financial features | done 2026-11-25 | **My app doesn't provide any financial features** | Play billing for "remove ads" later is not a financial feature | Payments, rewards, wallets |
| 9 | Health | done 2026-11-25 | *Activity and fitness* + *Nutrition and weight management*; nothing under Medical | Weight, body measurements, goal weight; BMI and ratios are screening guides with a disclaimer | Health Connect, sensors, medical claims |
| 10 | Trader status | done 2026-11-25 | **Yes, my trader status applies to this app**; no Terms of Service URL | Business account publishing its own app; nothing to agree to | "Remove ads": consider a ToS page at `/products/simple-body-log/terms/` |
| 11 | Category and contact | done 2026-11-25 | App; **Health & Fitness**; weight/body tracking tags; email hello@infinityladdertechnologies.com; no phone; website https://www.infinityladdertechnologies.com/products/simple-body-log/; external marketing on | Main function | — |
| 12 | Store listing | in progress | Text from [store_listing.md](store_listing.md) (incl. the health disclaimer); feature graphic + 8 slides per format from [screenshots.md](screenshots.md) | — | Features, claims, screenshots |
| A | Advertising ID | done 2026-11-25 | **No** | Release build requests no permissions (no `AD_ID`); checked on the build 3 merged manifest | Ads (planned): Yes, *Advertising or marketing* |
| B | Product page | done 2026-11-25 (site commit `fdd728b`, live) | https://www.infinityladdertechnologies.com/products/simple-body-log/ with "Coming soon to Google Play" | Store settings website; social preview | Launch: swap in the Play badge on the page and the products index |

## Pending decisions

- **Target audience (5):** 13+ (keep the Health screen's adults-only note) or 18 and over only — owner.
- **Content rating (4):** record the ratings shown on the Summary.

## Things done elsewhere because of these answers

- Health disclaimer added to `store_listing.md` and the product page (item 9).
- In-app Settings → Privacy policy link, build 3 (item 1).
- Product page and products index card on the website (items 11, B).
- Listing, release notes and pages written without promising "no ads" (item 3, ads planned).

## Planned changes that will reopen items

- **Ads with a paid "remove ads" option:** items 2, 3, 4, 6, 10, A, plus the privacy policy —
  see the change map in [README.md](README.md).
