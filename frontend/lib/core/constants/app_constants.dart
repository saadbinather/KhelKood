/// Application-wide constants
/// Implements Single Responsibility Principle - manages only constants
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // API Configuration
  static const String baseUrl = 'http://localhost:5000/api';
  
  // API Endpoints
  static const String courtsEndpoint = '/courts/verified';
  static const String leaderboardEndpoint = '/leaderboard';
  static const String teamDetailsEndpoint = '/teams/details';
  static const String updateTeamEndpoint = '/teams/update';
  static const String bookingsEndpoint = '/bookings';
  static const String challengesEndpoint = '/challenges';
  
  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String teamIdKey = 'team_id';
  
  // UI Constants
  static const double smallScreenWidth = 360.0;
  static const double tabletScreenWidth = 600.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 12.0;
  static const double largePadding = 24.0;
  
  // Time Constants
  static const int apiTimeout = 30; // seconds
  static const int cacheExpiry = 300; // seconds
}

