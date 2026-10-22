# RVMI Media (Flutter)

Android app for the church media library, event discussions, and inventory. Client of [server](../server) at `https://rvmi.deskcheque.top`.

One-time service setup (S3, Google Sign-In, Rekognition, FCM, cron): the markdown files in [RVMI-MEDIA](../).

## Run

Needs Flutter (stable, built against 3.44.x) and Android SDK.

```bash
flutter pub get
flutter run
```

- Debug (`flutter run`): probes `http://10.0.2.2:8000/up` once. If local Laravel is up, that host is used for the rest of the process; otherwise `https://rvmi.deskcheque.top`. Restart the app after starting `php artisan serve` to pick up local.
- `--dart-define=API_BASE_URL=https://rvmi.deskcheque.top` skips the probe (force production, a tunnel, or a LAN IP). Do not append `/api` — the app adds it.
- Physical phone: `10.0.2.2` is unreachable, so a plain `flutter run` falls through to production.
- Release (`flutter build apk --release`): always `https://rvmi.deskcheque.top`. No localhost probe.

Google Sign-In (optional until [GOOGLE.md](../GOOGLE.md) is done):

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
```

While `flutter run` is attached, the terminal accepts single-key commands (no Enter):

| Key | What it does |
| --- | --- |
| `r` | Hot reload |
| `R` | Hot restart |
| `h` | Print the full list of keys |
| `q` | Quit |
| `d` | Detach |

Hot reload will not pick up native changes (Android icons, splash, Gradle, `pubspec.yaml` assets). For those, stop with `q` and `flutter run` again.

### Physical phone (Wi-Fi)

Same as DeskCheque-Mobile: phone + PC on the same Wi-Fi, wireless debugging, then `flutter run`. Confirm with `adb devices`.

## Build

```powershell
# For Play Store release, you must build a signed Android App Bundle (.aab):
flutter build appbundle --release

# If you try to upload an APK or AAB that wasn't properly signed for release, 
# the Play Store will show an error like:
# "You uploaded an APK or Android App Bundle that was signed in debug mode. You need to sign your APK or Android App Bundle in release mode."
#
# To fix this:
# 1. Make sure you are building in release mode, and have configured signing in `android/app/build.gradle` (using your keystore).
# 2. Follow the official guide: https://docs.flutter.dev/deployment/android#signing-the-app
#
# Example signing config (in android/app/build.gradle):
#
# android {
#   ...
#   defaultConfig { ... }
#   signingConfigs {
#     release {
#       storeFile file('/path/to/your.keystore')
#       storePassword 'your-store-password'
#       keyAlias 'your-key-alias'
#       keyPassword 'your-key-password'
#     }
#   }
#   buildTypes {
#     release {
#       signingConfig signingConfigs.release
#     }
#   }
# }
# Obtaining and Using Release Keystore (Play Store Signing)

To generate release-ready builds for the Play Store, you need signing keys. There are two scenarios:

**A. If Play App Signing is Enabled (recommended for Play Store):**
1. Go to https://play.google.com/console > Your App > "Setup" > "App integrity".
2. Under "App signing", download the "upload key" certificate (`.pem`). 
3. You are responsible for generating and securing your private keystore file (the "upload key").
   - If you have not already created one, generate it with:
     ```shell
     keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
     ```
   - Save `upload-keystore.jks` and its password in a safe place.
   - When uploading to Play Store, Flutter uses your upload key. The Play Store then re-signs the build with their official release key.
4. Place your keystore file (e.g., `upload-keystore.jks`) in `android/app/`:
   ```
   android/app/upload-keystore.jks
   ```
5. Reference it in `android/app/build.gradle` like this:
   ```groovy
   signingConfigs {
     release {
       storeFile file('upload-keystore.jks')
       storePassword 'your-store-password'
       keyAlias 'upload'
       keyPassword 'your-key-password'
     }
   }
   ```

**B. If You Are Using Your Own Release Key:**
1. Generate a new keystore, or use your existing release keystore (used in past apps).
2. Place your `.jks` file in the `android/app/` folder of your project.
3. Set up `android/app/build.gradle` as above, pointing to your keystore and credentials.
4. Keep this file private and never check it into version control.

**Important:**  
- Never commit your keystore files or passwords to git.  
- Always back up your keystore and credentials in a secure location. Losing your release keys means you cannot update the app!
# Then run:
flutter build appbundle --release

# For sideloading/testing (not for Play Store), you can still build an APK:
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. Always talks to `https://rvmi.deskcheque.top`.

## BlueStacks shared folder

Use this when photos are edited on Windows and uploaded from the app. BlueStacks runs the Android APK. There is no separate Windows build.

1. Install `app-release.apk` in a BlueStacks instance that includes the Play Store, then sign in with the same Google account used on the phone.
2. Export JPEGs from the editor. The app rejects raw camera files. Copy the JPEGs into the BlueStacks shared folder (Media Manager).
3. In the app, open Upload and pick those files. The shared folder is only where the files come from. The app has no custom folders. Upload from Home goes to the main library. Upload from an event attaches the photos to that event.

A phone-sized BlueStacks profile keeps the current mobile layout, even when the Windows window is large. A tablet profile, or a resolution whose shortest side is at least 600dp, shows more photo columns. At 840dp and wider, the bottom bar moves to a side rail.
