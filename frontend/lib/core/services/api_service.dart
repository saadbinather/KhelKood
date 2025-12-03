import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'storage_service.dart';

/// API service for making HTTP requests
/// Implements Single Responsibility Principle - only handles API communication
class ApiService {
  final StorageService _storageService;
  
  // Dependency Injection through constructor
  ApiService(this._storageService);

  // Private method to get headers with authentication
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storageService.getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET request
  Future<http.Response> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
      
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(Duration(seconds: AppConstants.apiTimeout));
      
      return response;
    } catch (e) {
      print('GET request error for $endpoint: $e');
      rethrow;
    }
  }

  // POST request
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(Duration(seconds: AppConstants.apiTimeout));
      
      return response;
    } catch (e) {
      print('POST request error for $endpoint: $e');
      rethrow;
    }
  }

  // PUT request
  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
      
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(Duration(seconds: AppConstants.apiTimeout));
      
      return response;
    } catch (e) {
      print('PUT request error for $endpoint: $e');
      rethrow;
    }
  }

  // DELETE request
  Future<http.Response> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
      
      final response = await http.delete(
        url,
        headers: headers,
      ).timeout(Duration(seconds: AppConstants.apiTimeout));
      
      return response;
    } catch (e) {
      print('DELETE request error for $endpoint: $e');
      rethrow;
    }
  }

  // PATCH request
  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
      
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(Duration(seconds: AppConstants.apiTimeout));
      
      return response;
    } catch (e) {
      print('PATCH request error for $endpoint: $e');
      rethrow;
    }
  }

  // Helper method to check if response is successful
  bool isSuccessful(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  // Helper method to parse response body
  Map<String, dynamic> parseResponse(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing response: $e');
      return {};
    }
  }
}

