import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../repositories/team_repository.dart';
import '../repositories/court_repository.dart';
import '../repositories/booking_repository.dart';
import '../repositories/challenge_repository.dart';

/// Service Locator for Dependency Injection
/// Implements Dependency Inversion Principle
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Services
  StorageService? _storageService;
  ApiService? _apiService;

  // Repositories
  TeamRepository? _teamRepository;
  CourtRepository? _courtRepository;
  BookingRepository? _bookingRepository;
  ChallengeRepository? _challengeRepository;

  /// Initialize all services
  Future<void> initialize() async {
    _storageService = await StorageService.getInstance();
    _apiService = ApiService(_storageService!);
    _teamRepository = TeamRepository(_apiService!);
    _courtRepository = CourtRepository(_apiService!);
    _bookingRepository = BookingRepository(_apiService!);
    _challengeRepository = ChallengeRepository(_apiService!);
  }

  /// Get Storage Service
  StorageService get storageService {
    if (_storageService == null) {
      throw Exception('ServiceLocator not initialized. Call initialize() first.');
    }
    return _storageService!;
  }

  /// Get API Service
  ApiService get apiService {
    if (_apiService == null) {
      throw Exception('ServiceLocator not initialized. Call initialize() first.');
    }
    return _apiService!;
  }

  /// Get Team Repository
  ITeamRepository get teamRepository {
    if (_teamRepository == null) {
      throw Exception('ServiceLocator not initialized. Call initialize() first.');
    }
    return _teamRepository!;
  }

  /// Get Court Repository
  ICourtRepository get courtRepository {
    if (_courtRepository == null) {
      throw Exception('ServiceLocator not initialized. Call initialize() first.');
    }
    return _courtRepository!;
  }

  /// Get Booking Repository
  IBookingRepository get bookingRepository {
    if (_bookingRepository == null) {
      throw Exception('ServiceLocator not initialized. Call initialize() first.');
    }
    return _bookingRepository!;
  }

  /// Get Challenge Repository
  IChallengeRepository get challengeRepository {
    if (_challengeRepository == null) {
      throw Exception('ServiceLocator not initialized. Call initialize() first.');
    }
    return _challengeRepository!;
  }

  /// Reset all services (useful for testing)
  void reset() {
    _storageService = null;
    _apiService = null;
    _teamRepository = null;
    _courtRepository = null;
    _bookingRepository = null;
    _challengeRepository = null;
  }
}
