# VideoGen

Minimal Flutter codebase derived from the WaifuAI architecture and interface direction.

## Screens

- Home: welcome content, feature cards, quick actions, and recent projects.
- Profile: account information, statistics, Pro plan, and account menu.
- Bottom navigation: Home and Profile with a centered create button.
- Create sheet: opens from the `+` button and provides video creation options.

## Structure

```text
lib/
├── core/constants/
├── presentation/screens/
│   ├── home/
│   ├── main/
│   └── profile/
├── presentation/widgets/
├── shared/themes/
└── main.dart
```

## Run the project

```bash
flutter pub get
flutter run
```

### iOS: missing XCFrameworks after moving the project

Swift Package Manager caches absolute paths under `build/ios/SourcePackages`.
If Xcode reports missing Facebook or Firebase XCFrameworks at the project's old
location, regenerate the local build files from the project root:

```bash
flutter clean
flutter pub get
flutter build ios --simulator --debug
flutter run
```

The first build downloads the native packages again and requires network access.
Keep the committed `Package.resolved` files so package versions stay pinned.

## Validation

```bash
flutter analyze
flutter test
```

## Meta / Facebook app ads

Meta SDK configuration, tracking consent, and the dashboard/device verification
checklist are documented in [docs/meta_app_events.md](docs/meta_app_events.md).

## AppsFlyer Android attribution

Android install attribution and the Google Ads dashboard/testing checklist are
documented in [docs/appsflyer_android.md](docs/appsflyer_android.md).

## Android first-video notification

The persistent notification for the first three completed videos is documented
in [docs/android_video_onboarding.md](docs/android_video_onboarding.md).
