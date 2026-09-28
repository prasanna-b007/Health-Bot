import 'package:geolocator/geolocator.dart';

/// Device location, with the permission dance in one place.
///
/// Returns a typed failure instead of `Future.error(String)` so callers can
/// tell "GPS is off" from "permission denied forever" and offer the right
/// remedy. HospitalFinderScreen previously inlined its own copy of this logic.
class LocationService {
  Future<Position> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Location services are turned off. Please enable them to find nearby hospitals.',
        kind: LocationErrorKind.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission is needed to find hospitals near you.',
        kind: LocationErrorKind.denied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Enable it in system settings to find nearby hospitals.',
        kind: LocationErrorKind.deniedForever,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      throw LocationException(
        'Could not determine your location. Please try again.',
        kind: LocationErrorKind.unavailable,
        cause: e,
      );
    }
  }

  /// Opens the OS settings page so the user can grant a denied permission.
  Future<bool> openSettings() => Geolocator.openAppSettings();
}

enum LocationErrorKind { serviceDisabled, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.message, {required this.kind, this.cause});

  final String message;
  final LocationErrorKind kind;
  final Object? cause;

  /// Whether the remedy is a trip to system settings.
  bool get needsSettings => kind == LocationErrorKind.deniedForever;

  @override
  String toString() => 'LocationException($kind): $message';
}
