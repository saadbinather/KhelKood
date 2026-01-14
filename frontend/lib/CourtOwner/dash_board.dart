import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../screens/login_page.dart';
import '../core/constants/app_constants.dart';
import 'court_management_page.dart';
import 'booking_management_page.dart';
import 'feedback.dart'; // Court Feedback Page
import 'payments.dart'; // Payments Page
import 'profile_settings_page.dart';

class CourtOwnerDashboard extends StatefulWidget {
  const CourtOwnerDashboard({super.key});

  @override
  State<CourtOwnerDashboard> createState() => _CourtOwnerDashboardState();
}

class _CourtOwnerDashboardState extends State<CourtOwnerDashboard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showWelcomeMessage = true;
  Timer? _welcomeTimer;

  // Stats data
  int _activeCourtsCount = 0;
  int _upcomingBookingsCount = 0;
  bool _isLoadingStats = true;
  String? _courtName;

  @override
  void initState() {
    super.initState();

    // Fade animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Slide animation controller
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Hide welcome message after 2 seconds
    _welcomeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showWelcomeMessage = false;
        });
      }
    });

    // Fetch stats data
    _fetchStats();
  }

  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
          });
        }
        return;
      }

      // Fetch courts and bookings in parallel
      await Future.wait([
        _fetchActiveCourts(token),
        _fetchUpcomingBookings(token),
        _fetchCourtName(token),
      ]);
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _fetchCourtName(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/courtowner/my-court'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final court = data['data']?['court'] ?? data['court'];
        final name = court != null
            ? (court['name'] ?? court['courtTitle'])
            : null;

        setState(() {
          _courtName = (name is String && name.trim().isNotEmpty)
              ? name.trim()
              : _courtName;
        });
      }
    } catch (e) {
      // Ignore errors here; title will fall back to default
    }
  }

  Future<void> _fetchActiveCourts(String token) async {
    try {
      // Fetch courts and bookings in parallel
      final courtsResponse = await http.get(
        Uri.parse('${AppConstants.baseUrl}/courtowner/courts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final bookingsResponse = await http.get(
        Uri.parse('${AppConstants.baseUrl}/courtowner/bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (mounted && courtsResponse.statusCode == 200) {
        final courtsData = jsonDecode(courtsResponse.body);
        final courts = courtsData['data']?['courts'] ?? [];

        // Calculate total number of courts (sum of all fields)
        int totalCourts = 0;
        for (var court in courts) {
          totalCourts += (court['numOfCricketFields'] ?? 0) as int;
          totalCourts += (court['numOfFutsalFields'] ?? 0) as int;
          totalCourts += (court['numOfPadelCourts'] ?? 0) as int;
        }

        // Count unavailable courts for today
        int unavailableToday = 0;
        if (bookingsResponse.statusCode == 200) {
          final bookingsData = jsonDecode(bookingsResponse.body);
          final allBookings = <Map<String, dynamic>>[];

          // Collect all bookings from all categories
          final incoming = bookingsData['data']?['incoming'] ?? [];
          final upcoming = bookingsData['data']?['upcoming'] ?? [];
          final past = bookingsData['data']?['past'] ?? [];

          allBookings.addAll(List<Map<String, dynamic>>.from(incoming));
          allBookings.addAll(List<Map<String, dynamic>>.from(upcoming));
          allBookings.addAll(List<Map<String, dynamic>>.from(past));

          // Get today's date
          final now = DateTime.now();

          // Track unique unavailable court numbers for today
          final unavailableCourtNumbers = <String>{};

          for (var booking in allBookings) {
            // Check if booking is marked as unavailable
            if (booking['isUnavailable'] == true) {
              // Parse start time
              DateTime? startTime;
              try {
                final startTimeData = booking['startTime'];
                if (startTimeData is Map) {
                  if (startTimeData.containsKey('_seconds')) {
                    startTime = DateTime.fromMillisecondsSinceEpoch(
                      startTimeData['_seconds'] * 1000,
                    );
                  } else if (startTimeData.containsKey('seconds')) {
                    startTime = DateTime.fromMillisecondsSinceEpoch(
                      startTimeData['seconds'] * 1000,
                    );
                  }
                } else if (startTimeData is String) {
                  startTime = DateTime.parse(startTimeData);
                }

                // Check if unavailable booking is for today (same year, month, day)
                if (startTime != null &&
                    startTime.year == now.year &&
                    startTime.month == now.month &&
                    startTime.day == now.day) {
                  // Create unique key: courtID + courtNum
                  final courtID = booking['courtID']?.toString() ?? '';
                  final courtNum = booking['courtNum']?.toString() ?? '';
                  unavailableCourtNumbers.add('$courtID-$courtNum');
                }
              } catch (e) {
                // Skip if date parsing fails
                continue;
              }
            }
          }

          unavailableToday = unavailableCourtNumbers.length;
        }

        // Active courts = total courts - unavailable today
        final activeCount = totalCourts - unavailableToday;

        if (mounted) {
          setState(() {
            _activeCourtsCount = activeCount > 0 ? activeCount : 0;
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _fetchUpcomingBookings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/courtowner/bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bookingsData = data['data'] ?? {};

        // Count upcoming bookings
        final upcoming = bookingsData['upcoming'] ?? [];
        final incoming = bookingsData['incoming'] ?? [];

        if (mounted) {
          setState(() {
            _upcomingBookingsCount = (upcoming.length + incoming.length);
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _welcomeTimer?.cancel();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Call logout endpoint
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (token != null) {
          await http.post(
            Uri.parse('${AppConstants.baseUrl}/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        }

        // Clear local token
        await prefs.remove('auth_token');
      } catch (e) {
        // Even if API call fails, clear local token
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
      }

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final padding = isSmallScreen
        ? 12.0
        : isTablet
        ? 24.0
        : 16.0;
    final titleFontSize = isSmallScreen
        ? 18.0
        : isTablet
        ? 24.0
        : 20.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showWelcomeMessage
              ? Text(
                  "Welcome Back!",
                  key: const ValueKey('welcome'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Text(
                  _courtName ?? "Court Owner",
                  key: const ValueKey('courtowner'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick stats section
              _buildQuickStats(),

              SizedBox(
                height: isSmallScreen
                    ? 12
                    : isTablet
                    ? 20
                    : 16,
              ),

              // Dashboard buttons with staggered animations
              _buildAnimatedButton(
                index: 0,
                title: "Manage Courts",
                icon: Icons.sports_tennis,
                color: Colors.redAccent,
                gradient: const LinearGradient(
                  colors: [Colors.redAccent, Colors.deepOrange],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CourtManagementPage(),
                    ),
                  );
                },
              ),

              SizedBox(
                height: isSmallScreen
                    ? 8
                    : isTablet
                    ? 16
                    : 12,
              ),

              _buildAnimatedButton(
                index: 1,
                title: "Booking Management",
                icon: Icons.calendar_today,
                color: Colors.redAccent,
                gradient: const LinearGradient(
                  colors: [Colors.redAccent, Colors.deepOrange],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookingManagementPage(),
                    ),
                  );
                },
              ),

              SizedBox(
                height: isSmallScreen
                    ? 8
                    : isTablet
                    ? 16
                    : 12,
              ),

              _buildAnimatedButton(
                index: 2,
                title: "View Feedback",
                icon: Icons.feedback,
                color: Colors.redAccent,
                gradient: const LinearGradient(
                  colors: [Colors.redAccent, Colors.deepOrange],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CourtFeedbackPage(),
                    ),
                  );
                },
              ),

              SizedBox(
                height: isSmallScreen
                    ? 8
                    : isTablet
                    ? 16
                    : 12,
              ),

              _buildAnimatedButton(
                index: 3,
                title: "Payments",
                icon: Icons.payments,
                color: Colors.redAccent,
                gradient: const LinearGradient(
                  colors: [Colors.redAccent, Colors.deepOrange],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PaymentsPage(),
                    ),
                  );
                },
              ),

              SizedBox(
                height: isSmallScreen
                    ? 8
                    : isTablet
                    ? 16
                    : 12,
              ),

              _buildAnimatedButton(
                index: 4,
                title: "Profile Settings",
                icon: Icons.settings,
                color: Colors.redAccent,
                gradient: const LinearGradient(
                  colors: [Colors.redAccent, Colors.deepOrange],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileSettingsPage(),
                    ),
                  );
                },
              ),

              SizedBox(
                height: isSmallScreen
                    ? 12
                    : isTablet
                    ? 20
                    : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.redAccent, Colors.deepOrange],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Court Owner",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Manage your courts efficiently",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final spacing = isSmallScreen ? 8.0 : 12.0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Active Courts",
            _isLoadingStats ? "..." : _activeCourtsCount.toString(),
            Icons.sports_tennis,
            Colors.redAccent,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildStatCard(
            "Upcoming Bookings",
            _isLoadingStats ? "..." : _upcomingBookingsCount.toString(),
            Icons.event,
            Colors.deepOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;

    return Container(
      padding: EdgeInsets.all(
        isSmallScreen
            ? 10
            : isTablet
            ? 16
            : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: isSmallScreen
                  ? 18
                  : isTablet
                  ? 24
                  : 20,
            ),
          ),
          SizedBox(
            height: isSmallScreen
                ? 6
                : isTablet
                ? 10
                : 8,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen
                  ? 18
                  : isTablet
                  ? 24
                  : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: isSmallScreen ? 1 : 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen
                  ? 10
                  : isTablet
                  ? 13
                  : 11,
              color: Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton({
    required int index,
    required String title,
    required IconData icon,
    required Color color,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: _DashboardButton(
              title: title,
              icon: icon,
              gradient: gradient,
              color: color,
              onTap: onTap,
            ),
          ),
        );
      },
    );
  }
}

class _DashboardButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final Color color;
  final VoidCallback onTap;

  const _DashboardButton({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.color,
    required this.onTap,
  });

  @override
  State<_DashboardButton> createState() => _DashboardButtonState();
}

class _DashboardButtonState extends State<_DashboardButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen
                      ? 12
                      : isTablet
                      ? 20
                      : 16,
                  horizontal: isSmallScreen
                      ? 12
                      : isTablet
                      ? 20
                      : 16,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        isSmallScreen
                            ? 8
                            : isTablet
                            ? 12
                            : 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: isSmallScreen
                            ? 20
                            : isTablet
                            ? 28
                            : 24,
                      ),
                    ),
                    SizedBox(
                      width: isSmallScreen
                          ? 10
                          : isTablet
                          ? 16
                          : 12,
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen
                              ? 14
                              : isTablet
                              ? 18
                              : 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
