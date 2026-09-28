import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/hospital.dart';

/// Nearby-hospital lookup against the Geoapify Places API.
///
/// This is the app's only hospital source. `ApiService` previously returned
/// three invented hospitals with fake phone numbers, and the Rasa action
/// server returned a third, different set of fakes; both are gone. The action
/// server now just signals that a search is warranted and the device — which
/// is the only party that knows where the user is — performs it.
class HospitalService {
  HospitalService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _host = 'api.geoapify.com';
  static const String _path = '/v2/places';

  /// Hospitals within [AppConfig.hospitalSearchRadiusMeters], nearest first.
  ///
  /// Throws [HospitalServiceException] with a message fit for display.
  Future<List<HospitalData>> getNearbyHospitals(
    double latitude,
    double longitude, {
    int? radiusMeters,
    int limit = 10,
  }) async {
    if (!AppConfig.hasPlacesApiKey) {
      throw const HospitalServiceException(
        'Hospital search is not configured on this build.',
        kind: HospitalErrorKind.notConfigured,
      );
    }

    final radius = radiusMeters ?? AppConfig.hospitalSearchRadiusMeters;
    final uri = Uri.https(_host, _path, {
      'categories': 'healthcare.hospital',
      'filter': 'circle:$longitude,$latitude,$radius',
      'bias': 'proximity:$longitude,$latitude',
      'limit': '$limit',
      'apiKey': AppConfig.placesApiKey,
    });

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(AppConfig.requestTimeout);
    } on SocketException catch (e) {
      throw HospitalServiceException(
        'No internet connection.',
        kind: HospitalErrorKind.network,
        cause: e,
      );
    } catch (e) {
      throw HospitalServiceException(
        'Could not reach the hospital directory.',
        kind: HospitalErrorKind.network,
        cause: e,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const HospitalServiceException(
        'Hospital search rejected the API key.',
        kind: HospitalErrorKind.notConfigured,
      );
    }
    if (response.statusCode != 200) {
      // The body can contain the key, so it is never surfaced to the user.
      debugPrint('Places API ${response.statusCode}: ${response.body}');
      throw HospitalServiceException(
        'Hospital directory returned an error (${response.statusCode}).',
        kind: HospitalErrorKind.server,
      );
    }

    final List<dynamic> features;
    try {
      final decoded = jsonDecode(response.body);
      features =
          (decoded is Map<String, dynamic> ? decoded['features'] : null)
              as List<dynamic>? ??
          const [];
    } catch (e) {
      throw HospitalServiceException(
        'Hospital directory sent an unreadable response.',
        kind: HospitalErrorKind.parse,
        cause: e,
      );
    }

    return parseFeatures(features, latitude, longitude);
  }

  /// Convert Geoapify features into [HospitalData], nearest first.
  ///
  /// Separated from the request so it can be tested without a network call.
  @visibleForTesting
  static List<HospitalData> parseFeatures(
    List<dynamic> features,
    double originLat,
    double originLon,
  ) {
    final hospitals = <HospitalData>[];
    for (final feature in features) {
      if (feature is! Map) continue;
      final properties = feature['properties'];
      if (properties is! Map) continue;

      final lat = (properties['lat'] as num?)?.toDouble();
      final lon = (properties['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final distanceMeters =
          (properties['distance'] as num?)?.toDouble() ??
          Geolocator.distanceBetween(originLat, originLon, lat, lon);

      hospitals.add(
        HospitalData(
          name: (properties['name'] as String?)?.trim().isNotEmpty == true
              ? properties['name'] as String
              : 'Medical Centre',
          rawDistance: distanceMeters,
          phone:
              (properties['contact:phone'] ?? properties['phone']) as String?,
          hasEmergency: properties['emergency'] == 'yes',
          website:
              (properties['website'] ?? properties['contact:website'])
                  as String?,
          latitude: lat,
          longitude: lon,
          address: (properties['formatted'] as String?) ?? '',
        ),
      );
    }
    hospitals.sort((a, b) => a.rawDistance.compareTo(b.rawDistance));
    return hospitals;
  }
}

enum HospitalErrorKind { network, server, parse, notConfigured }

class HospitalServiceException implements Exception {
  const HospitalServiceException(
    this.message, {
    required this.kind,
    this.cause,
  });

  final String message;
  final HospitalErrorKind kind;
  final Object? cause;

  @override
  String toString() => 'HospitalServiceException($kind): $message';
}
