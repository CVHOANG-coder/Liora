# Liora branding

The display name is Liora on iOS, Android and in Flutter. User-facing copy, share titles, support details and newly exported video filenames use Liora. Existing package/bundle IDs, store product IDs, Firebase/Meta identifiers, API URLs and cache keys are intentionally unchanged for compatibility. App Store/Play Store listing metadata and remotely hosted legal/support pages are managed outside this repository.

- In-app mark: `assets/images/home/lola_logo.png` (the existing L artwork).
- Launcher master: `assets/branding/lola_app_icon.png`.
- iOS variants: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- Android variants: `android/app/src/main/res/mipmap-*/ic_launcher.png`.
- Native launch mark: `ios/Runner/Assets.xcassets/LaunchImage.imageset/Liora*.png`.

Launcher artwork was composed with the built-in ImageGen tool and resized for each native slot. Unused legacy source images and the old splash/purchase artwork were removed from `assets/` after verifying that no app or test code referenced them.

## Final icon prompt

Use case: compositing. Asset: production iOS/Android app launcher icon for Liora. Image 1 is the existing letter-L brand mark, preserve its exact recognizable ribbon L silhouette, pink-purple-blue glossy material, small play triangle, and proportions. Image 2 is the OLD launcher icon, use only as a dark-background mood reference and replace its N entirely. Output a square opaque edge-to-edge 1024x1024 PNG icon: place the L from Image 1 centered, occupying 72% of the canvas width/height with safe even padding, on a nearly black navy #02050C background with a very subtle purple ambient glow. No N, no words, no new symbols, no border, no built-in rounded-square corners, no stars or orbit decorations. The L must be crisp and legible at small sizes. Keep original L design, do not redesign it.
