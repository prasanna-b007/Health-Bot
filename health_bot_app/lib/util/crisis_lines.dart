import 'dart:ui' show Locale, PlatformDispatcher;

/// Where to point someone who has just disclosed suicidal thoughts or
/// self-harm.
///
/// This exists because the backend used to treat "I want to end my life" as a
/// medical emergency identical to chest pain, and the app answered it by
/// opening the nearest-hospital map. That is the wrong destination and the
/// wrong tone: it reads as being handed off, it asks the hardest possible
/// first step of someone least able to take it, and an emergency department
/// is not what crisis services are for.
///
/// A crisis line is. They are free, confidential, staffed around the clock by
/// people trained for exactly this call, and reachable without leaving the
/// room. So the app shows the line for the user's country, with the emergency
/// number kept as a clearly secondary option for immediate danger.
///
/// Resolution mirrors [EmergencyNumber]: the device locale, not GPS, because
/// a locale is available instantly and offline. The line is always shown with
/// its name and number in full, so a user who knows their local service can
/// see when the app has guessed wrong.
class CrisisLine {
  const CrisisLine({
    required this.name,
    required this.number,
    required this.countryCode,
    this.textOption = '',
    this.hours = 'Available 24/7',
  });

  /// The service's name, shown to the user. Naming it matters -- "988 Suicide
  /// and Crisis Lifeline" tells someone what they are about to reach in a way
  /// that a bare number does not.
  final String name;

  /// The digits to dial.
  final String number;

  /// ISO-3166 alpha-2 this line was chosen for. Empty when unknown.
  final String countryCode;

  /// A text or chat alternative, where one exists. Some people will send a
  /// message when they would not make a call, and for this particular
  /// disclosure that difference decides whether they reach anyone at all.
  final String textOption;

  /// When the service is staffed.
  final String hours;

  /// Used when the country is unknown.
  ///
  /// Deliberately not a number. There is no global crisis line, and inventing
  /// one would send someone in distress to a dead tone at the worst possible
  /// moment. An honest "we do not know yours, here is how to find it" is
  /// better than a confident wrong number.
  static const CrisisLine unknown = CrisisLine(
    name: 'Find a crisis line near you',
    number: '',
    countryCode: '',
    hours: 'findahelpline.com lists services by country',
  );

  /// True when an actual local service was matched.
  bool get isKnown => number.isNotEmpty;

  /// True when the service can be reached by text or chat as well as by call.
  bool get hasTextOption => textOption.isNotEmpty;

