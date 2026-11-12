# AppsFlyer Android install attribution

The Android app is `com.lioraai.videogenerator` (Liora). AppsFlyer SDK 7 is
initialized once at cold start, before Firebase initialization finishes. The
native session-ready listener starts every foreground session. Initialization
and session errors do not block app startup. iOS attribution is not enabled.

The configured Dev Key is used by default. Builds can override it with
`--dart-define=APPSFLYER_DEV_KEY=...`. This is an SDK client key, not a dashboard
API token. Do not put dashboard API tokens in the app.

The Flutter plugin supplies Google Play Install Referrer 2.2 and the Android
`com.google.android.gms.permission.AD_ID` permission through its dependencies and
merged manifest. No legacy install-referrer receiver or AdMob SDK is needed.

## Dashboard setup required before campaign validation

1. In AppsFlyer, add/select the Android app with the exact package above and
   verify its Dev Key matches the build. Set its Google Play listing when live.
2. Under Partner Marketplace / Integrated Partners, open Google Ads
   (`googleadwords_int`) and activate the partner. Follow its current Android
   integration instructions, including the Google Ads Link ID for this app.
3. In Google Ads, create/use the third-party app analytics connection for
   AppsFlyer and this Android app. Supply the resulting Link ID to the AppsFlyer
   Google Ads integration and save. Import the AppsFlyer install/first-open
   conversion into Google Ads when using it for campaign measurement or bidding.
   If Firebase already supplies a primary install conversion, review conversion
   goals to avoid optimizing/counting the same install twice.
4. Check the Google Ads customer accounts/campaigns permitted to use that link,
   and confirm the campaign points at this app's Google Play listing.
5. If collecting consent through a CMP in relevant markets, pass actual consent
   to AppsFlyer before the first session, using its consent APIs or supported
   TCF integration. This integration does not assume or fabricate consent.

Menu names can vary by account. Reference:
[Google Ads integration](https://support.appsflyer.com/hc/en-us/articles/207033746-Google-Ads-integration).

## How to interpret the result

- AppsFlyer install/session attribution is automatic; do not manually log an
  `install` event. An install is reported after the app is first opened.
- In AppsFlyer acquisition reporting, filter media source `googleadwords_int`
  and inspect campaign details to find installs attributed to Google Ads.
- AdMob is Google's publisher monetization platform. Google Ads campaigns can
  serve in apps using AdMob as well as other Google inventory. Google Ads
  attribution alone does not prove the ad appeared specifically on AdMob.
  Placement/network detail depends on the data Google makes available; consult
  Google Ads reporting for that breakdown where supported.
- Missing, delayed, or restricted attribution data is not proof of an organic
  install. SDK integration alone cannot guarantee 100% user-level attribution.
- The SDK conversion listener is registered before the session-ready listener.
  Known non-organic media sources (Google Ads, Meta, TikTok, etc.) map to `ADS`.
  Explicit organic results map to `ORGANIC`. Missing status/source, conflicting
  organic data, `unknown`, and `restricted` results are left unclassified. A
  conversion failure never defaults to organic. Restricted paid installs may
  therefore remain unreported with this deliberately conservative mapping.
- When sign-in or restored-session profile validation provides the backend user
  ID, the app sets AppsFlyer's Customer User ID. This does not retroactively
  attach that ID to an install already reported before authentication.
- The app sends `POST /users/update-install-source` with its Bearer token and
  `{"install_source":"ADS"}` or `{"install_source":"ORGANIC"}` only after both
  identity and classified attribution are available. The API derives the user
  from the token; no `user_id` is added to the request body.
- Classified attribution and per-user successful acknowledgements are cached in
  preferences. Pending reports survive app restarts and retry every 30 seconds
  after failure, on foreground resume, and when authentication/source changes.
  A per-user boolean success flag prevents all further reports after the first
  successful request, including later organic-to-ADS changes. Successful reports
  stored by the previous version also count as completed. Success is remembered
  in memory before saving the flag, so a storage failure retries the flag write
  without repeating the request during that process. If the app exits before
  the flag is persisted, or app data is cleared, a duplicate request is still
  possible; the backend should keep this operation idempotent. Non-2xx and explicit
  `success: false` responses remain pending. Authentication failures wait for
  ordinary session recovery rather than triggering sign-in from this endpoint.
- This is client-reported attribution for logging, not independently verified
  server attribution. Per-user data availability depends on partner restrictions
  and account configuration. No AppsFlyer API token or webhook is needed for this
  client-to-backend flow. iOS still does not report an install source.
- The existing Meta and Firebase analytics remain separate. This integration
  sends no custom purchase events or ad revenue events.

## Device and campaign validation

1. Register a test device using AppsFlyer's current test-device instructions.
2. For SDK diagnostics only, use a debug build:

   ```bash
   flutter run --dart-define=APPSFLYER_DEBUG_LOGGING=true
   ```

   Native verbose logs stay disabled in release builds even if this flag is set.
3. Use AppsFlyer's SDK Integration Tests to check a fresh install and first open.
   An APK installed over USB verifies SDK connectivity, not a real Google Ads
   install. An old installation or a normal reinstall can be classified according
   to AppsFlyer's reinstall/reattribution rules rather than as a new install.
4. Validate a real campaign with a new eligible device/user: click an actual ad,
   install the published build containing this integration from Google Play,
   and open it. Compare AppsFlyer media source/campaign with Google Ads reports,
   allowing for reporting delay and different attribution windows.

No dashboard linking, real-device attribution, or campaign delivery is verified
by local automated tests. Release requires the usual Google Play Data safety and
privacy disclosures to reflect the SDK's actual data collection.

Local checks for this integration:

```bash
flutter test test/appsflyer_service_test.dart test/install_source_reporter_test.dart test/api_client_test.dart test/profile_provider_test.dart
```

After dashboard setup, validate a fresh organic install and a real paid install
from Google Play. Confirm the SDK result and backend record agree. A USB install
or mocked callback cannot validate Google Ads attribution. Existing users with
unavailable historical conversion data stay unclassified; this change does not
reconstruct their original install source.

SDK reference:
[Flutter SDK getting started](https://github.com/AppsFlyerSDK/appsflyer-flutter-plugin/blob/master/doc/getting-started.md).
