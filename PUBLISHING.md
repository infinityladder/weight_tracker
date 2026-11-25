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

## Store listing and Play Console

Everything published and declared for Google Play is recorded in
[store-listing/](store-listing/README.md), with a change map for when the app adds ads,
purchases, cloud sync or accounts:

- [store_listing.md](store-listing/store_listing.md) — the listing text.
- [screenshots.md](store-listing/screenshots.md) — slides, feature graphic, how to rebuild them.
- [privacy-policy.md](store-listing/privacy-policy.md) — the hosted policy, what it was
  written from, where it is linked.
- [play-console.md](store-listing/play-console.md) — every App content answer and the reason.

Graphics to upload:

- App icon, 512 × 512, 32-bit PNG: `logo/play-store-icon-512.png`
- Feature graphic: `store-listing/screenshots/<newest date>/marketing/feature-graphic.png`
- Screenshots: `store-listing/screenshots/<newest date>/marketing/` → `phone/`, `tablet_7/`,
  `tablet_10/`; upload `01`…`08` in order (not `_thumbnail-test.png`).

## Testing track

New personal developer accounts must run a closed test with at least 12
testers for 14 days before they can publish to production. Upload the first
bundle to the **Closed testing** track and invite testers by email or Google
Group.
