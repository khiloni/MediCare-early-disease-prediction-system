# 📱 Medicare AI — Mobile Deployment Guide (Patient App)

Follow these steps to run the Patient app on a real Android/iOS device or build a production APK.

## 1. Prerequisites
- **Flutter SDK** installed and added to PATH.
- **Android Studio** (for Android) or **Xcode** (for iOS/macOS).
- A real device connected via USB with **Developer Mode** and **USB Debugging** enabled.

## 2. Configuration (Supabase & Google Login)
For Google Login to work on a real device, you must configure the Redirect URI:
1. Open `lib/config/app_config.dart` and ensure `backendUrl` points to your machine's IP (e.g., `http://192.168.1.5:8000`) instead of `localhost`.
2. In your **Supabase Dashboard** → **Authentication** → **URL Configuration**:
   - Add `io.supabase.medicareai://callback` to the **Additional Redirect URIs**.
3. **Android Configuration**:
   - Open `android/app/src/main/AndroidManifest.xml`.
   - Ensure the `<intent-filter>` for deep linking is present:
     ```xml
     <intent-filter>
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <data android:scheme="io.supabase.medicareai" android:host="callback" />
     </intent-filter>
     ```

## 3. Run on Real Device
```bash
cd frontend
flutter pub get
flutter run --release
```
*Note: Using `--release` is recommended for performance testing on real devices.*

## 4. Build Release APK (Android)
To generate a standalone APK file for your phone:
1. Run the build command:
   ```bash
   flutter build apk --release
   ```
2. The APK will be located at:
   `build/app/outputs/flutter-apk/app-release.apk`
3. Transfer this file to your phone and install it!

## 5. Troubleshooting
- **Backend Connection**: Ensure your phone and computer are on the same Wi-Fi network.
- **CORS/Firewall**: Disable your computer's firewall or allow port 8000 if the app cannot connect to the backend.
- **Google Login**: Ensure the SHA-1 fingerprints from your Android project are added to the Google Cloud Console / Supabase Auth settings.
