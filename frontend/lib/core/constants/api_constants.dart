/**
 * API Constants
 * 
 * Single Responsibility: Centralized API configuration
 */

class ApiConstants {
  static const String baseUrl = 'http://localhost:5000/api';
  
  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  
  // Court endpoints
  static const String verifiedCourts = '/courts/verified';
  static const String myCourtAsOwner = '/courtowner/my-court';
  static const String updateCourtRates = '/courtowner/update-rates';
  
  // Booking endpoints
  static const String bookCourt = '/booking/book-court';
  static const String bookingHistory = '/booking/booking-history';
  static const String markUnavailable = '/booking/mark-unavailable';
  
  // Challenge endpoints
  static const String createChallenge = '/challenges/create';
  static const String acceptChallenge = '/challenges/accept';
  static const String openChallenges = '/challenges/open';
  
  // Team endpoints
  static const String teamProfile = '/team/profile';
  static const String leaderboard = '/leaderboard/';
  
  // Helper method to build court booking endpoint
  static String courtBookings(String courtId, {int? courtNum}) {
    return courtNum != null
        ? '/booking/court/$courtId?courtNum=$courtNum'
        : '/booking/court/$courtId';
  }
  
  // Helper method to build court challenges endpoint
  static String courtChallenges(String courtId, {int? courtNum}) {
    return courtNum != null
        ? '/challenges/court/$courtId?courtNum=$courtNum'
        : '/challenges/court/$courtId';
  }
}

