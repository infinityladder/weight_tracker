# Publishing Simple Body Log to Google Play

## Build

Use the latest stable Flutter (`flutter channel stable && flutter upgrade`).

```sh
flutter build appbundle --release
```

The bundle to upload is `build/app/outputs/bundle/release/app-release.aab`.

Before every upload, raise the build number in `pubspec.yaml`
(`version: 1.0.0+1` → `1.0.1+2`). Play rejects a build number it has seen.

## Signing

- Package name: `com.simplebodylog.app`. It can't change after the first upload.
- Upload key: `C:\Users\malin\signing_keys\body-log-upload.jks`, alias `upload`.
- `android/key.properties` (not in git) holds the passwords and key path.
  Without it, release builds are signed with the debug key and Play will
  reject them.
- Back up the keystore and `key.properties` somewhere safe (password manager
  or encrypted drive). Leave Play App Signing on (the default): Google holds
  the real signing key, and a lost upload key can be reset through Play
  Console support.

## Play Console setup

1. Create the app: name **Simple Body Log** (the app itself shows "Body log"), app (not game), free.
2. **Privacy policy URL:**
   `https://www.infinityladdertechnologies.com/products/simple-body-log/privacy/`
   (source: `infinityladder.github.io/products/simple-body-log/privacy/index.html`; facts below)
3. **App access:** all functionality is available without special access.
4. **Ads:** no ads. The listing and release notes don't promise "no ads", so
   adding them later only needs this answer, the Data safety form and the
   privacy policy updated before that release (ad SDKs collect device IDs).
5. **Content rating:** fill in the questionnaire. No violence, no user
   content, no sharing of location, no purchases.
6. **Target audience:** 13 and over. Not for children.
7. **Data safety:**
   - Does the app collect or share user data? **No.** Data stays on the
     device; an export is a CSV saved to a folder the user picks, which
     Play doesn't count as collection.
   - Encryption in transit: not applicable (no network).
   - Can users request deletion: yes, by uninstalling or clearing app data.
8. **Health apps declaration:** the app is a fitness and weight tracker. It
   doesn't use Health Connect and makes no medical claims.
9. **Category:** Health & Fitness.
10. **Store listing:** see below.

## Privacy facts

The answers the privacy policy was written from (2026-11-25). Start here when updating it.

| Question | Answer |
| --- | --- |
| Publisher | Infinity Ladder Technologies, Australia |
| Privacy contact | hello@infinityladdertechnologies.com |
| Data stored | Weigh-ins, measurements (incl. custom names), goal + start date, height, settings; on the device only (sqflite) |
| Network | None. The release build requests no permissions (INTERNET is debug/profile only) |
| SDKs that send data | None: no ads, analytics, crash reporting, push or sign-in |
| Export / import | Export saves a CSV to a folder the user picks (SAF); import reads a file the user picks |
| Device backup | Android Auto Backup left on: data may be in the user's own Google backup |
| In-app link | Settings → Privacy policy (url_launcher, opens the browser) |
| Target audience | 13 and over |
| Price | Free, no purchases |
| Planned | Ads, with a paid option to remove them. Update the policy, Data safety form, Ads answer and Content rating **before** that release |
| Maybe later | Unknown (analytics, sync, Health Connect not decided) |

## Store listing

The listing text is in [store-listing/store_listing.md](store-listing/store_listing.md).

**Graphics:**

- App icon, 512 × 512, 32-bit PNG: `logo/play-store-icon-512.png`
- Feature graphic: `store-listing/screenshots/<newest date>/marketing/feature-graphic.png`
  (`python scripts/make_feature_graphic.py store-listing/slides_config.py`)
- Screenshots: `store-listing/screenshots/<newest date>/marketing/`, with
  `phone/`, `tablet_7/` and `tablet_10/` folders. Upload `01`…`08` in order.

## Testing track

New personal developer accounts must run a closed test with at least 12
testers for 14 days before they can publish to production. Upload the first
bundle to the **Closed testing** track and invite testers by email or Google
Group.
