import '../models/booking_model.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

/// Repository interface for booking data operations
/// Implements Dependency Inversion Principle - depend on abstractions
abstract class IBookingRepository {
  Future<List<BookingModel>> getUserBookings();
  Future<List<BookingModel>> getUpcomingBookings();
  Future<List<BookingModel>> getPastBookings();
  Future<BookingModel?> createBooking(Map<String, dynamic> bookingData);
  Future<bool> cancelBooking(String bookingId);
  Future<BookingModel?> getBookingById(String bookingId);
}

/// Booking repository implementation
/// Implements Single Responsibility - only handles booking data operations
class BookingRepository implements IBookingRepository {
  final ApiService _apiService;

  // Dependency injection through constructor
  BookingRepository(this._apiService);

  @override
  Future<List<BookingModel>> getUserBookings() async {
    try {
      final response = await _apiService.get(AppConstants.bookingsEndpoint);
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final bookingsData = data['data']?['bookings'] ?? 
                            data['bookings'] ?? 
                            data['data'] ?? 
                            [];
        
        if (bookingsData is List) {
          return bookingsData
              .map((bookingJson) => BookingModel.fromJson(bookingJson as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching user bookings: $e');
      return [];
    }
  }

  @override
  Future<List<BookingModel>> getUpcomingBookings() async {
    try {
      final response = await _apiService.get('${AppConstants.bookingsEndpoint}/upcoming');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final bookingsData = data['data']?['bookings'] ?? data['bookings'] ?? [];
        
        if (bookingsData is List) {
          return bookingsData
              .map((bookingJson) => BookingModel.fromJson(bookingJson as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching upcoming bookings: $e');
      return [];
    }
  }

  @override
  Future<List<BookingModel>> getPastBookings() async {
    try {
      final response = await _apiService.get('${AppConstants.bookingsEndpoint}/past');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final bookingsData = data['data']?['bookings'] ?? data['bookings'] ?? [];
        
        if (bookingsData is List) {
          return bookingsData
              .map((bookingJson) => BookingModel.fromJson(bookingJson as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching past bookings: $e');
      return [];
    }
  }

  @override
  Future<BookingModel?> createBooking(Map<String, dynamic> bookingData) async {
    try {
      final response = await _apiService.post(
        AppConstants.bookingsEndpoint,
        bookingData,
      );
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final bookingResult = data['data']?['booking'] ?? data['booking'] ?? data;
        
        if (bookingResult != null && bookingResult is Map<String, dynamic>) {
          return BookingModel.fromJson(bookingResult);
        }
      }
      
      return null;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  @override
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final response = await _apiService.delete('${AppConstants.bookingsEndpoint}/$bookingId');
      return _apiService.isSuccessful(response);
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  @override
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final response = await _apiService.get('${AppConstants.bookingsEndpoint}/$bookingId');
      
      if (_apiService.isSuccessful(response)) {
        final data = _apiService.parseResponse(response);
        final bookingData = data['data']?['booking'] ?? data['booking'] ?? data;
        
        if (bookingData != null && bookingData is Map<String, dynamic>) {
          return BookingModel.fromJson(bookingData);
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching booking by ID: $e');
      return null;
    }
  }
}

