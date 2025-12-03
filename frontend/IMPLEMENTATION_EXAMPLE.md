# Implementation Example: Using the New Architecture

This document provides practical examples of how to use the new architecture in your screens.

## Example 1: Refactored Dashboard Page (Simplified)

Here's how you can refactor the existing `dashboard_page.dart` to use the new architecture:

### Before (Old Approach)
```dart
class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? teamData;
  
  Future<void> _fetchTeamDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    final response = await http.get(
      Uri.parse('http://localhost:5000/api/teams/details'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        teamData = data['team'];
      });
    }
  }
}
```

### After (New Architecture)
```dart
import 'package:frontend/core/di/service_locator.dart';
import 'package:frontend/core/models/team_model.dart';
import 'package:frontend/core/models/court_model.dart';
import 'package:frontend/shared/widgets/loading_indicator.dart';
import 'package:frontend/shared/widgets/error_message.dart';
import 'package:frontend/screens/dashboard/dashboard_sections.dart';

class _DashboardPageState extends State<DashboardPage> {
  TeamModel? team;
  List<CourtModel> courts = [];
  List<TeamModel> topTeams = [];
  bool isLoading = true;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      // Use repositories through service locator
      final teamRepo = ServiceLocator().teamRepository;
      final courtRepo = ServiceLocator().courtRepository;
      
      // Fetch data using repositories
      final fetchedTeam = await teamRepo.getTeamDetails();
      final fetchedCourts = await courtRepo.getVerifiedCourts();
      final fetchedTopTeams = await teamRepo.getTopTeams(limit: 5);
      
      setState(() {
        team = fetchedTeam;
        courts = fetchedCourts;
        topTeams = fetchedTopTeams;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load data: $e';
        isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(team?.teamName ?? 'Dashboard'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (isLoading) {
      return const LoadingIndicator(message: 'Loading dashboard...');
    }
    
    if (errorMessage != null) {
      return ErrorMessage(
        message: errorMessage!,
        onRetry: _loadData,
      );
    }
    
    if (team == null) {
      return const EmptyState(
        title: 'No Team Data',
        message: 'Unable to load your team information',
        icon: Icons.error_outline,
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use modular sections
            TeamOverviewSection(team: team!),
            const SizedBox(height: 24),
            
            QuickStatsSection(team: team!),
            const SizedBox(height: 24),
            
            VerifiedCourtsSection(
              courts: courts,
              onViewAll: () => _navigateToAllCourts(),
              onCourtTap: (court) => _navigateToCourtDetails(court),
            ),
            const SizedBox(height: 24),
            
            LeaderboardSection(
              topTeams: topTeams,
              onViewAll: () => _navigateToLeaderboard(),
            ),
          ],
        ),
      ),
    );
  }
  
  void _navigateToAllCourts() {
    // Navigation logic
  }
  
  void _navigateToCourtDetails(CourtModel court) {
    // Navigation logic
  }
  
  void _navigateToLeaderboard() {
    // Navigation logic
  }
}
```

## Example 2: Challenges Page with New Architecture

