import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import 'leaderboard_page.dart';
import 'challenges_page.dart';
import 'create_booking_or_challenge_page.dart';
import 'all_courts_page.dart';
import 'view_all_teams.dart';
import 'match_history_page.dart';
import 'booking_history_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? teamData;
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> verifiedCourts = [];
  bool isLoadingCourts = false;
  List<Map<String, dynamic>> topTeams = [];
  bool isLoadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _fetchTeamDetails();
    _fetchVerifiedCourts();
    _fetchTopTeams();
  }

  Future<void> _fetchVerifiedCourts() async {
    setState(() {
      isLoadingCourts = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          isLoadingCourts = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/courts/verified'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        setState(() {
          verifiedCourts = List<Map<String, dynamic>>.from(
            data['data']?['courts'] ?? data['courts'] ?? [],
          );
          isLoadingCourts = false;
        });
      } else {
        setState(() {
          isLoadingCourts = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingCourts = false;
      });
    }
  }

  Future<void> _fetchTopTeams() async {
    setState(() {
      isLoadingLeaderboard = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          isLoadingLeaderboard = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/leaderboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final allTeams = List<Map<String, dynamic>>.from(
          data['data']?['teams'] ?? data['teams'] ?? [],
        );
        setState(() {
          // Get top 3 teams (already sorted by points descending from API)
          topTeams = allTeams.take(3).toList();
          isLoadingLeaderboard = false;
        });
      } else {
        setState(() {
          isLoadingLeaderboard = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingLeaderboard = false;
      });
    }
  }

  Future<void> _fetchTeamDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          errorMessage = 'No authentication token found';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/team/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        setState(() {
          teamData = data['data']?['team'] ?? data['team'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load team details';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
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
            Uri.parse('http://localhost:5000/api/auth/logout'),
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

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(
              isSmallScreen
                  ? 16.0
                  : isTablet
                  ? 24.0
                  : 20.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(
                    isSmallScreen
                        ? 12
                        : isTablet
                        ? 18
                        : 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen
                        ? 32
                        : isTablet
                        ? 48
                        : 40,
                    color: Colors.redAccent,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen
                        ? 16
                        : isTablet
                        ? 20
                        : 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmallScreen ? 6 : 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInfoCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    if (teamData == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showProfileBottomSheet(context),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.group,
                        color: Colors.redAccent,
                        size: isSmallScreen ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamData!['teamName'] ?? 'Unknown Team',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 18 : 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 4 : 6),
                          Text(
                            teamData!['sports'] != null &&
                                    teamData!['sports'].toString().isNotEmpty
                                ? teamData!['sports'].toString().toUpperCase()
                                : 'No Sport',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.redAccent,
                      size: isSmallScreen ? 16 : 18,
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                _buildInfoRow(
                  Icons.email,
                  'Email',
                  teamData!['email'] ?? 'N/A',
                ),
                SizedBox(height: isSmallScreen ? 10 : 12),
                _buildInfoRow(
                  Icons.phone,
                  'Phone',
                  teamData!['phone'] ?? 'N/A',
                ),
                SizedBox(height: isSmallScreen ? 10 : 12),
                Row(
                  children: [
                    Icon(
                      Icons.stars,
                      color: Colors.redAccent,
                      size: isSmallScreen ? 18 : 20,
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Text(
                      'Points: ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                    ),
                    Text(
                      '${teamData!['points'] ?? 0}',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (teamData!['players'] != null &&
                    (teamData!['players'] as List).isNotEmpty) ...[
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Divider(color: Colors.white24),
                  SizedBox(height: isSmallScreen ? 10 : 12),
                  Text(
                    'Players',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 10),
                  Wrap(
                    spacing: isSmallScreen ? 6 : 8,
                    runSpacing: isSmallScreen ? 6 : 8,
                    children: (teamData!['players'] as List)
                        .take(3)
                        .map<Widget>((player) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 10 : 12,
                              vertical: isSmallScreen ? 5 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              player.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                  if ((teamData!['players'] as List).length > 3)
                    Padding(
                      padding: EdgeInsets.only(top: isSmallScreen ? 6 : 8),
                      child: Text(
                        '+${(teamData!['players'] as List).length - 3} more',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: isSmallScreen ? 11 : 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.redAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateChallengeButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const CreateBookingOrChallengePage(actionType: 'challenge'),
            ),
          );
          // Refresh courts if challenge was created successfully
          if (result == true) {
            _fetchVerifiedCourts();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        icon: Icon(
          Icons.add_circle_outline,
          color: Colors.white,
          size: isSmallScreen ? 18 : 20,
        ),
        label: Text(
          'Create New Challenge',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTopLeaderboardSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LeaderboardPage()),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: Colors.redAccent,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Text(
                          'Top Teams',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.redAccent,
                      size: isSmallScreen ? 16 : 18,
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                if (isLoadingLeaderboard)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      child: const CircularProgressIndicator(
                        color: Colors.redAccent,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (topTeams.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      child: Text(
                        'No teams available',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                  )
                else
                  ...topTeams.asMap().entries.map((entry) {
                    final index = entry.key;
                    final team = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < topTeams.length - 1
                            ? (isSmallScreen ? 10 : 12)
                            : 0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: isSmallScreen ? 28 : 32,
                            height: isSmallScreen ? 28 : 32,
                            decoration: BoxDecoration(
                              color: index == 0
                                  ? Colors.amber.withOpacity(0.3)
                                  : index == 1
                                  ? Colors.grey[700]!.withOpacity(0.3)
                                  : Colors.brown.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 10 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team['teamName'] ?? 'Unknown',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isSmallScreen ? 2 : 4),
                                Text(
                                  team['sports']?.toString().toUpperCase() ??
                                      '',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: isSmallScreen ? 11 : 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.stars,
                                color: Colors.amber,
                                size: isSmallScreen ? 16 : 18,
                              ),
                              SizedBox(width: isSmallScreen ? 4 : 6),
                              Text(
                                '${team['points'] ?? 0}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileBottomSheet(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen
        ? 16.0
        : isTablet
        ? 32.0
        : 24.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                children: [
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.redAccent,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          SizedBox(width: isSmallScreen ? 8 : 12),
                          Text(
                            'Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: Colors.redAccent,
                              size: isSmallScreen ? 20 : 24,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditDialog();
                            },
                            tooltip: 'Edit Profile',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.white70,
                              size: isSmallScreen ? 20 : 24,
                            ),
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.group,
                        color: Colors.redAccent,
                        size: isSmallScreen ? 50 : 60,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    Text(
                      teamData!['teamName']?.toString() ?? 'Team',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        teamData!['sports']?.toString().toUpperCase() ?? 'N/A',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 24 : 32),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.email_outlined,
                              'Email',
                              teamData!['email'] ?? 'N/A',
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            _buildInfoRow(
                              Icons.phone_outlined,
                              'Phone',
                              teamData!['phone'] ?? 'N/A',
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            _buildInfoRow(
                              Icons.sports_soccer,
                              'Sport',
                              teamData!['sports'] ?? 'N/A',
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            _buildInfoRow(
                              Icons.stars,
                              'Points',
                              (teamData!['points'] ?? 0).toString(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MatchHistoryPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.history,
                                      color: Colors.redAccent,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                    SizedBox(width: isSmallScreen ? 12 : 16),
                                    Text(
                                      'Match History',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white54,
                                  size: isSmallScreen ? 14 : 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BookingHistoryPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.history,
                                      color: Colors.redAccent,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                    SizedBox(width: isSmallScreen ? 12 : 16),
                                    Text(
                                      'Booking History',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white54,
                                  size: isSmallScreen ? 14 : 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    if (teamData!['players'] != null &&
                        (teamData!['players'] as List).isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        color: Colors.redAccent,
                                        size: isSmallScreen ? 20 : 24,
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 12),
                                      Text(
                                        'Players',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: isSmallScreen ? 12 : 16),
                              Divider(color: Colors.white24),
                              SizedBox(height: isSmallScreen ? 12 : 16),
                              Wrap(
                                spacing: isSmallScreen ? 8 : 10,
                                runSpacing: isSmallScreen ? 8 : 10,
                                children: (teamData!['players'] as List)
                                    .map<Widget>((player) {
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 12 : 14,
                                          vertical: isSmallScreen ? 6 : 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(
                                            0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.redAccent.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          player.toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isSmallScreen ? 13 : 14,
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    final TextEditingController teamNameController = TextEditingController(
      text: teamData!['teamName'] ?? '',
    );
    final TextEditingController phoneController = TextEditingController(
      text: teamData!['phone'] ?? '',
    );
    final TextEditingController emailController = TextEditingController(
      text: teamData!['email'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Text(
              "Edit Profile",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: teamNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Team Name",
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: Icon(
                    Icons.flag_outlined,
                    color: Colors.redAccent.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: Colors.redAccent.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Phone",
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    color: Colors.redAccent.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _updateProfile(
                teamNameController.text.trim(),
                emailController.text.trim(),
                phoneController.text.trim(),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile(
    String teamName,
    String email,
    String phone,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No authentication token found'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final response = await http.put(
        Uri.parse('http://localhost:5000/api/team/edit-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'teamName': teamName,
          'email': email,
          'phone': phone,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchTeamDetails();
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['error']?.toString() ?? 'Failed to update profile',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen
        ? 12.0
        : isTablet
        ? 24.0
        : 20.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          teamData?['teamName']?.toString() ?? 'Player Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 18 : 20,
          ),
        ),
        centerTitle: true,
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchTeamDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Row(
                      children: [
                        Icon(
                          Icons.waving_hand,
                          color: Colors.redAccent,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Expanded(
                          child: Text(
                            'Welcome, ${teamData?['teamName'] ?? 'Player'}!',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: isSmallScreen ? 18 : 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 8),
                    Text(
                      'What would you like to do today?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildTeamInfoCard(),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildTopLeaderboardSection(),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildCreateChallengeButton(),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85,
                      children: [
                        _buildDashboardCard(
                          context: context,
                          title: 'Challenges',
                          subtitle: 'View & accept challenges',
                          icon: Icons.sports_mma,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChallengesPage(),
                              ),
                            );
                          },
                        ),
                        _buildDashboardCard(
                          context: context,
                          title: 'Book a court for yourself',
                          subtitle: 'Friendly match',
                          icon: Icons.calendar_today,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CreateBookingOrChallengePage(
                                      actionType: 'booking',
                                    ),
                              ),
                            );
                          },
                        ),
                        _buildDashboardCard(
                          context: context,
                          title: 'All Courts',
                          subtitle: 'Browse and review courts',
                          icon: Icons.sports_soccer,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AllCourtsPage(),
                              ),
                            );
                          },
                        ),
                        _buildDashboardCard(
                          context: context,
                          title: 'All Teams',
                          subtitle: 'View teams in your sport',
                          icon: Icons.groups,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ViewAllTeamsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
