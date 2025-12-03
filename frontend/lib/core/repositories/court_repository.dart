import '../models/court_model.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

/// Repository interface for court data operations
/// Implements Dependency Inversion Principle - depend on abstractions
abstract class ICourtRepository {
  Future<List<CourtModel>> getVerifiedCourts();
  Future<CourtModel?> getCourtById(String courtId);
  Future<List<CourtModel>> searchCourts({String? city, String? sport});
}

/// Court repository implementation
/// Implements Single Responsibility - only handles court data operations
class CourtRepository implements ICourtRepository {
  final ApiService _apiService;

  // Dependency injection through constructor
  CourtRepository(this._apiService);

  @override
  Future<List<CourtModel>> getVerifiedCourts() async {
    try {
      final response = await _apiService.get(AppConstants.courtsEndpoint);
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        
        // Handle different response structures
        final courtsData = data['data']?['courts'] ?? 
                          data['courts'] ?? 
                          data['data'] ?? 
                          [];
        
        if (courtsData is List) {
          return courtsData
              .map((courtJson) => CourtModel.fromJson(courtJson as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching verified courts: $e');
      return [];
    }
  }

  @override
  Future<CourtModel?> getCourtById(String courtId) async {
    try {
      final response = await _apiService.get('/courts/$courtId');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final courtData = data['data']?['court'] ?? data['court'] ?? data;
        
        if (courtData != null && courtData is Map<String, dynamic>) {
          return CourtModel.fromJson(courtData);
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching court by ID: $e');
      return null;
    }
  }

  @override
  Future<List<CourtModel>> searchCourts({String? city, String? sport}) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (city != null) queryParams['city'] = city;
      if (sport != null) queryParams['sport'] = sport;
      
      final queryString = queryParams.isEmpty 
          ? '' 
          : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      
      final response = await _apiService.get('/courts/search$queryString');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final courtsData = data['data']?['courts'] ?? data['courts'] ?? [];
        
        if (courtsData is List) {
          return courtsData
              .map((courtJson) => CourtModel.fromJson(courtJson as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error searching courts: $e');
      return [];
    }
  }
}

