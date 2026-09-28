/// On-device emergency red-flag detection.
///
/// The real detector lives on the server, in `backend/actions/emergency.py`,
/// and it is better than this one: it also sees the symptoms confirmed during
/// the interview, and it knows the canonical dataset names. This is not a
/// replacement for it.
///
/// It exists because of what happened when the server could not be reached.
/// The app showed "could not reach the health server", and stopped — including
/// for someone who had just typed "crushing chest pain and can't breathe".
/// The one moment the app most needs to say something useful was the one
/// moment it said nothing.
///
/// So this runs only on the failure path, and only ever escalates: a hit sends
/// the user to emergency guidance, a miss leaves the original network error
/// exactly as it was. It cannot downgrade anything, and it never reassures —
/// no match means "we could not check", not "you are fine".
///
/// The phrase list is a deliberate subset of the server's `EMERGENCY_PHRASES`,
/// kept to unambiguous, high-specificity wording. A false positive here costs
/// someone an unnecessary look at an emergency screen; a false negative costs
/// much more, but a list broad enough to catch everything would fire on
/// ordinary text and train people to ignore it.
///
/// Crisis phrases are kept separate, for the same reason the server separates
/// them: a suicidal disclosure and a heart attack need opposite responses, and
/// they were previously in one list here — so with no network, "I want to end
/// my life" opened a map of emergency departments. Offline is exactly when
/// that matters most, because there is no server about to correct it.
library;

class RedFlags {
  const RedFlags._();

  /// Normalises the way `normalize()` does on the server: lowercase, drop
  /// apostrophes, collapse whitespace. Apostrophe removal is what makes
  /// "can't breathe" and "cant breathe" compare equal.
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r"[‘’'`]"), '')
      .replaceAll(RegExp(r'[_\-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Phrases that mean "stop and get emergency care".
  ///
  /// Mirrors the server list; keep the two in step when either changes.
  static const List<String> phrases = [
    // Cardiac
    'chest pain', 'severe chest pain', 'chest tightness', 'pain in chest',
    'chest hurts', 'crushing chest pressure', 'pressure in chest',
    'heart attack',
    // Respiratory
    'shortness of breath', 'difficulty breathing', 'cannot breathe',
    'cant breathe', 'hard to breathe', 'breathing difficulty', 'breathless',
    'choking', 'gasping for air',
    // Consciousness
    'unconscious', 'unconsciousness', 'fainted', 'not responding',
    'loss of consciousness', 'passed out', 'unresponsive',
    // Bleeding
    'severe bleeding', 'heavy bleeding', 'bleeding heavily', 'hemorrhage',
    'haemorrhage', 'coughing blood', 'vomiting blood', 'blood in vomit',
    // Stroke
    'stroke', 'face drooping', 'arm weakness', 'sudden numbness',
    'stroke symptoms', 'slurred speech', 'sudden weakness',
    'unilateral weakness',
    // Neurological
    'thunderclap headache', 'worst headache of life', 'seizure', 'convulsions',
    // Allergic
    'severe allergic reaction', 'anaphylaxis', 'throat swelling',
    'swollen throat', 'tongue swelling', 'throat is swelling',
    'throat is closing', 'tongue is swelling', 'cant swallow',
    // Poisoning
    'poisoning',
  ];

  /// Disclosures that call for a crisis line, never a hospital map.
  ///
  /// A deliberate subset of the server's `CRISIS_PHRASES`, again kept to
  /// unambiguous wording.
  static const List<String> crisisPhrases = [
    'suicidal',
    'suicide',
    'kill myself',
    'killing myself',
    'want to end my life',
    'end my life',
    'ending my life',
    'want to die',
    'dont want to live',
    'better off dead',
    'no reason to live',
    'harm myself',
    'hurt myself',
    'harming myself',
    'hurting myself',
    'self harm',
    'overdose',
    'overdosed',
    'took too many pills',
  ];

  /// The first medical red flag found in [text], or null.
  ///
  /// Substring matching on normalised text, like the server. It over-matches
  /// slightly — "chest pain" fires inside "no chest pain" — and that is the
  /// intended direction of error for an offline safety net. The server, which
  /// does handle negation, corrects it on the next reachable request.
  static String? findIn(String? text) => _firstOf(text, phrases);

  /// The first crisis disclosure found in [text], or null.
  ///
  /// Checked *before* [findIn] by callers: "I took an overdose and my chest
  /// hurts" belongs with a crisis line, not an ambulance.
  static String? findCrisisIn(String? text) => _firstOf(text, crisisPhrases);

  static String? _firstOf(String? text, List<String> candidates) {
    final haystack = normalize(text ?? '');
    if (haystack.isEmpty) return null;
    for (final phrase in candidates) {
      if (haystack.contains(phrase)) return phrase;
    }
    return null;
  }

  static bool has(String? text) => findIn(text) != null;

  static bool hasCrisis(String? text) => findCrisisIn(text) != null;

  /// Wording for the emergency screen when the offline check is what caught
  /// it. It is explicit that the server was unreachable, so the user
  /// understands this is a precaution rather than a completed assessment.
  static String reasonFor(String phrase) =>
      'You described "$phrase", which can be a medical emergency. '
      'The assessment server could not be reached, so this has not been '
      'fully checked — treat it as urgent.';
}
