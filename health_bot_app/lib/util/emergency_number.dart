import 'dart:ui' show Locale, PlatformDispatcher;

/// Which number the "call emergency services" button actually dials.
///
/// This used to be hardcoded to `112`. That is correct across the EU and India
/// and is routed by GSM networks in many other places, but it is simply wrong
/// in the United States, the UK, Australia, Japan and much of Asia and Latin
/// America — so the app's single most safety-critical button dialled nothing
/// for a large share of the people who might press it.
///
/// Where a country runs a distinct **medical/ambulance** line alongside a
/// general emergency line, the medical one is chosen: this is a health app, and
/// the caller wants an ambulance.
///
/// The resolved number is always shown on the button. A user who knows their
/// local number can then see at a glance that the app has it wrong, which
/// matters more than any guess this table makes.
class EmergencyNumber {
  const EmergencyNumber({required this.number, required this.countryCode});

  /// The digits to dial.
  final String number;

  /// ISO-3166 alpha-2 the number was chosen for. Empty when unknown.
  final String countryCode;

  /// The fallback.
  ///
  /// 112 is the GSM standard: handsets route it to local emergency services in
  /// most networks worldwide, including ones whose "official" number differs.
  /// It is the safest thing to dial when the country is genuinely unknown.
  static const EmergencyNumber fallback = EmergencyNumber(
    number: '112',
    countryCode: '',
  );

  /// True when this came from an actual country match rather than the default.
  bool get isKnownCountry => countryCode.isNotEmpty;

  /// Medical/ambulance emergency numbers by ISO-3166 alpha-2.
  ///
  /// Countries not listed fall through to [fallback]. The whole EEA plus the
  /// UK's parallel 112 support means most of Europe is deliberately absent —
  /// 112 is already correct there.
  static const Map<String, String> byCountry = {
    // Americas
    'US': '108', 'CA': '108', 'MX': '108', 'PA': '108', 'DO': '108',
    'AR': '107', // SAME
    'BR': '192', // SAMU
    'CL': '131', // SAMU
    'CO': '123',
    'PE': '106',
    'UY': '108', 'EC': '108', 'CR': '108', 'GT': '110', 'BO': '118',
    // Europe outside the 112 default
    'GB': '999', 'IE': '999', 'RU': '103', 'UA': '103', 'BY': '103',
    'RS': '194', 'MD': '112',
    // Asia-Pacific
    'AU': '000', 'NZ': '111',
    'JP': '119', // fire + ambulance
    'KR': '119', 'TW': '119', 'HK': '999', 'MO': '999',
    'CN': '120', // ambulance
    'SG': '995', 'MY': '999', 'BN': '991',
    'TH': '1669', // Narenthorn EMS
    'ID': '119', 'PH': '108', 'VN': '115',
    'IN': '108', // unified emergency; 108 also reaches ambulances
    'PK': '1122', 'BD': '999', 'LK': '1990', 'NP': '102', 'BT': '112',
    'MM': '192', 'KH': '119', 'LA': '195', 'MN': '103',
    // Middle East
    'IL': '101', 'AE': '998', 'SA': '997', 'QA': '999', 'KW': '112',
    'BH': '999', 'OM': '9999', 'JO': '108', 'LB': '140', 'IQ': '122',
    'IR': '115', 'TR': '112',
    // Africa
    'ZA': '10177', 'EG': '123', 'NG': '112', 'KE': '999', 'GH': '193',
    'TZ': '114', 'UG': '112', 'ET': '907', 'MA': '150', 'DZ': '14',
    'TN': '190', 'ZW': '994', 'ZM': '991', 'RW': '912',
  };

  /// The number for [countryCode], or [fallback] when it is unknown.
  static EmergencyNumber forCountry(String? countryCode) {
    final code = (countryCode ?? '').trim().toUpperCase();
    final number = byCountry[code];
    if (number == null) return fallback;
    return EmergencyNumber(number: number, countryCode: code);
  }

  /// The best guess for this device.
  ///
  /// Resolved from the platform locales rather than from GPS. That is a
  /// deliberate trade: a locale is available instantly and offline, which is
  /// when this button matters, whereas a reverse geocode needs the network and
  /// a round trip. It is wrong for a traveller whose phone is still set to
  /// their home region — which is exactly why the number is printed on the
  /// button rather than hidden behind the word "emergency".
  static EmergencyNumber resolve({List<Locale>? locales}) {
    final candidates = locales ?? PlatformDispatcher.instance.locales;
    for (final locale in candidates) {
      final code = locale.countryCode;
      if (code != null && byCountry.containsKey(code.toUpperCase())) {
        return forCountry(code);
      }
    }
    return fallback;
  }
}
