/**
 * Booking Repository - Data access layer for bookings
 * 
 * SOLID Principles:
 * 1. Single Responsibility: Handles only booking data access
 * 2. Dependency Inversion: Depends on ApiService abstraction
 * 
 * Repository Pattern: Separates data access from business logic
 */

import '../models/booking_model.dart';
import '../services/api_service.dart';

class BookingRepository {
  final ApiService _apiService;

  BookingRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Fetch bookings for a specific court
  Future<List<BookingModel>> getBookingsByCourtId(
    String courtId, {
    int? courtNum,
  }) async {
    try {
      final endpoint = courtNum != null
          ? '/booking/court/$courtId?courtNum=$courtNum'
          : '/booking/court/$courtId';
      
      final response = await _apiService.get(endpoint);
      final bookings = (response['data']['bookings'] as List)
          .map((json) => BookingModel.fromJson(json))
          .toList();
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  /// Create a new booking
  Future<BookingModel> createBooking({
    required String courtId,
    required int courtNum,
    required DateTime startTime,
    required DateTime endTime,
    required int totalPrice,
  }) async {
    try {
      final response = await _apiService.post('/booking/book-court', {
        'courtID': courtId,
        'courtNum': courtNum,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'totalPrice': totalPrice,
      });
      return BookingModel.fromJson(response['data']['booking']);
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  /// Mark court as unavailable
  Future<void> markUnavailable({
    required String courtId,
    required int courtNum,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      await _apiService.post('/booking/mark-unavailable', {
        'courtID': courtId,
        'courtNum': courtNum,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to mark unavailable: $e');
    }
  }

  /// Fetch booking history for the logged-in team
  Future<List<BookingModel>> getBookingHistory() async {
    try {
      final response = await _apiService.get('/booking/booking-history');
      final bookings = (response['data']['bookings'] as List)
          .map((json) => BookingModel.fromJson(json))
          .toList();
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch booking history: $e');
    }
  }
}

