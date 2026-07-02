import 'dart:convert';
import 'package:http/http.dart' as http;

class HospitalService {
  Future<List<dynamic>> getNearbyHospitals(
      double latitude,
      double longitude,
      ) async {

    final url =
        "https://api.geoapify.com/v2/places?"
        "categories=healthcare.hospital"
        "&filter=circle:$longitude,$latitude,5000"
        "&bias=proximity:$longitude,$latitude"
        "&limit=10"
        "&apiKey=694a644c10a44b3e8d9c6c853b44256c";

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded["features"] == null) {
        throw Exception("No hospitals returned.");
      }

      return decoded["features"];
    } else {
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      throw Exception(
        "Hospital API Error: ${response.statusCode}\n${response.body}",
      );
    }
  }
}