/**
 * Court Repository - Data access layer for courts
 * 
 * SOLID Principles:
 * 1. Single Responsibility: Handles only court data access
 * 2. Dependency Inversion: Depends on ApiService abstraction
 * 
 * Repository Pattern: Separates data access from business logic
 */

import '../models/court_model.dart';
import '../services/api_service.dart';

class CourtRepository {
  final ApiService _apiService;

  CourtRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Fetch all verified courts
  Future<List<CourtModel>> getVerifiedCourts() async {
    try {
      final response = await _apiService.get('/courts/verified');
      final courts = (response['data']['courts'] as List)
          .map((json) => CourtModel.fromJson(json))
          .toList();
      return courts;
    } catch (e) {
      throw Exception('Failed to fetch verified courts: $e');
    }
  }

  /// Fetch courts filtered by sport
  Future<List<CourtModel>> getCourtsBySport(String sport) async {
    try {
      final courts = await getVerifiedCourts();
      return courts.where((court) {
        return court.getCourtsForSport(sport) > 0;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch courts by sport: $e');
    }
  }

  /// Fetch court owner's court
  Future<CourtModel> getMyCourtAsOwner() async {
    try {
      final response = await _apiService.get('/courtowner/my-court');
      return CourtModel.fromJson(response['data']['court']);
    } catch (e) {
      throw Exception('Failed to fetch owner court: $e');
    }
  }

  /// Update court rates
  Future<CourtModel> updateCourtRates({
    required String courtId,
    required int cricketRate,
    required int futsalRate,
    required int padelRate,
  }) async {
    try {
      final response = await _apiService.put('/courtowner/update-rates', {
        'courtId': courtId,
        'cricketRate': cricketRate,
        'futsalRate': futsalRate,
        'padelRate': padelRate,
      });
      return CourtModel.fromJson(response['data']['court']);
    } catch (e) {
      throw Exception('Failed to update court rates: $e');
    }
  }
}

