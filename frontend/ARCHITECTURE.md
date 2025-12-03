# KhelKood Frontend Architecture

## Overview
This document describes the architecture and design principles implemented in the KhelKood frontend application.

## Design Principles Implemented

### 1. SOLID Principles

#### Single Responsibility Principle (SRP)
Each class/module has only one reason to change:
- **Services**: Handle only one type of operation
  - `StorageService`: Manages local storage operations only
  - `ApiService`: Handles HTTP requests only
- **Repositories**: Handle data operations for a single entity
  - `TeamRepository`: Team data operations only
  - `CourtRepository`: Court data operations only
  - `BookingRepository`: Booking data operations only
  - `ChallengeRepository`: Challenge data operations only
- **Widgets**: Each widget has a single purpose
  - `StatCard`: Display single statistic
  - `CourtCard`: Display court information
  - `ChallengeCard`: Display challenge information
- **Models**: Encapsulate data and related logic for single entity
- **Constants**: Separated into logical groups (colors, app constants)

#### Dependency Inversion Principle (DIP)
High-level modules depend on abstractions, not concrete implementations:
- **Repository Interfaces**: Abstract interfaces defined (`ITeamRepository`, `ICourtRepository`, etc.)
- **Dependency Injection**: Services injected through constructors
- **Service Locator**: Centralizes dependency management
- Example:
```dart
abstract class ITeamRepository {
  Future<TeamModel?> getTeamDetails();
  Future<List<TeamModel>> getTopTeams({int limit = 10});
}

class TeamRepository implements ITeamRepository {
  final ApiService _apiService; // Depends on abstraction
  TeamRepository(this._apiService); // Constructor injection
}
```

### 2. Object-Oriented Programming (OOP) Principles

#### Encapsulation
- Models encapsulate data with private/public access
- Business logic contained within models
- Data validation in model constructors
- Example:
```dart
class TeamModel {
  final String teamName;
  final int? wins;
  
  // Encapsulated business logic
  double get winRate {
    final totalMatches = (wins ?? 0) + (losses ?? 0) + (draws ?? 0);
    if (totalMatches == 0) return 0.0;
    return ((wins ?? 0) / totalMatches) * 100;
  }
}
```

#### Abstraction
- Abstract repository interfaces hide implementation details
- Widget abstractions for reusable components
- Service interfaces define contracts

#### Polymorphism
- Multiple implementations can satisfy repository interfaces
- Widgets can be extended and customized
- Service implementations can be swapped

#### Inheritance
- Flutter widget inheritance for reusability
- Stateless/Stateful widget extensions

### 3. Modularity & Component Architecture

#### Folder Structure
```
frontend/lib/
├── core/                          # Core business logic
│   ├── constants/                 # App-wide constants
│   │   ├── app_constants.dart    # API URLs, keys, config
│   │   └── app_colors.dart       # Color scheme
│   ├── models/                    # Data models
│   │   ├── team_model.dart
│   │   ├── court_model.dart
│   │   ├── booking_model.dart
│   │   └── challenge_model.dart
│   ├── services/                  # Service layer
│   │   ├── storage_service.dart  # Local storage
│   │   └── api_service.dart      # HTTP client
│   ├── repositories/              # Data access layer
│   │   ├── team_repository.dart
│   │   ├── court_repository.dart
│   │   ├── booking_repository.dart
│   │   └── challenge_repository.dart
│   └── di/                        # Dependency injection
│       └── service_locator.dart
├── shared/                        # Shared/reusable components
│   └── widgets/                   # Reusable widgets
│       ├── stat_card.dart
│       ├── court_card.dart
│       ├── challenge_card.dart
│       ├── leaderboard_card.dart
│       ├── team_stats_row.dart
│       ├── section_header.dart
│       ├── loading_indicator.dart
│       ├── error_message.dart
│       └── empty_state.dart
├── screens/                       # Feature screens
│   ├── dashboard/
│   │   └── dashboard_sections.dart
│   └── [other screens...]
└── widgets/                       # Screen-specific widgets
```

## Architecture Layers

