/**
 * Challenge Repository - Data access layer for challenges
 * 
 * SOLID Principles:
 * 1. Single Responsibility: Handles only challenge data access
 * 2. Dependency Inversion: Depends on ApiService abstraction
 * 
 * Repository Pattern: Separates data access from business logic
 */

import '../models/challenge_model.dart';
import '../services/api_service.dart';

class ChallengeRepository {
  final ApiService _apiService;

  ChallengeRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Fetch challenges for a specific court
  Future<List<ChallengeModel>> getChallengesByCourtId(
    String courtId, {
    int? courtNum,
  }) async {
    try {
      final endpoint = courtNum != null
          ? '/challenges/court/$courtId?courtNum=$courtNum'
          : '/challenges/court/$courtId';
      
      final response = await _apiService.get(endpoint);
      final challenges = (response['data']['challenges'] as List)
          .map((json) => ChallengeModel.fromJson(json))
          .toList();
      return challenges;
    } catch (e) {
      throw Exception('Failed to fetch challenges: $e');
    }
  }

  /// Create a new challenge
  Future<ChallengeModel> createChallenge({
    required String courtId,
    required int courtNum,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final response = await _apiService.post('/challenges/create', {
        'courtID': courtId,
        'courtNum': courtNum,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      });
      return ChallengeModel.fromJson(response['data']['challenge']);
    } catch (e) {
      throw Exception('Failed to create challenge: $e');
    }
  }

  /// Accept a challenge
  Future<void> acceptChallenge(String challengeId) async {
    try {
      await _apiService.post('/challenges/accept', {
        'challengeId': challengeId,
      });
    } catch (e) {
      throw Exception('Failed to accept challenge: $e');
    }
  }

  /// Fetch all open challenges
  Future<List<ChallengeModel>> getOpenChallenges() async {
    try {
      final response = await _apiService.get('/challenges/open');
      final challenges = (response['data']['challenges'] as List)
          .map((json) => ChallengeModel.fromJson(json))
          .toList();
      return challenges;
    } catch (e) {
      throw Exception('Failed to fetch open challenges: $e');
    }
  }
}

