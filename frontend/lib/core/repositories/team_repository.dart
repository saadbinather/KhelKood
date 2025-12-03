import '../models/team_model.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

/// Repository interface for team data operations
/// Implements Dependency Inversion Principle - depend on abstractions
abstract class ITeamRepository {
  Future<TeamModel?> getTeamDetails();
  Future<List<TeamModel>> getTopTeams({int limit = 10});
  Future<bool> updateTeam(String teamId, Map<String, dynamic> updates);
  Future<TeamModel?> getTeamById(String teamId);
}

/// Team repository implementation
/// Implements Single Responsibility - only handles team data operations
class TeamRepository implements ITeamRepository {
  final ApiService _apiService;

  // Dependency injection through constructor
  TeamRepository(this._apiService);

  @override
  Future<TeamModel?> getTeamDetails() async {
    try {
      final response = await _apiService.get(AppConstants.teamDetailsEndpoint);
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        
        // Handle different response structures
        final teamData = data['data']?['team'] ?? data['team'] ?? data;
        
        if (teamData != null && teamData is Map<String, dynamic>) {
          return TeamModel.fromJson(teamData);
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching team details: $e');
      return null;
    }
  }

  @override
  Future<List<TeamModel>> getTopTeams({int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '${AppConstants.leaderboardEndpoint}?limit=$limit'
      );
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        
        // Handle different response structures
        final teamsData = data['data']?['teams'] ?? 
                         data['teams'] ?? 
                         data['data'] ?? 
                         [];
        
        if (teamsData is List) {
          return teamsData
              .map((teamJson) => TeamModel.fromJson(teamJson as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching top teams: $e');
      return [];
    }
  }

  @override
  Future<bool> updateTeam(String teamId, Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.put(
        AppConstants.updateTeamEndpoint,
        updates,
      );
      
      return _apiService.isSuccessful(response);
    } catch (e) {
      print('Error updating team: $e');
      return false;
    }
  }

  @override
  Future<TeamModel?> getTeamById(String teamId) async {
    try {
      final response = await _apiService.get('/teams/$teamId');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final teamData = data['data']?['team'] ?? data['team'] ?? data;
        
        if (teamData != null && teamData is Map<String, dynamic>) {
          return TeamModel.fromJson(teamData);
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching team by ID: $e');
      return null;
    }
  }
}

