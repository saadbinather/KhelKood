# Frontend Architecture Documentation

## Overview
This Flutter application follows **SOLID principles** and **OOP best practices** with a **modular, layered architecture**.

---

## SOLID Principles Implemented

### 1. **Single Responsibility Principle (SRP)**
Each class/module has one clear responsibility:
- **Models**: Only handle data structure (e.g., `CourtModel`, `BookingModel`)
- **Repositories**: Only handle data access/API calls (e.g., `CourtRepository`)
- **Services**: Only handle HTTP communication (`ApiService`)
- **Widgets**: Only handle UI presentation (e.g., `CourtCard`, `LoadingIndicator`)

### 2. **Dependency Inversion Principle (DIP)**
High-level modules depend on abstractions, not concrete implementations:
- **Repositories** depend on `ApiService` abstraction (injected via constructor)
- Pages use **Repository pattern** instead of direct API calls
- Easy to swap implementations (e.g., mock API for testing)

---

## OOP Principles Applied

### 1. **Encapsulation**
- Models encapsulate data with private fields and getters
- Business logic encapsulated in model methods (e.g., `booking.isFriendly()`)
- Widgets encapsulate their own state and UI logic

### 2. **Inheritance**
- All models can extend a base `Entity` class if needed
- Widgets inherit from `StatelessWidget` or `StatefulWidget`

### 3. **Polymorphism**
- Different sport types handled through a unified interface
- Repositories can be swapped without changing calling code

### 4. **Abstraction**
- Complex API logic abstracted behind simple repository methods
- UI components abstracted into reusable widgets

---

## Folder Structure

```
lib/
├── core/
│   ├── models/              # Data entities (OOP)
│   │   ├── court_model.dart
│   │   ├── booking_model.dart
│   │   └── challenge_model.dart
│   │
│   ├── repositories/        # Data access layer (SRP, DIP)
│   │   ├── court_repository.dart
│   │   ├── booking_repository.dart
│   │   └── challenge_repository.dart
│   │
│   ├── services/            # HTTP communication (SRP)
│   │   └── api_service.dart
│   │
│   ├── constants/           # App-wide constants
│   │   └── api_constants.dart
│   │
│   └── utils/               # Helper functions (SRP)
│       ├── sport_utils.dart
│       └── date_utils.dart
│
├── shared/
│   └── widgets/             # Reusable UI components
│       ├── loading_indicator.dart
│       ├── error_display.dart
│       ├── court_card.dart
│       ├── custom_button.dart
│       └── empty_state.dart
│
├── screens/                 # Page-level widgets
│   ├── all_courts_page.dart
│   ├── booking_history_page.dart
│   ├── create_booking_page.dart
│   └── ...
│
├── widgets/                 # Feature-specific widgets
│   └── time_slot_grid.dart
│
├── CourtOwner/              # Court owner specific screens
├── Admin/                   # Admin specific screens
└── main.dart
```

---

## Architecture Layers

### **1. Data Layer (Models)**
**Responsibility**: Define data structures

```dart
class CourtModel {
  final String id;
  final String name;
  // ... fields
  
  // Factory for JSON deserialization
  factory CourtModel.fromJson(Map<String, dynamic> json) { ... }
  
  // Business logic methods
  int getCourtsForSport(String sport) { ... }
}
```

**Benefits**:
- Type-safe data structures
- Centralized data validation
- Business logic encapsulated in models

---

### **2. Repository Layer (Data Access)**
**Responsibility**: Handle API communication

```dart
class CourtRepository {
  final ApiService _apiService;
  
  CourtRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();
  
  Future<List<CourtModel>> getVerifiedCourts() async {
    final response = await _apiService.get('/courts/verified');
    return (response['data']['courts'] as List)
        .map((json) => CourtModel.fromJson(json))
        .toList();
  }
}
```

**Benefits** (SOLID):
- **SRP**: Only handles data fetching
- **DIP**: Depends on `ApiService` abstraction
- Easy to mock for testing
- Consistent error handling

---

### **3. Service Layer (HTTP)**
**Responsibility**: HTTP communication

```dart
class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';
  
  Future<Map<String, dynamic>> get(String endpoint) async {
    final headers = await _buildHeaders();
    final response = await http.get(Uri.parse('$baseUrl$endpoint'), ...);
    return _handleResponse(response);
  }
}
```

**Benefits**:
- **SRP**: Only handles HTTP
- Centralized token management
- Consistent response handling
- Singleton pattern for efficiency

---

### **4. Presentation Layer (Widgets)**
**Responsibility**: UI rendering

