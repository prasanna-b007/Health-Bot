import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/config/app_config.dart';

/// `String.fromEnvironment` is resolved at compile time, so these run against
/// whatever `--dart-define`s the test invocation carries. `flutter test` with
/// no defines gives the unconfigured development defaults, which is exactly
/// the state the guards exist to catch.
void main() {
  group('defaults', () {
    test('the backend URL is usable out of the box', () {
      expect(AppConfig.rasaBaseUrl, startsWith('http'));
    });

    test('no API key or token is compiled in by default', () {
      // Regression: a Geoapify key used to be hardcoded in the source.
      expect(AppConfig.placesApiKey, isEmpty);
      expect(AppConfig.rasaAuthToken, isEmpty);
      expect(AppConfig.hasPlacesApiKey, isFalse);
      expect(AppConfig.hasRasaAuthToken, isFalse);
    });

    test('the hospital search radius has a sensible default', () {
      expect(AppConfig.hospitalSearchRadiusMeters, greaterThan(0));
    });

    test('a request timeout is set', () {
      expect(AppConfig.requestTimeout.inSeconds, greaterThan(0));
    });
  });

  group('missingConfiguration', () {
    test('names each unset value', () {
      final warnings = AppConfig.missingConfiguration();
      expect(warnings.any((w) => w.contains('PLACES_API_KEY')), isTrue);
      expect(warnings.any((w) => w.contains('RASA_AUTH_TOKEN')), isTrue);
    });

    test('warnings explain what to do', () {
      for (final warning in AppConfig.missingConfiguration()) {
        expect(warning.length, greaterThan(20));
      }
    });
  });

  group('releaseBlockers', () {
    test('an unconfigured build is not shippable', () {
      // The default points at the Android emulator over plain HTTP.
      expect(AppConfig.releaseBlockers(), isNotEmpty);
    });

    test('cleartext transport is flagged', () {
      if (AppConfig.usesCleartext) {
        expect(
          AppConfig.releaseBlockers().any((b) => b.contains('http://')),
          isTrue,
          reason: 'symptom data over cleartext must block a release build',
        );
      }
    });

    test('a development address is flagged', () {
      final url = AppConfig.rasaBaseUrl;
      final isLocal = url.contains('10.0.2.2') ||
          url.contains('localhost') ||
          url.contains('127.0.0.1');
      if (isLocal) {
        expect(
          AppConfig.releaseBlockers()
              .any((b) => b.contains('local development machine')),
          isTrue,
        );
      }
    });

    test('a missing auth token is flagged', () {
      if (!AppConfig.hasRasaAuthToken) {
        expect(
          AppConfig.releaseBlockers().any((b) => b.contains('RASA_AUTH_TOKEN')),
          isTrue,
        );
      }
    });

    test('usesCleartext tracks the scheme', () {
      expect(AppConfig.usesCleartext, AppConfig.rasaBaseUrl.startsWith('http://'));
    });
  });
}
