import '../models/challenge_model.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

/// Repository interface for challenge data operations
/// Implements Dependency Inversion Principle - depend on abstractions
abstract class IChallengeRepository {
  Future<Map<String, List<ChallengeModel>>> getOpenChallenges();
  Future<List<ChallengeModel>> getIncomingChallenges();
  Future<List<ChallengeModel>> getOutgoingChallenges();
  Future<ChallengeModel?> createChallenge(Map<String, dynamic> challengeData);
  Future<bool> acceptChallenge(String challengeId);
  Future<bool> declineChallenge(String challengeId);
  Future<bool> cancelChallenge(String challengeId);
  Future<ChallengeModel?> getChallengeById(String challengeId);
}

/// Challenge repository implementation
/// Implements Single Responsibility - only handles challenge data operations
class ChallengeRepository implements IChallengeRepository {
  final ApiService _apiService;

  // Dependency injection through constructor
  ChallengeRepository(this._apiService);

  @override
  Future<Map<String, List<ChallengeModel>>> getOpenChallenges() async {
    try {
      final response = await _apiService.get('${AppConstants.challengesEndpoint}/open');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        
        final incomingData = data['data']?['incoming'] ?? data['incoming'] ?? [];
        final outgoingData = data['data']?['outgoing'] ?? data['outgoing'] ?? [];
        
        final incoming = (incomingData as List)
            .map((json) => ChallengeModel.fromJson(json as Map<String, dynamic>))
            .toList();
        
        final outgoing = (outgoingData as List)
            .map((json) => ChallengeModel.fromJson(json as Map<String, dynamic>))
            .toList();
        
        return {
          'incoming': incoming,
          'outgoing': outgoing,
        };
      }
      
      return {'incoming': [], 'outgoing': []};
    } catch (e) {
      print('Error fetching open challenges: $e');
      return {'incoming': [], 'outgoing': []};
    }
  }

  @override
  Future<List<ChallengeModel>> getIncomingChallenges() async {
    try {
      final response = await _apiService.get('${AppConstants.challengesEndpoint}/incoming');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final challengesData = data['data']?['challenges'] ?? 
                              data['challenges'] ?? 
                              data['data'] ?? 
                              [];
        
        if (challengesData is List) {
          return challengesData
              .map((json) => ChallengeModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching incoming challenges: $e');
      return [];
    }
  }

  @override
  Future<List<ChallengeModel>> getOutgoingChallenges() async {
    try {
      final response = await _apiService.get('${AppConstants.challengesEndpoint}/outgoing');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final challengesData = data['data']?['challenges'] ?? data['challenges'] ?? [];
        
        if (challengesData is List) {
          return challengesData
              .map((json) => ChallengeModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching outgoing challenges: $e');
      return [];
    }
  }

  @override
  Future<ChallengeModel?> createChallenge(Map<String, dynamic> challengeData) async {
    try {
      final response = await _apiService.post(
        AppConstants.challengesEndpoint,
        challengeData,
      );
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final challengeResult = data['data']?['challenge'] ?? data['challenge'] ?? data;
        
        if (challengeResult != null && challengeResult is Map<String, dynamic>) {
          return ChallengeModel.fromJson(challengeResult);
        }
      }
      
      return null;
    } catch (e) {
      print('Error creating challenge: $e');
      return null;
    }
  }

  @override
  Future<bool> acceptChallenge(String challengeId) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.challengesEndpoint}/$challengeId/accept',
        {},
      );
      return _apiService.isSuccessful(response);
    } catch (e) {
      print('Error accepting challenge: $e');
      return false;
    }
  }

  @override
  Future<bool> declineChallenge(String challengeId) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.challengesEndpoint}/$challengeId/decline',
        {},
      );
      return _apiService.isSuccessful(response);
    } catch (e) {
      print('Error declining challenge: $e');
      return false;
    }
  }

  @override
  Future<bool> cancelChallenge(String challengeId) async {
    try {
      final response = await _apiService.delete(
        '${AppConstants.challengesEndpoint}/$challengeId',
      );
      return _apiService.isSuccessful(response);
    } catch (e) {
      print('Error cancelling challenge: $e');
      return false;
    }
  }

  @override
  Future<ChallengeModel?> getChallengeById(String challengeId) async {
    try {
      final response = await _apiService.get(
        '${AppConstants.challengesEndpoint}/$challengeId',
      );
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final challengeData = data['data']?['challenge'] ?? data['challenge'] ?? data;
        
        if (challengeData != null && challengeData is Map<String, dynamic>) {
          return ChallengeModel.fromJson(challengeData);
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching challenge by ID: $e');
      return null;
    }
  }
}

