import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/models/hospital.dart';
import 'package:health_bot_app/services/hospital_service.dart';

Map<String, dynamic> feature({
  String? name = 'City General Hospital',
  double lat = 12.97,
  double lon = 77.59,
  double? distance = 1200,
  String? phone,
  String? website,
  String? emergency,
  String formatted = '123 Main St',
}) {
  return {
    'properties': {
      'name': ?name,
      'lat': lat,
      'lon': lon,
      'distance': ?distance,
      'contact:phone': ?phone,
      'website': ?website,
      'emergency': ?emergency,
      'formatted': formatted,
    },
  };
}

void main() {
  group('parseFeatures', () {
    test('reads a well-formed feature', () {
      final hospitals = HospitalService.parseFeatures(
        [feature(phone: '555-0199', website: 'example.org', emergency: 'yes')],
        12.97,
        77.59,
      );
      expect(hospitals, hasLength(1));
      final h = hospitals.single;
      expect(h.name, 'City General Hospital');
      expect(h.rawDistance, 1200);
      expect(h.hasEmergency, isTrue);
      expect(h.hasPhone, isTrue);
      expect(h.hasWebsite, isTrue);
      expect(h.address, '123 Main St');
    });

    test('sorts nearest first', () {
      final hospitals = HospitalService.parseFeatures(
        [
          feature(name: 'Far', distance: 4100),
          feature(name: 'Near', distance: 800),
          feature(name: 'Middle', distance: 2200),
        ],
        12.97,
        77.59,
      );
      expect(hospitals.map((h) => h.name), ['Near', 'Middle', 'Far']);
    });

    test('skips features without coordinates', () {
      final broken = {
        'properties': {'name': 'No coords', 'distance': 100}
      };
      expect(HospitalService.parseFeatures([broken], 0, 0), isEmpty);
    });

    test('skips malformed entries instead of throwing', () {
      final hospitals = HospitalService.parseFeatures(
        ['not a map', {}, feature()],
        12.97,
        77.59,
      );
      expect(hospitals, hasLength(1));
    });

    test('names an unnamed facility', () {
      final hospitals = HospitalService.parseFeatures([feature(name: null)], 0, 0);
      expect(hospitals.single.name, 'Medical Centre');
    });

    test('an empty list yields no hospitals', () {
      expect(HospitalService.parseFeatures(const [], 0, 0), isEmpty);
    });
  });

  group('HospitalData', () {
    HospitalData at(double metres) => HospitalData(
          name: 'Test',
          rawDistance: metres,
          latitude: 0,
          longitude: 0,
        );

    test('formats distance in kilometres', () {
      expect(at(1200).distance, '1.2 km away');
      expect(at(450).distance, '0.5 km away');
    });

    test('never reports a zero-minute drive', () {
      expect(at(10).estimatedTimeMins, 1);
    });

    test('estimates drive time from distance', () {
      expect(at(15000).estimatedTimeMins, 30);
    });

    test('reports missing contact details', () {
      final h = at(1000);
      expect(h.hasPhone, isFalse);
      expect(h.hasWebsite, isFalse);
      expect(h.phoneLabel, 'N/A');
    });

    test('treats blank contact details as missing', () {
      final h = HospitalData(
        name: 'Test',
        rawDistance: 100,
        latitude: 0,
        longitude: 0,
        phone: '   ',
        website: '',
      );
      expect(h.hasPhone, isFalse);
      expect(h.hasWebsite, isFalse);
    });
  });
}