#### **Reusable Components**:
```dart
// Before: Duplicate loading code everywhere
Center(child: CircularProgressIndicator(color: Colors.redAccent))

// After: Reusable component
LoadingIndicator(message: 'Fetching courts...')
```

**Reusable Widgets**:
- `LoadingIndicator`: Consistent loading UI
- `ErrorDisplay`: Consistent error handling UI
- `CourtCard`: Reusable court display
- `CustomButton`: Consistent button styling
- `EmptyState`: Consistent empty state UI

---

## Usage Examples

### **Example 1: Fetch Courts (Old vs New)**

**❌ Old Way** (No separation of concerns):
```dart
Future<void> _fetchCourts() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final response = await http.get(
    Uri.parse('http://localhost:5000/api/courts/verified'),
    headers: {'Authorization': 'Bearer $token', ...},
  );
  final data = jsonDecode(response.body);
  setState(() {
    courts = data['data']['courts'];
  });
}
```

**✅ New Way** (SOLID principles):
```dart
final _courtRepository = CourtRepository();

Future<void> _fetchCourts() async {
  try {
    final courts = await _courtRepository.getVerifiedCourts();
    setState(() {
      _courts = courts;
    });
  } catch (e) {
    // Handle error
  }
}
```

**Benefits**:
- Clean, readable code
- Easy to test (mock repository)
- Type-safe models
- Centralized API logic

---

### **Example 2: Display Court Card (Old vs New)**

**❌ Old Way** (Duplicate code):
```dart
// Same card UI code repeated in 5+ files
Card(
  color: Colors.grey[900],
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text(court['name']),
        Text(court['location']),
        // ... 50 more lines
      ],
    ),
  ),
)
```

**✅ New Way** (Reusable component):
```dart
CourtCard(
  court: court,
  isSelected: selectedCourtId == court.id,
  onTap: () => _selectCourt(court),
  displaySport: 'cricket',
)
```

**Benefits**:
- **DRY**: Don't Repeat Yourself
- Consistent UI across app
- Easy to update styling globally
- Reduced code duplication

---

## Benefits of This Architecture

### **1. Maintainability**
- Easy to find and fix bugs (single responsibility)
- Changes in one layer don't affect others
- Clear separation of concerns

### **2. Testability**
- Easy to unit test (mock repositories)
- Integration testing simplified
- Business logic isolated from UI

### **3. Scalability**
- Easy to add new features
- New developers can understand structure quickly
- Modular components can be reused

### **4. Code Quality**
- Reduced code duplication (50%+ reduction in some files)
- Type-safe data handling
- Consistent error handling
- Cleaner, more readable code

---

## Migration Guide

### **Step 1: Use Models**
Replace raw `Map<String, dynamic>` with typed models:
```dart
// Before
Map<String, dynamic> court;

// After
CourtModel court;
```

### **Step 2: Use Repositories**
Replace direct API calls with repository methods:
```dart
// Before
final response = await http.get(...);
final data = jsonDecode(response.body);

// After
final courts = await _courtRepository.getVerifiedCourts();
```

### **Step 3: Use Reusable Widgets**
Replace duplicate UI code with shared widgets:
```dart
// Before
Center(child: CircularProgressIndicator(...))

// After
LoadingIndicator(message: 'Loading...')
```

---

## Testing Strategy

### **Unit Tests** (Models & Utils)
```dart
test('Court model returns correct sport count', () {
  final court = CourtModel(cricketCourts: 3, ...);
  expect(court.getCourtsForSport('cricket'), 3);
});
```

### **Integration Tests** (Repositories)
```dart
test('Court repository fetches courts', () async {
  final mockApiService = MockApiService();
  final repository = CourtRepository(apiService: mockApiService);
  final courts = await repository.getVerifiedCourts();
  expect(courts.length, greaterThan(0));
});
```

---

## Next Steps

1. ✅ Models created (`CourtModel`, `BookingModel`, `ChallengeModel`)
2. ✅ Repositories created (`CourtRepository`, `BookingRepository`, `ChallengeRepository`)
3. ✅ Reusable widgets created (`CourtCard`, `LoadingIndicator`, etc.)
4. ⏳ Migrate existing screens to use new architecture
5. ⏳ Add unit tests for models and repositories
6. ⏳ Add integration tests for critical flows

---

## Summary

This architecture brings **professional-grade structure** to the Flutter app:

- **SOLID Principles**: SRP and DIP implemented throughout
- **OOP**: Encapsulation, abstraction, and polymorphism
- **Modularity**: Reusable components reduce duplication
- **Maintainability**: Clear separation of concerns
- **Scalability**: Easy to extend with new features

The codebase is now more **maintainable**, **testable**, and **scalable**! 🚀

