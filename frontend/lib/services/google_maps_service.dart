import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';

/// Service to call Google Maps API through backend (secure)
class GoogleMapsService {
  /// Get authentication token
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      return null;
    }
  }

  /// Reverse geocoding - Get address from coordinates
  /// Calls: GET /api/google-maps/reverse-geocode?lat={lat}&lng={lng}
  static Future<Map<String, dynamic>?> getAddressFromCoords(
    double lat,
    double lng,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse(
        '${ApiConstants.baseUrl}/google-maps/reverse-geocode?lat=$lat&lng=$lng',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Places Autocomplete - Search for places
  /// Calls: GET /api/google-maps/places/autocomplete?query={query}&country={country}
  static Future<Map<String, dynamic>?> searchPlaces(
    String query, {
    String country = 'pk',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        '${ApiConstants.baseUrl}/google-maps/places/autocomplete?query=$encodedQuery&country=$country',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      print('Error searching places: $e');
      return null;
    }
  }

  /// Place Details - Get details for a specific place
  /// Calls: GET /api/google-maps/places/details?placeId={placeId}&fields={fields}
  static Future<Map<String, dynamic>?> getPlaceDetails(
    String placeId, {
    String fields = 'geometry',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final encodedPlaceId = Uri.encodeComponent(placeId);
      final url = Uri.parse(
        '${ApiConstants.baseUrl}/google-maps/places/details?placeId=$encodedPlaceId&fields=$fields',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }
}

