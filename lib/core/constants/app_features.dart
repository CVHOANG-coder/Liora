abstract final class AppFeatures {
  // Legal and support links are shown by default, but can still be disabled
  // for builds that must not expose external destinations.
  static const bool externalLinksEnabled = bool.fromEnvironment(
    'ENABLE_EXTERNAL_LINKS',
    defaultValue: true,
  );

  // Onboarding is shown to users who have not completed it yet. Builds can
  // still opt out when they must enter the app directly from Splash.
  static const bool onboardingEnabled = bool.fromEnvironment(
    'ENABLE_ONBOARDING',
    defaultValue: true,
  );

  // Purchases, credits, and subscriptions are available in the current app.
  // Builds can opt out when store billing must remain unavailable.
  static const bool commerceEnabled = bool.fromEnvironment(
    'ENABLE_COMMERCE',
    defaultValue: true,
  );
}
