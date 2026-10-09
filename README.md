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
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. Always talks to `https://rvmi.deskcheque.top`.
