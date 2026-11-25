# Privacy policy and product page record — Simple Body Log

What the privacy policy says, what it was written from, every place it is linked, and the
product page. Written by `development_readmes/privacy_policy_and_product_page/`. Before changing
how the app handles data, read the change map in [README.md](README.md) and section 10 of the skill.

- **Live URL:** https://www.infinityladdertechnologies.com/products/simple-body-log/privacy/
- **Source:** `infinityladder.github.io/products/simple-body-log/privacy/index.html`
- **Last updated** (on the page): 2026-11-25 · written for build 1.0.0 (3)

## Answer sheet (what the policy was written from)

| # | Question | Answer | Evidence |
| --- | --- | --- | --- |
| 1 | Publisher and country | Infinity Ladder Technologies, Australia | owner |
| 2 | Privacy contact email | hello@infinityladdertechnologies.com | owner |
| 3 | App name, site slug | Simple Body Log (shows "Body log" on the phone); `simple-body-log` | |
| 4 | Data stored, and where | Weigh-ins (date, time, weight), measurements incl. custom names, goal + start date, height, settings (units, body, window, BMI ranges, health analyses); on the device only | `lib/db.dart` (sqflite: entries, fields, settings) |
| 5 | Network use | None | Merged release manifest has no INTERNET (debug/profile only); no URLs in code except the policy link |
| 6 | Accounts / sign-in | None | scan: no ACCOUNTS |
| 7 | SDKs that send data | None (no ads, analytics, crash, push) | scan: dependencies are flutter_riverpod, sqflite, path_provider, file_picker, fl_chart, intl, url_launcher |
| 8 | Permissions in the release build | None | merged release manifest |
| 9 | Export / import / share | Export saves a CSV to a folder the user picks; import reads a file the user picks | `lib/screens/data_transfer.dart` (system file picker) |
| 10 | Sensitive data | Weight and body measurements = health information, on device only | |
| 10a | Android Auto Backup | Left on; mentioned (data may be in the user's own Google backup) | manifest sets no `allowBackup` |
| 11 | Target audience | 13 and over (Play Console choice still pending: 13+ or 18+ only) | owner |
| 12 | Price | Free, no purchases | owner |
| 13 | Ads later? | **Yes, planned**, with a paid option to remove them | owner |
| 14–17 | Analytics, cloud/accounts, Health Connect, other | Not decided | owner |

## What the page contains

| Section | Kept? | What it says, in short |
| --- | --- | --- |
| Who we are | required | Made by Infinity Ladder Technologies, Australia; shows as Body Log on the phone |
| Data the app handles | required | The list in answer 4; stays on the device; no account, no server, no internet |
| Data we collect and share | required | None; this version has no advertising, analytics or tracking services |
| Health and fitness information | yes | Health information, on device only, not used for ads, not sold or shared |
| Export and import | yes | CSV to a folder the user picks; file the user picks; cloud folders follow their own policy |
| Device backups | yes | Android backup may include the data, in the user's own Google account |
| Permissions | yes | None |
| How your data is protected | required | App-private storage; nothing sent over the network |
| Keeping and deleting your data | required | Delete entries in the app; clear storage or uninstall; exports stay |
| Children | required | Not directed at under-13s |
| Your rights | required | We hold nothing; contact us; OAIC in Australia |
| Changes to this policy | required | Updated **before** a version that shows ads, offers purchases or uses the internet |
| Contact | required | hello@infinityladdertechnologies.com, website |
| Advertising, Analytics, Purchases | not included | Not in this build — add with the change map |

## Where it is linked (all must stay in step)

| Place | Where exactly |
| --- | --- |
| Play Console → App content → Privacy policy | the live URL |
| In the app | `lib/screens/settings_sheet.dart`: `privacyPolicyUrl` and the Settings → PRIVACY POLICY button (url_launcher, external browser; `<queries>` VIEW https in the manifest) |
| Repo summary | `PRIVACY.md` |
| Website | product page `/products/simple-body-log/` and the products index ("Privacy policy ->") |
| Data safety form | "No data collected" — [play-console.md](play-console.md) item 6 |

## Claims elsewhere that depend on this policy

- Store listing: "No account needed. Your measurements stay on your phone."
- Slide 8 sub: "Stays on your phone."
- Product page: lead ("keep every entry on your own phone. No account needed") and the last feature line.
- `PRIVACY.md` summary bullets.

## Product page

- **Live URL:** https://www.infinityladdertechnologies.com/products/simple-body-log/ · source
  `infinityladder.github.io/products/simple-body-log/index.html` (site commit `fdd728b`) · card on
  `products/index.html`
- **Store action:** "Coming soon to Google Play" (no badge until the app is public); Privacy policy link
- **Images:** `images/products/simple-body-log/` — icon (512), feature graphic (social preview),
  gallery: 01-home-dark, 02-ruler-light, 03-trend-dark, 04-goal-light, 05-health-dark,
  07-female-light (generation 2026-11-23)
- **Claims on the page** (match the listing): cards *Body map*, *Trend and goal*, *Health screen*;
  the listing's feature list; lead "keep every entry on your own phone. No account needed";
  the health disclaimer under the gallery
- **Used as:** Play Console Store settings → Website ([play-console.md](play-console.md) item 11)
- **At launch:** swap "Coming soon" for the Play badge
  (`https://play.google.com/store/apps/details?id=com.simplebodylog.app`) on the page and the index card
