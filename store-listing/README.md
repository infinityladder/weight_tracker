# Store records — Simple Body Log

What was published and declared for Google Play, and where it lives. Each record is written by
a skill in `development_readmes/` and updated when the app changes. **Before a release that
changes how the app handles data, money or users, follow the change map below.**

| Record | What it covers | Written by |
| --- | --- | --- |
| [store_listing.md](store_listing.md) | Listing text: name, short and full description — the source of truth for every claim | by hand / the skills |
| [screenshots.md](screenshots.md) | Screenshot generation 2026-11-23, 8 slides per format and the claim each makes, feature graphic, capture script, demo data | `android_store_screenshots/` |
| [privacy-and-product-page.md](privacy-and-product-page.md) | The privacy policy (URL, the answer sheet it was written from, its sections, every place it is linked) and the product page | `privacy_policy_and_product_page/` |
| [play-console.md](play-console.md) | Every App content answer and store settings | `play_console_checklist/` |

## Change map

Find the change, then update **every** place in its row **before** that release ships.
"PC n" = item n in [play-console.md](play-console.md).

| The app starts to… | Privacy policy | Play Console | Listing, screenshots, website | In the app |
| --- | --- | --- | --- | --- |
| **Show ads** — *planned* | Add *Advertising* section; *Data we collect and share* names the ad network and data types; drop "contains no advertising"; *Last updated* | PC 3 Ads → Yes; PC A Advertising ID → Yes; PC 6 Data safety (device IDs, app interactions, approx. location → shared, advertising); PC 4 recheck; PC 5 (no under-13s, so no Families rules) | Nothing promises "no ads" today — keep it so; "Contains ads" label appears | EEA/UK/CH consent (UMP); AD_ID permission arrives with the SDK |
| **Sell "remove ads"** — *planned* | Add *Purchases* section (Google Play processes payment) | PC 2 Sign in details → Yes + reviewer steps; PC 4 digital purchases → Yes; PC 10 Terms of Service URL (consider) | Listing and product page mention it | Restore purchases; licence testers for reviewers |
| **Send data to a server** (sync, cloud backup, web version) | *Data the app handles*, *Data we collect and share*, *How your data is protected*, *Keeping and deleting*, *Your rights*; drop "doesn't use the internet" | PC 6 Data safety → Yes (types, encrypted in transit, deletion); PC 4 Online content if content comes back | "Your measurements stay on your phone" (listing), slide 8 sub "Stays on your phone", product page lead and feature list, `PRIVACY.md` | INTERNET permission; prominent disclosure |
| **Add accounts / sign-in** | Account data, deletion (in app + web link), retention | PC 2 → Yes + test account; PC 6 (name, email, IDs); account deletion URL | "No account needed" (listing, product page) | In-app account deletion; web deletion page |
| **Add analytics or crash reporting** | Name the provider, data sent, purpose, opt-out; drop "no … analytics or tracking" | PC 6 (app interactions, crash logs, diagnostics, device IDs); PC A if it reads the ad ID | — | Opt-out if offered |
| **Use Health Connect or body sensors** | *Health and fitness information*: what is read/written and why | PC 9 Health (+ Health Connect permissions declaration); PC 6 if it leaves the device | Hardware/sensor requirements in the description | Permission rationale screen |
| **Change the audience** (adds under-13s, or 18+ only) | *Children* section | PC 5; PC 4; Families policy if under 13 | Listing and art suitable for the audience | Health screen's adult-ranges note |
| **Add or redesign a feature or screen** | Only if it handles data differently | PC 4 if it adds content types | New screenshot generation ([screenshots.md](screenshots.md)); listing features; product page features and gallery | — |
| **Rename or rebrand** | Title and app name | Store listing name; PC 11 | Feature graphic, slides, product page, icon | App label |
