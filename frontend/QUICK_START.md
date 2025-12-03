# Quick Start Guide - New Architecture

## 🚀 Getting Started

### 1. Initialize Dependencies (Once at App Startup)

In your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:frontend/core/di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection
  await ServiceLocator().initialize();
  
  runApp(const MyApp());
}
```

## 📦 Using the New Architecture

### Fetching Data with Repositories

```dart
import 'package:frontend/core/di/service_locator.dart';
import 'package:frontend/core/models/team_model.dart';

// In your StatefulWidget state:
TeamModel? team;
bool isLoading = true;

@override
void initState() {
  super.initState();
  _loadTeam();
}

Future<void> _loadTeam() async {
  setState(() => isLoading = true);
  
  // Get repository from service locator
  final teamRepo = ServiceLocator().teamRepository;
  
  // Fetch data
  final fetchedTeam = await teamRepo.getTeamDetails();
  
  setState(() {
    team = fetchedTeam;
    isLoading = false;
  });
}
```

### Using Reusable Widgets

```dart
import 'package:frontend/shared/widgets/stat_card.dart';
import 'package:frontend/shared/widgets/loading_indicator.dart';
import 'package:frontend/shared/widgets/error_message.dart';
import 'package:frontend/core/constants/app_colors.dart';

@override
Widget build(BuildContext context) {
  if (isLoading) {
    return const LoadingIndicator(
      message: 'Loading...',
    );
  }
  
  if (team == null) {
    return ErrorMessage(
      message: 'Failed to load team',
      onRetry: _loadTeam,
    );
  }
  
  return Column(
    children: [
      StatCard(
        label: 'Win Rate',
        value: '${team!.winRate.toStringAsFixed(1)}%',
        icon: Icons.trending_up,
        iconColor: AppColors.success,
      ),
      // More widgets...
    ],
  );
}
```

### Working with Models

```dart
import 'package:frontend/core/models/team_model.dart';

// Create from JSON
final team = TeamModel.fromJson({
  'teamName': 'Warriors',
  'wins': 10,
  'losses': 5,
});

// Access properties
print(team.teamName);        // 'Warriors'
print(team.winRate);         // 66.67 (calculated)
print(team.matchSummary);    // '10W - 5L - 0D'

// Convert to JSON
final json = team.toJson();

// Create modified copy
final updatedTeam = team.copyWith(wins: 11);
```

## 🎨 Common UI Patterns

### 1. Displaying a List of Cards

```dart
ListView.separated(
  itemCount: courts.length,
  separatorBuilder: (context, index) => const SizedBox(height: 12),
  itemBuilder: (context, index) {
    return CourtCard(
      court: courts[index],
      onTap: () => _navigateToCourt(courts[index]),
    );
  },
)
```

### 2. Section with Header and Action

```dart
Column(
  children: [
    SectionHeader(
      title: 'Top Teams',
      icon: Icons.leaderboard,
      actionLabel: 'View All',
      onActionPressed: () => _navigateToLeaderboard(),
    ),
    const SizedBox(height: 12),
    // Content here
  ],
)
```

### 3. Loading, Error, and Empty States

```dart
Widget _buildBody() {
  if (isLoading) {
    return const LoadingIndicator(message: 'Loading data...');
  }
  
  if (errorMessage != null) {
    return ErrorMessage(
      message: errorMessage!,
      onRetry: _loadData,
    );
  }
  
  if (items.isEmpty) {
    return EmptyState(
      title: 'No Items',
      message: 'There are no items to display',
      icon: Icons.inbox,
      actionLabel: 'Add Item',
      onAction: () => _navigateToAdd(),
    );
  }
  
  return _buildContent();
}
```

## 📁 File Organization

### Creating a New Feature

1. **Create Model** (if needed):
```dart
// lib/core/models/feature_model.dart
class FeatureModel {
  final String id;
  final String name;
  
  FeatureModel({required this.id, required this.name});
  
  factory FeatureModel.fromJson(Map<String, dynamic> json) {
    return FeatureModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
```

2. **Create Repository**:
```dart
// lib/core/repositories/feature_repository.dart
abstract class IFeatureRepository {
  Future<List<FeatureModel>> getFeatures();
}

class FeatureRepository implements IFeatureRepository {
  final ApiService _apiService;
  
  FeatureRepository(this._apiService);
  
  @override
  Future<List<FeatureModel>> getFeatures() async {
    final response = await _apiService.get('/features');
    // Parse and return
  }
}
```

3. **Register in ServiceLocator**:
```dart
// lib/core/di/service_locator.dart
FeatureRepository? _featureRepository;

Future<void> initialize() async {
  // ... existing code
  _featureRepository = FeatureRepository(_apiService!);
}

IFeatureRepository get featureRepository {
  if (_featureRepository == null) {
    throw Exception('ServiceLocator not initialized.');
  }
  return _featureRepository!;
}
```

4. **Create Reusable Widget** (if needed):
```dart
// lib/shared/widgets/feature_card.dart
class FeatureCard extends StatelessWidget {
  final FeatureModel feature;
  final VoidCallback? onTap;
  
  const FeatureCard({
    super.key,
    required this.feature,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // Card design
      ),
    );
  }
}
```

5. **Use in Screen**:
```dart
// lib/screens/feature_page.dart
class _FeaturePageState extends State<FeaturePage> {
  List<FeatureModel> features = [];
  