  /// Crisis lines by ISO-3166 alpha-2.
  ///
  /// Numbers are the national service each country points its own population
  /// at. Where a country has several, the one chosen is the national,
  /// round-the-clock, general-population line, since this app knows nothing
  /// about the caller beyond their locale.
  static const Map<String, CrisisLine> byCountry = {
    'US': CrisisLine(
      name: '988 Suicide & Crisis Lifeline',
      number: '988',
      countryCode: 'US',
      textOption: 'Text 988',
    ),
    'CA': CrisisLine(
      name: '9-8-8 Suicide Crisis Helpline',
      number: '988',
      countryCode: 'CA',
      textOption: 'Text 988',
    ),
    'GB': CrisisLine(
      name: 'Samaritans',
      number: '116123',
      countryCode: 'GB',
      textOption: 'Text SHOUT to 85258',
    ),
    'IE': CrisisLine(
      name: 'Samaritans Ireland',
      number: '116123',
      countryCode: 'IE',
      textOption: 'Text HELLO to 50808',
    ),
    'IN': CrisisLine(
      name: 'Tele-MANAS',
      number: '14416',
      countryCode: 'IN',
      hours: 'Available 24/7, in multiple languages',
    ),
    'AU': CrisisLine(
      name: 'Lifeline Australia',
      number: '131114',
      countryCode: 'AU',
      textOption: 'Text 0477 13 11 14',
    ),
    'NZ': CrisisLine(
      name: '1737 Need to Talk?',
      number: '1737',
      countryCode: 'NZ',
      textOption: 'Text 1737',
    ),
    'ZA': CrisisLine(
      name: 'SADAG Suicide Crisis Line',
      number: '0800567567',
      countryCode: 'ZA',
    ),
    'SG': CrisisLine(
      name: 'Samaritans of Singapore',
      number: '1767',
      countryCode: 'SG',
    ),
    'MY': CrisisLine(
      name: 'Befrienders KL',
      number: '0376272929',
      countryCode: 'MY',
    ),
    'PH': CrisisLine(
      name: 'NCMH Crisis Hotline',
      number: '1553',
      countryCode: 'PH',
    ),
    'JP': CrisisLine(
      name: 'Yorisoi Hotline',
      number: '0120279338',
      countryCode: 'JP',
    ),
    'KR': CrisisLine(
      name: 'Suicide Prevention Hotline',
      number: '109',
      countryCode: 'KR',
    ),
    'HK': CrisisLine(
      name: 'Suicide Prevention Services',
      number: '28960000',
      countryCode: 'HK',
    ),
    'DE': CrisisLine(
      name: 'Telefonseelsorge',
      number: '08001110111',
      countryCode: 'DE',
    ),
    'FR': CrisisLine(
      name: '3114 – Numéro national',
      number: '3114',
      countryCode: 'FR',
    ),
    'ES': CrisisLine(name: 'Línea 024', number: '024', countryCode: 'ES'),
    'IT': CrisisLine(
      name: 'Telefono Amico',
      number: '023272327',
      countryCode: 'IT',
    ),
    'NL': CrisisLine(
      name: '113 Zelfmoordpreventie',
      number: '08000113',
      countryCode: 'NL',
    ),
    'BE': CrisisLine(
      name: 'Zelfmoordlijn 1813',
      number: '1813',
      countryCode: 'BE',
    ),
    'SE': CrisisLine(
      name: 'Mind Självmordslinjen',
      number: '90101',
      countryCode: 'SE',
    ),
    'NO': CrisisLine(name: 'Mental Helse', number: '116123', countryCode: 'NO'),
    'DK': CrisisLine(name: 'Livslinien', number: '70201201', countryCode: 'DK'),
    'FI': CrisisLine(
      name: 'MIELI Kriisipuhelin',
      number: '0925250111',
      countryCode: 'FI',
    ),
    'PL': CrisisLine(
      name: 'Centrum Wsparcia',
      number: '800702222',
      countryCode: 'PL',
    ),
    'PT': CrisisLine(name: 'SNS 24', number: '808242424', countryCode: 'PT'),
    'AT': CrisisLine(
      name: 'Telefonseelsorge',
      number: '142',
      countryCode: 'AT',
    ),
    'CH': CrisisLine(
      name: 'Die Dargebotene Hand',
      number: '143',
      countryCode: 'CH',
    ),
    'BR': CrisisLine(name: 'CVV', number: '188', countryCode: 'BR'),
    'AR': CrisisLine(
      name: 'Salud Mental Responde',
      number: '135',
      countryCode: 'AR',
    ),
    'MX': CrisisLine(
      name: 'Línea de la Vida',
      number: '8009112000',
      countryCode: 'MX',
    ),
    'AE': CrisisLine(name: 'Estijaba', number: '8001717', countryCode: 'AE'),
    'IL': CrisisLine(name: 'ERAN', number: '1201', countryCode: 'IL'),
  };

  /// The line for [countryCode], or [unknown].
  static CrisisLine forCountry(String? countryCode) {
    final code = (countryCode ?? '').trim().toUpperCase();
    return byCountry[code] ?? unknown;
  }

  /// The best guess for this device, from the platform locales.
  static CrisisLine resolve({List<Locale>? locales}) {
    final candidates = locales ?? PlatformDispatcher.instance.locales;
    for (final locale in candidates) {
      final code = locale.countryCode;
      if (code != null && byCountry.containsKey(code.toUpperCase())) {
        return forCountry(code);
      }
    }
    return unknown;
  }
}
