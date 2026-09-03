abstract final class AppFeatures {
  // TODO(external-links): Re-enable Privacy, Terms, and Help links when their
  // destinations are ready to be exposed in the app again.
  static const bool externalLinksEnabled = bool.fromEnvironment(
    'ENABLE_EXTERNAL_LINKS',
    defaultValue: false,
  );

  // TODO(onboarding): Re-enable the onboarding flow when it is needed again.
  // The current build goes directly from Splash to the main screen.
  static const bool onboardingEnabled = bool.fromEnvironment(
    'ENABLE_ONBOARDING',
    defaultValue: false,
  );

  // TODO(commerce): Re-enable purchases, credits, and subscriptions when the
  // product is ready to expose them again. Keeping this behind a compile-time
  // flag preserves the existing implementation without shipping its UI or
  // starting the store connection in the current build.
  static const bool commerceEnabled = bool.fromEnvironment(
    'ENABLE_COMMERCE',
    defaultValue: false,
  );
}
