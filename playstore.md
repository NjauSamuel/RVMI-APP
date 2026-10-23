# Play Store Signing

To build a release version of your app for the Play Store, you must sign it with a release keystore.

## 1. Generate an upload keystore

If you haven't generated one yet, run this command from the **root of the project**:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

*Note: Choose a strong password and keep it safe. If you lose this keystore, you cannot update your app on the Play Store.*

## 2. Configure credentials

I have created a template at `android/key.properties`. Open it and replace the placeholder passwords with the ones you created in the previous step:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

## 3. Build the App Bundle

Once the `upload-keystore.jks` is in `android/app/` and `key.properties` is in `android/`, run:

```bash
flutter build appbundle --release
```

The resulting file will be at `build/app/outputs/bundle/release/app-release.aab`. This is the file you upload to the Google Play Console.

## Troubleshooting

If you see the error:
> "You uploaded an APK or Android App Bundle that was signed in debug mode..."

It means the signing configuration was not picked up. Ensure:
1. `android/key.properties` exists and has the correct values.
2. `android/app/upload-keystore.jks` exists in the correct folder.
3. You ran the `flutter build ... --release` command.