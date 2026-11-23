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
   `https://github.com/infinityladder/weight_tracker/blob/main/PRIVACY.md`
3. **App access:** all functionality is available without special access.
4. **Ads:** no ads.
5. **Content rating:** fill in the questionnaire. No violence, no user
   content, no sharing of location, no purchases.
6. **Target audience:** 18 and over (or 13+). Not for children.
7. **Data safety:**
   - Does the app collect or share user data? **No.** Data stays on the
     device; exports go only where the user sends them through the share
     sheet, which Play doesn't count as collection.
   - Encryption in transit: not applicable (no network).
   - Can users request deletion: yes, by uninstalling or clearing app data.
8. **Health apps declaration:** the app is a fitness and weight tracker. It
   doesn't use Health Connect and makes no medical claims.
9. **Category:** Health & Fitness.
10. **Store listing:** see below.

## Store listing

The listing text is in [store-listing/store_listing.md](store-listing/store_listing.md).

**Graphics:**

- App icon, 512 × 512, 32-bit PNG: `logo/play-store-icon-512.png`
- Feature graphic, 1024 × 500 PNG or JPG (still to make)
- Screenshots: `store-listing/screenshots/<newest date>/marketing/`, with
  `phone/`, `tablet_7/` and `tablet_10/` folders. Upload `01`…`08` in order.

## Testing track

New personal developer accounts must run a closed test with at least 12
testers for 14 days before they can publish to production. Upload the first
bundle to the **Closed testing** track and invite testers by email or Google
Group.
