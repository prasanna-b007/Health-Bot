/// A nearby medical facility.
///
/// This is the single hospital model for the app. It previously lived in
/// api_service.dart alongside a hardcoded list of invented hospitals, with an
/// unused `Hospital` class here as well.
class HospitalData {
  HospitalData({
    required this.name,
    required this.rawDistance,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.website,
    this.address = '',
    this.hasEmergency = false,
    this.type = 'General Hospital',
  });

  final String name;

  /// Straight-line distance from the user, in metres.
  final double rawDistance;

  final double latitude;
  final double longitude;
  final String? phone;
  final String? website;
  final String address;
  final bool hasEmergency;
  final String type;

  double get distanceKm => rawDistance / 1000;

  /// "1.2 km away", for display.
  String get distance => '${distanceKm.toStringAsFixed(1)} km away';

  /// Rough drive time assuming 30 km/h in traffic. Always at least a minute,
  /// so a very close facility does not render as "0 min".
  int get estimatedTimeMins {
    final minutes = (distanceKm / 30 * 60).round();
    return minutes < 1 ? 1 : minutes;
  }

  bool get hasPhone => (phone ?? '').trim().isNotEmpty;
  bool get hasWebsite => (website ?? '').trim().isNotEmpty;

  /// Display form for the phone number, for the "N/A" case the UI shows.
  String get phoneLabel => hasPhone ? phone!.trim() : 'N/A';
}
