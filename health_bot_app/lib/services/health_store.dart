import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assessment_record.dart';
import '../models/health_profile.dart';

/// On-device store for the user's profile and assessment history.
///
/// The store itself never uploads anything, and assessment history in
/// particular never leaves the device. The one exception lives elsewhere: when
/// the user runs an assessment, the screen doing it sends their age and
/// ongoing conditions along with the symptoms, because the risk engine scores
/// on them. Symptom history is among the most
/// sensitive data a person can hold, and the app has no account system to
/// protect it with, so there is nowhere to sync it to that would be safer than
/// the device itself.
///
/// It is a [ChangeNotifier] singleton read through `ListenableBuilder` rather
/// than an injected dependency: there is exactly one user and one store, and
/// threading a provider through eight screens to say so would be ceremony.
///
/// Reads are served from memory after [load]; writes update memory first and
/// persist after, so the UI never waits on disk to redraw.
class HealthStore extends ChangeNotifier {
  HealthStore._();

  static final HealthStore instance = HealthStore._();

  static const _profileKey = 'health_profile_v1';
  static const _historyKey = 'assessment_history_v1';

  /// Most recent first. Older entries beyond this are dropped — the timeline
  /// is a memory aid, not an archive, and an unbounded list in a single
  /// preferences string eventually becomes a slow read on every launch.
  static const int maxHistory = 40;

  SharedPreferences? _prefs;
  bool _loaded = false;

  HealthProfile _profile = HealthProfile.empty;
  List<AssessmentRecord> _history = const [];

  HealthProfile get profile => _profile;

  /// Newest first.
  List<AssessmentRecord> get history => List.unmodifiable(_history);

  bool get isLoaded => _loaded;

  AssessmentRecord? get latest => _history.isEmpty ? null : _history.first;

  /// Reads both records into memory. Safe to call more than once.
  ///
  /// A failure here is deliberately swallowed: storage being unavailable means
  /// the app forgets things, which is a degraded experience, not a reason to
  /// block someone from checking their symptoms.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _profile = HealthProfile.decode(prefs.getString(_profileKey));
      _history = _sorted(
        AssessmentRecord.decodeList(prefs.getString(_historyKey)),
      );
    } catch (e) {
      debugPrint('HealthStore: could not load local data ($e)');
      _profile = HealthProfile.empty;
      _history = const [];
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> saveProfile(HealthProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _write(_profileKey, profile.encode());
  }

  Future<void> clearProfile() => saveProfile(HealthProfile.empty);

  /// Appends a finished assessment to the timeline.
  Future<void> addRecord(AssessmentRecord record) async {
    _history = _sorted([record, ..._history]).take(maxHistory).toList();
    notifyListeners();
    await _write(_historyKey, AssessmentRecord.encodeList(_history));
  }

  Future<void> deleteRecord(String id) async {
    _history = _history.where((r) => r.id != id).toList();
    notifyListeners();
    await _write(_historyKey, AssessmentRecord.encodeList(_history));
  }

  Future<void> clearHistory() async {
    _history = const [];
    notifyListeners();
    await _write(_historyKey, AssessmentRecord.encodeList(const []));
  }

  /// Drops everything held in memory and forces the next [load] to re-read
  /// storage. The store is a singleton, so without this one test's writes
  /// would leak into the next test's expectations.
  @visibleForTesting
  Future<void> reset() async {
    _prefs = null;
    _loaded = false;
    _profile = HealthProfile.empty;
    _history = const [];
    await load();
  }

  static List<AssessmentRecord> _sorted(List<AssessmentRecord> records) {
    final copy = [...records]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return copy;
  }

  Future<void> _write(String key, String value) async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      // In-memory state is already updated, so the current session behaves
      // correctly; only persistence across launches is lost.
      debugPrint('HealthStore: could not persist "$key" ($e)');
    }
  }
}
