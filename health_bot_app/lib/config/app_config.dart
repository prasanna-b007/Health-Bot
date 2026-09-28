/// Build-time configuration.
///
/// Nothing secret is hardcoded here. Values come from `--dart-define`, so the
/// repository carries no API keys and each developer points at their own
/// backend without editing tracked source:
///
///   flutter run \
///     --dart-define=RASA_BASE_URL=http://10.0.2.2:5005 \
///     --dart-define=PLACES_API_KEY=your_key_here
///
/// A `--dart-define-from-file=env.json` is usually more convenient; env.json is
/// gitignored. See README.md.
///
/// Note that a key compiled into a mobile binary is extractable by anyone who
/// has the app. `--dart-define` keeps it out of version control, which is a
/// different problem from keeping it out of the build. If the quota matters,
/// proxy the places lookup through your own backend.
library;

class AppConfig {
  const AppConfig._();

  /// Rasa REST webhook host.
  ///
  /// Android emulator reaches the host machine on 10.0.2.2; a physical device
  /// needs your machine's LAN IP; Flutter web uses localhost.
  static const String rasaBaseUrl = String.fromEnvironment(
    'RASA_BASE_URL',
    defaultValue: 'http://10.0.2.2:5005',
  );

  /// Shared secret for the Rasa REST API, sent as the `token` query
  /// parameter that `rasa run --auth-token` checks.
  ///
  /// A token compiled into a mobile binary is extractable, so this raises the
  /// bar rather than closing the door: it stops an open port being driven by
  /// anyone who finds it, and does not authenticate a *user*. Per-user auth
  /// needs a backend that issues credentials — see DEPLOYMENT.md.
  static const String rasaAuthToken = String.fromEnvironment('RASA_AUTH_TOKEN');

  static bool get hasRasaAuthToken => rasaAuthToken.isNotEmpty;

  /// Geoapify Places key, used for the nearby-hospital search.
  static const String placesApiKey = String.fromEnvironment('PLACES_API_KEY');

  /// Radius of the nearby-hospital search, in metres.
  static const int hospitalSearchRadiusMeters = int.fromEnvironment(
    'HOSPITAL_SEARCH_RADIUS_M',
    defaultValue: 5000,
  );

  /// Network timeout for backend calls.
  static const Duration requestTimeout = Duration(seconds: 30);

  static bool get hasPlacesApiKey => placesApiKey.isNotEmpty;

  /// True when the backend is reached over plain HTTP.
  static bool get usesCleartext => rasaBaseUrl.startsWith('http://');

  /// Startup check, so a misconfigured build fails visibly rather than at the
  /// moment the user taps "Emergency Help".
  static List<String> missingConfiguration() => [
    if (!hasPlacesApiKey)
      'PLACES_API_KEY is not set — nearby hospital search is unavailable. '
          'Pass --dart-define=PLACES_API_KEY=<key>.',
    if (!hasRasaAuthToken)
      'RASA_AUTH_TOKEN is not set — requests will be rejected by a backend '
          'started with --auth-token.',
  ];

  /// Configuration that is acceptable in development but must not ship.
  ///
  /// Checked at startup in release builds: symptom data over plain HTTP, or a
  /// build still pointing at a developer machine, is a shipping mistake worth
  /// catching before the store does.
  static List<String> releaseBlockers() => [
    if (usesCleartext)
      'RASA_BASE_URL uses http:// — health data would travel unencrypted. '
          'Use https:// for a released build.',
    if (rasaBaseUrl.contains('10.0.2.2') ||
        rasaBaseUrl.contains('localhost') ||
        rasaBaseUrl.contains('127.0.0.1'))
      'RASA_BASE_URL points at a local development machine.',
    if (!hasRasaAuthToken) 'RASA_AUTH_TOKEN is not set.',
  ];
}