### 1. Presentation Layer (UI)
- **Widgets**: Reusable UI components
- **Screens**: Page-level components
- **Sections**: Logical groupings of related UI

### 2. Business Logic Layer
- **Repositories**: Data access and business rules
- **Models**: Data structures with business logic
- **Services**: Cross-cutting concerns

### 3. Data Layer
- **API Service**: HTTP communication
- **Storage Service**: Local persistence
- **Models**: Data transformation (JSON ↔ Dart objects)

## Key Features

### Dependency Injection
Using Service Locator pattern for centralized dependency management:
```dart
// Initialize once at app startup
await ServiceLocator().initialize();

// Access anywhere in the app
final teamRepo = ServiceLocator().teamRepository;
final teams = await teamRepo.getTopTeams();
```

### Type-Safe Models
All data is strongly typed with validation:
```dart
factory TeamModel.fromJson(Map<String, dynamic> json) {
  return TeamModel(
    teamName: json['teamName']?.toString() ?? 'Unknown Team',
    wins: _parseInt(json['wins']),
    // ... more fields with validation
  );
}
```

### Reusable Components
Components are designed to be:
- **Composable**: Can be combined to create complex UIs
- **Configurable**: Accept parameters for customization
- **Self-contained**: Include all necessary logic and styling

### Error Handling
- Try-catch blocks in all async operations
- Graceful degradation with default values
- User-friendly error messages

## Best Practices

### 1. Code Organization
- One class per file
- Related files grouped in directories
- Clear naming conventions

### 2. Separation of Concerns
- UI logic separated from business logic
- Data access separated from presentation
- Configuration separated from code

### 3. DRY (Don't Repeat Yourself)
- Reusable widgets for common UI patterns
- Shared models and services
- Centralized constants

### 4. Testability
- Dependency injection enables easy mocking
- Pure functions in models
- Clear interfaces for repositories

## Usage Examples

### Using Repositories
```dart
// Get team details
final teamRepo = ServiceLocator().teamRepository;
final team = await teamRepo.getTeamDetails();

// Get top teams
final topTeams = await teamRepo.getTopTeams(limit: 10);
```

### Using Reusable Widgets
```dart
// Display a stat card
StatCard(
  label: 'Win Rate',
  value: '75%',
  icon: Icons.trending_up,
  onTap: () => navigateToStats(),
)

// Display a court card
CourtCard(
  court: courtModel,
  onTap: () => navigateToCourt(courtModel),
)
```

### Using Models
```dart
// Create from JSON
final team = TeamModel.fromJson(jsonData);

// Access business logic
final winRate = team.winRate;
final summary = team.matchSummary;

// Convert to JSON
final json = team.toJson();
```

## Future Enhancements

1. **State Management**: Implement Provider/Riverpod for reactive state
2. **Caching**: Add data caching in repositories
3. **Offline Support**: Implement offline-first architecture
4. **Testing**: Add unit tests for repositories and models
5. **Error Tracking**: Integrate error monitoring service
6. **Analytics**: Add user behavior tracking
7. **Internationalization**: Support multiple languages

## Migration Guide

### Migrating Existing Code

1. **Replace direct API calls** with repository methods:
```dart
// Before
final response = await http.get(url, headers: headers);
final data = jsonDecode(response.body);

// After
final team = await ServiceLocator().teamRepository.getTeamDetails();
```

2. **Replace Map<String, dynamic>** with typed models:
```dart
// Before
Map<String, dynamic> team = {...};
final name = team['teamName'];

// After
TeamModel team = TeamModel.fromJson({...});
final name = team.teamName;
```

3. **Use reusable widgets** instead of custom implementations:
```dart
// Before
Container(
  // ... lots of boilerplate
  child: Text(...),
)

// After
StatCard(label: 'Wins', value: '10', icon: Icons.check)
```

## Conclusion

This architecture provides:
- ✅ **Maintainability**: Easy to understand and modify
- ✅ **Scalability**: Can grow without becoming complex
- ✅ **Testability**: Easy to write tests
- ✅ **Reusability**: Components can be reused across the app
- ✅ **Type Safety**: Compile-time error detection
- ✅ **Separation of Concerns**: Clear boundaries between layers

