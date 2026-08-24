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

## Validation

```bash
flutter analyze
flutter test
```
