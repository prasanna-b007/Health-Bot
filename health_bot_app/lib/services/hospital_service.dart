import 'dart:convert';
import 'package:http/http.dart' as http;

class HospitalService {
  Future<List<dynamic>> getNearbyHospitals(
      double latitude,
      double longitude,
      ) async {

    final query = '''
[out:json];
(
  node["amenity"="hospital"](around:5000,$latitude,$longitude);
  way["amenity"="hospital"](around:5000,$latitude,$longitude);
  relation["amenity"="hospital"](around:5000,$latitude,$longitude);
);
out center tags;
''';

    final response = await http.post(
      Uri.parse("https://overpass-api.de/api/interpreter"),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {
        "data": query,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["elements"];
    } else {
      throw Exception("Failed to load hospitals");
    }
  }
}