### New Implementation
```dart
import 'package:frontend/core/di/service_locator.dart';
import 'package:frontend/core/models/challenge_model.dart';
import 'package:frontend/shared/widgets/challenge_card.dart';
import 'package:frontend/shared/widgets/loading_indicator.dart';
import 'package:frontend/shared/widgets/error_message.dart';
import 'package:frontend/shared/widgets/empty_state.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  List<ChallengeModel> incomingChallenges = [];
  List<ChallengeModel> outgoingChallenges = [];
  bool isLoading = true;
  String? errorMessage;
  Set<String> processingChallenges = {};

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final challengeRepo = ServiceLocator().challengeRepository;
      final challenges = await challengeRepo.getOpenChallenges();

      setState(() {
        incomingChallenges = challenges['incoming'] ?? [];
        outgoingChallenges = challenges['outgoing'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load challenges: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _acceptChallenge(ChallengeModel challenge) async {
    if (challenge.id == null) return;

    setState(() {
      processingChallenges.add(challenge.id!);
    });

    try {
      final challengeRepo = ServiceLocator().challengeRepository;
      final success = await challengeRepo.acceptChallenge(challenge.id!);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge accepted!')),
        );
        _loadChallenges(); // Reload data
      } else {
        _showError('Failed to accept challenge');
      }
    } catch (e) {
      _showError('Error accepting challenge: $e');
    } finally {
      setState(() {
        processingChallenges.remove(challenge.id);
      });
    }
  }

  Future<void> _declineChallenge(ChallengeModel challenge) async {
    if (challenge.id == null) return;

    setState(() {
      processingChallenges.add(challenge.id!);
    });

    try {
      final challengeRepo = ServiceLocator().challengeRepository;
      final success = await challengeRepo.declineChallenge(challenge.id!);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge declined')),
        );
        _loadChallenges();
      } else {
        _showError('Failed to decline challenge');
      }
    } catch (e) {
      _showError('Error declining challenge: $e');
    } finally {
      setState(() {
        processingChallenges.remove(challenge.id);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToCreateChallenge(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const LoadingIndicator(message: 'Loading challenges...');
    }

    if (errorMessage != null) {
      return ErrorMessage(
        message: errorMessage!,
        onRetry: _loadChallenges,
      );
    }

    if (incomingChallenges.isEmpty && outgoingChallenges.isEmpty) {
      return EmptyState(
        title: 'No Challenges',
        message: 'Create or receive challenges to get started',
        icon: Icons.sports_tennis,
        actionLabel: 'Create Challenge',
        onAction: _navigateToCreateChallenge,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (incomingChallenges.isNotEmpty) ...[
              SectionHeader(
                title: 'Incoming Challenges',
                icon: Icons.call_received,
              ),
              const SizedBox(height: 12),
              _buildChallengesList(incomingChallenges, isIncoming: true),
              const SizedBox(height: 24),
            ],
            if (outgoingChallenges.isNotEmpty) ...[
              SectionHeader(
                title: 'Outgoing Challenges',
                icon: Icons.call_made,
              ),
              const SizedBox(height: 12),
              _buildChallengesList(outgoingChallenges, isIncoming: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesList(
    List<ChallengeModel> challenges, {
    required bool isIncoming,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: challenges.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        final isProcessing = processingChallenges.contains(challenge.id);

        return ChallengeCard(
          challenge: challenge,
          isIncoming: isIncoming,
          isProcessing: isProcessing,
          onTap: () => _navigateToChallengeDetails(challenge),
          onAccept: isIncoming ? () => _acceptChallenge(challenge) : null,
          onDecline: isIncoming ? () => _declineChallenge(challenge) : null,
        );
      },
    );
  }

  void _navigateToCreateChallenge() {
    // Navigation logic
  }

  void _navigateToChallengeDetails(ChallengeModel challenge) {
    // Navigation logic
  }
}
```

## Example 3: Initializing the App with Service Locator

Update your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:frontend/core/di/service_locator.dart';
import 'package:frontend/screens/login_page.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection
  await ServiceLocator().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhelKood',
      theme: ThemeData.dark().copyWith(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const LoginPage(),
    );
  }
}
```

## Example 4: Creating a Custom Widget

```dart
import 'package:flutter/material.dart';
import '../../core/models/booking_model.dart';
import '../../core/constants/app_colors.dart';

/// Booking card widget - follows Single Responsibility Principle
class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildDetails(),
            if (onCancel != null && booking.isPending) ...[
              const SizedBox(height: 12),
              _buildCancelButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            booking.courtName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    if (booking.isConfirmed) {
      color = AppColors.success;
    } else if (booking.isPending) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        booking.status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      children: [
        _buildDetailRow(Icons.sports, booking.sport),
        const SizedBox(height: 8),
        _buildDetailRow(Icons.calendar_today, booking.formattedDate),
        const SizedBox(height: 8),
        _buildDetailRow(Icons.access_time, booking.timeRange),
        const SizedBox(height: 8),
        _buildDetailRow(
          Icons.monetization_on,
          '₹${booking.totalAmount}',
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.cancel, size: 18),
        label: const Text('Cancel Booking'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
```

## Benefits of This Approach

1. **Cleaner Code**: Less boilerplate, more readable
2. **Type Safety**: Compile-time error checking with models
3. **Reusability**: Widgets and logic can be reused
4. **Testability**: Easy to mock repositories for testing
5. **Maintainability**: Changes in one place don't affect others
6. **Scalability**: Easy to add new features

## Migration Checklist

- [ ] Initialize ServiceLocator in main.dart
- [ ] Replace direct HTTP calls with repository methods
- [ ] Replace Map<String, dynamic> with typed models
- [ ] Use reusable widgets instead of custom implementations
- [ ] Import constants instead of hardcoding values
- [ ] Add error handling with ErrorMessage widget
- [ ] Add loading states with LoadingIndicator widget
- [ ] Add empty states with EmptyState widget

