---
name: flutter-release
description: Build and release Flutter app for Android and iOS platforms.
disable-model-invocation: true
---

We're going to prepare your Flutter app for release on Android and/or iOS platforms.

## Platform Selection

First, ask the user which platform(s) they want to release for:

- [ ] Android (APK / App Bundle)
- [ ] iOS (IPA / App Store)

## Pre-Release Checklist

Before building, ensure the following:

- [ ] Run `flutter analyze` to check for any issues.
- [ ] Run `flutter test` to ensure all tests pass.
- [ ] Verify the app version in `pubspec.yaml` is correct.
- [ ] Ensure all debug code and print statements are removed or disabled.
- [ ] Check that the app icon and splash screen are configured.

## Version Management

Ask the user about version management:

- Current version in `pubspec.yaml`: Read and display it.
- Ask if they want to bump the version (major/minor/patch).
- Update `pubspec.yaml` with the new version if requested.

```yaml
# Version format in pubspec.yaml
version: 1.0.0+1  # version_name+build_number
```

---

## Android Release

### Android Signing Configuration

1. **Check for existing keystore:**
   - Look for `android/app/upload-keystore.jks` or ask user for keystore location.
   - If no keystore exists, guide the user to create one:

   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```

2. **Configure signing in `android/app/build.gradle`:**
   - Ensure `signingConfigs` block exists with release configuration.
   - Reference `key.properties` file for credentials (keep out of version control).

3. **Create `android/key.properties`** (add to `.gitignore`):

   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=<path-to-keystore>
   ```

### Build Android Release

**Option 1: APK (for direct distribution)**

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

**Option 2: App Bundle (for Google Play Store - recommended)**

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Android Release Checklist

- [ ] Signing configured correctly
- [ ] App bundle or APK built successfully
- [ ] ProGuard rules configured (if using obfuscation)
- [ ] Permissions reviewed in `AndroidManifest.xml`
- [ ] Internet permission added if needed

---

## iOS Release

### iOS Signing Configuration

1. **Apple Developer Account:**
   - Ensure user has an active Apple Developer account.
   - Verify team ID and bundle identifier in Xcode.

2. **Open Xcode for signing setup:**

   ```bash
   open ios/Runner.xcworkspace
   ```

3. **In Xcode:**
   - Select "Runner" target → "Signing & Capabilities"
   - Select the correct Team
   - Ensure "Automatically manage signing" is checked (or configure manually)
   - Verify Bundle Identifier matches App Store Connect

### Build iOS Release

**Option 1: Archive for App Store**

```bash
flutter build ios --release
```

Then archive in Xcode:
- Product → Archive
- Distribute App → App Store Connect

**Option 2: IPA for Ad Hoc / Enterprise distribution**

```bash
flutter build ipa --release
```

Output: `build/ios/ipa/*.ipa`

### iOS Release Checklist

- [ ] Bundle identifier configured correctly
- [ ] App icons for all required sizes (1024x1024 for App Store)
- [ ] Launch screen configured
- [ ] Signing certificates and provisioning profiles valid
- [ ] Info.plist permissions configured with usage descriptions
- [ ] App Transport Security configured (if needed)

---

## Post-Build Verification

After building:

- [ ] Test the release build on a real device.
- [ ] Verify app functionality in release mode.
- [ ] Check app size is acceptable.
- [ ] Test deep links if applicable.

## Distribution

### Android Distribution

- **Google Play Store:** Upload `.aab` to Google Play Console.
- **Direct Distribution:** Share `.apk` file directly.
- **Firebase App Distribution:** `firebase appdistribution:distribute`

### iOS Distribution

- **App Store:** Upload via Xcode or Transporter app.
- **TestFlight:** Upload to App Store Connect for beta testing.
- **Ad Hoc:** Distribute `.ipa` to registered devices.

## Final Steps

- [ ] Create a git tag for the release version.
- [ ] Update CHANGELOG.md with release notes.
- [ ] Commit version bump and any release-related changes.

```bash
git tag v1.0.0
git push origin v1.0.0
```