  @override
  void initState() {
    super.initState();
    _loadFeatures();
  }
  
  Future<void> _loadFeatures() async {
    final repo = ServiceLocator().featureRepository;
    final data = await repo.getFeatures();
    setState(() => features = data);
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: features.length,
      itemBuilder: (context, index) {
        return FeatureCard(
          feature: features[index],
          onTap: () => _onFeatureTap(features[index]),
        );
      },
    );
  }
}
```

## 🔧 Common Tasks

### Task 1: Add a New API Endpoint

```dart
// 1. Add constant
// lib/core/constants/app_constants.dart
static const String myNewEndpoint = '/my/endpoint';

// 2. Add repository method
// lib/core/repositories/my_repository.dart
Future<MyModel?> getMyData() async {
  final response = await _apiService.get(AppConstants.myNewEndpoint);
  if (_apiService.isSuccessful(response)) {
    final data = _apiService.parseResponse(response);
    return MyModel.fromJson(data);
  }
  return null;
}

// 3. Use in UI
final repo = ServiceLocator().myRepository;
final data = await repo.getMyData();
```

### Task 2: Add a New Reusable Widget

```dart
// lib/shared/widgets/my_widget.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class MyWidget extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  
  const MyWidget({
    super.key,
    required this.title,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
```

### Task 3: Handle Form Submission

```dart
Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;
  
  setState(() => isLoading = true);
  
  try {
    final repo = ServiceLocator().myRepository;
    final data = {
      'name': nameController.text,
      'email': emailController.text,
    };
    
    final result = await repo.createItem(data);
    
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Success!')),
      );
      Navigator.pop(context);
    } else {
      _showError('Failed to create item');
    }
  } catch (e) {
    _showError('Error: $e');
  } finally {
    setState(() => isLoading = false);
  }
}

void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
    ),
  );
}
```

## 🎯 Best Practices

### DO ✅

```dart
// Use repositories for data
final repo = ServiceLocator().teamRepository;
final team = await repo.getTeamDetails();

// Use typed models
TeamModel team = TeamModel.fromJson(json);

// Use reusable widgets
StatCard(label: 'Wins', value: '10', icon: Icons.check)

// Use constants
final url = '${AppConstants.baseUrl}${AppConstants.teamsEndpoint}';

// Handle errors gracefully
try {
  final data = await repo.getData();
  if (data == null) {
    _showError('No data available');
  }
} catch (e) {
  _showError('Error: $e');
}
```

### DON'T ❌

```dart
// Don't make direct HTTP calls
final response = await http.get(url); // ❌

// Don't use Map<String, dynamic> for data
Map<String, dynamic> team = {...}; // ❌

// Don't repeat UI code
Container(/* lots of styling code */); // ❌

// Don't hardcode URLs
final url = 'http://localhost:5000/api/teams'; // ❌

// Don't ignore errors
final data = await repo.getData(); // No error handling ❌
```

## 📚 Available Repositories

```dart
ServiceLocator().teamRepository       // Team operations
ServiceLocator().courtRepository      // Court operations
ServiceLocator().bookingRepository    // Booking operations
ServiceLocator().challengeRepository  // Challenge operations
```

## 🎨 Available Widgets

```dart
// Display Widgets
StatCard()           // Display single statistic
SectionHeader()      // Section title with action
TeamStatsRow()       // Team statistics row

// Entity Cards
CourtCard()          // Display court
ChallengeCard()      // Display challenge
LeaderboardCard()    // Display team ranking

// State Widgets
LoadingIndicator()   // Loading state
ErrorMessage()       // Error state
EmptyState()         // Empty state
```

## 🔗 Useful Imports

```dart
// Models
import 'package:frontend/core/models/team_model.dart';
import 'package:frontend/core/models/court_model.dart';
import 'package:frontend/core/models/booking_model.dart';
import 'package:frontend/core/models/challenge_model.dart';

// Services & DI
import 'package:frontend/core/di/service_locator.dart';

// Constants
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/constants/app_colors.dart';

// Widgets
import 'package:frontend/shared/widgets/stat_card.dart';
import 'package:frontend/shared/widgets/court_card.dart';
import 'package:frontend/shared/widgets/challenge_card.dart';
import 'package:frontend/shared/widgets/loading_indicator.dart';
import 'package:frontend/shared/widgets/error_message.dart';
import 'package:frontend/shared/widgets/empty_state.dart';
```

## 🐛 Debugging Tips

### Issue: "ServiceLocator not initialized"
**Solution**: Make sure to call `await ServiceLocator().initialize()` in `main.dart` before `runApp()`.

### Issue: Null values in models
**Solution**: Check if the JSON keys match. Models use fallback values for safety.

### Issue: Widget not updating
**Solution**: Make sure you're calling `setState()` after data changes.

### Issue: "Can't find repository"
**Solution**: Ensure the repository is registered in `ServiceLocator.initialize()`.

## 📖 Further Reading

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Full architecture documentation
- [IMPLEMENTATION_EXAMPLE.md](./IMPLEMENTATION_EXAMPLE.md) - Detailed examples
- [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md) - What was changed
- [ARCHITECTURE_DIAGRAM.md](./ARCHITECTURE_DIAGRAM.md) - Visual diagrams

## 🎉 You're Ready!

Start using the new architecture in your screens. The benefits will become clear as you work with it:
- Less boilerplate
- Type safety
- Reusable components
- Easier testing
- Better organization

Happy coding! 🚀

