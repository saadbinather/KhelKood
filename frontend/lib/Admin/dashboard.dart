import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_page.dart';

/// ADMIN PAGES
/// - AdminDashboard
/// - PendingRegistrationsPage (+ UserDetailPage)

const String baseUrl = 'http://localhost:5000/api';

// Helper function to get auth token
Future<String?> _getAuthToken() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  } catch (e) {
    print('Error getting token: $e');
    return null;
  }
}

// Helper function to save auth token
Future<void> _saveAuthToken(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  } catch (e) {
    print('Error saving token: $e');
  }
}

class AdminDashboardEntry extends StatelessWidget {
  const AdminDashboardEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboard();
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  // Pink color theme
  static const Color pinkColor = Color(0xFFFF69B4); // Hot pink
  static const Color lightPink = Color(0xFFFFB6C1); // Light pink
  static const Color whiteColor = Colors.white;

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
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: pinkColor)),
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
      
      // Navigate to login page
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildEmojiBackground() {
    return Stack(
      children: List.generate(30, (index) {
        final emojis = ['💕', '💖', '💗', '💓', '💝', '💞', '💟', '❤️', '🧡', '💛'];
        final emoji = emojis[index % emojis.length];
        return Positioned(
          left: (index * 37.0) % 400,
          top: (index * 43.0) % 800,
          child: Opacity(
            opacity: 0.1,
            child: Text(
              emoji,
              style: TextStyle(fontSize: 30 + (index % 3) * 10),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteColor,
      appBar: AppBar(
        backgroundColor: pinkColor,
        elevation: 0,
        title: const Text(
          'Welcome, Pitah Jee 💕',
          style: TextStyle(
            color: whiteColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: whiteColor),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Emoji background
          _buildEmojiBackground(),
          // Main content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pending Registrations Card
                    _buildActionCard(
                      context,
                      title: 'Pending Registrations 💖',
                      subtitle: 'Approve players & court owners ✨',
                      icon: Icons.person_add,
                      emoji: '💕',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PendingRegistrationsPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String emoji,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [pinkColor, lightPink],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: pinkColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: whiteColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: whiteColor, size: 36),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: whiteColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: whiteColor.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: whiteColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// --------------------- PENDING REGISTRATIONS ---------------------
class PendingRegistrationsPage extends StatefulWidget {
  const PendingRegistrationsPage({super.key});

  @override
  State<PendingRegistrationsPage> createState() =>
      _PendingRegistrationsPageState();
}

class _PendingRegistrationsPageState extends State<PendingRegistrationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> pendingPlayers = [];
  List<Map<String, dynamic>> pendingOwners = [];

  static const Color pinkColor = Color(0xFFFF69B4);
  static const Color lightPink = Color(0xFFFFB6C1);
  static const Color whiteColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUnverifiedUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnverifiedUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          errorMessage = 'No authentication token found. Please login again.';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/user/unverified'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final users = List<Map<String, dynamic>>.from(data['data']['users'] ?? []);

        setState(() {
          // Separate users by role: "team" = players, "courtowner" = court owners
          pendingPlayers = users
              .where((user) => user['role'] == 'team')
              .map((user) {
                final createdAt = user['createdAt'];
                String dateStr = 'Unknown';
                if (createdAt != null) {
                  try {
                    if (createdAt is String) {
                      dateStr = createdAt.split('T')[0];
                    } else if (createdAt is Map && createdAt.containsKey('_seconds')) {
                      dateStr = DateTime.fromMillisecondsSinceEpoch(
                              createdAt['_seconds'] * 1000)
                          .toString()
                          .split(' ')[0];
                    } else if (createdAt is Map && createdAt.containsKey('seconds')) {
                      dateStr = DateTime.fromMillisecondsSinceEpoch(
                              createdAt['seconds'] * 1000)
                          .toString()
                          .split(' ')[0];
                    }
                  } catch (e) {
                    dateStr = 'Unknown';
                  }
                }
                return {
                  'id': user['id'],
                  'name': user['name'] ?? 'Unknown',
                  'email': user['email'] ?? '',
                  'role': 'player',
                  'registeredAt': dateStr,
                };
              })
              .toList();

          pendingOwners = users
              .where((user) => user['role'] == 'courtowner')
              .map((user) {
                final createdAt = user['createdAt'];
                String dateStr = 'Unknown';
                if (createdAt != null) {
                  try {
                    if (createdAt is String) {
                      dateStr = createdAt.split('T')[0];
                    } else if (createdAt is Map && createdAt.containsKey('_seconds')) {
                      dateStr = DateTime.fromMillisecondsSinceEpoch(
                              createdAt['_seconds'] * 1000)
                          .toString()
                          .split(' ')[0];
                    } else if (createdAt is Map && createdAt.containsKey('seconds')) {
                      dateStr = DateTime.fromMillisecondsSinceEpoch(
                              createdAt['seconds'] * 1000)
                          .toString()
                          .split(' ')[0];
                    }
                  } catch (e) {
                    dateStr = 'Unknown';
                  }
                }
                return {
                  'id': user['id'],
                  'name': user['name'] ?? 'Unknown',
                  'email': user['email'] ?? '',
                  'role': 'courtOwner',
                  'registeredAt': dateStr,
                };
              })
              .toList();

          isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Failed to fetch unverified users';
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

  Future<void> _approveUser(Map<String, dynamic> user) async {
    final id = user['id'];
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Approving... 💕'),
        backgroundColor: pinkColor,
      ),
    );

    try {
      final token = await _getAuthToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/admin/verify-user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userDocId': id}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          if (user['role'] == 'player') {
            pendingPlayers.removeWhere((u) => u['id'] == id);
          } else {
            pendingOwners.removeWhere((u) => u['id'] == id);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${user['name']} verified successfully! 💖'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to verify user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectUser(Map<String, dynamic> user) async {
    final id = user['id'];
    final reasonController = TextEditingController();

    // Show confirmation dialog with optional reason
    final rejectionReason = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: whiteColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject User 💔', style: TextStyle(color: pinkColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject ${user['name']}?',
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Optional reason (e.g., incomplete documents)',
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: pinkColor.withOpacity(0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: const BorderSide(color: pinkColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Reject', style: TextStyle(color: pinkColor)),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (rejectionReason == null) return;
    final reason = rejectionReason.isEmpty
        ? 'Rejected by admin'
        : rejectionReason;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rejecting... 💔'),
        backgroundColor: pinkColor,
      ),
    );

    try {
      final token = await _getAuthToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/admin/reject-user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userDocId': id, 'reason': reason}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          if (user['role'] == 'player') {
            pendingPlayers.removeWhere((u) => u['id'] == id);
          } else {
            pendingOwners.removeWhere((u) => u['id'] == id);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${user['name']} 💔'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to reject user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailPage(
          user: user,
          onApprove: () => _approveUser(user),
          onReject: () => _rejectUser(user),
        ),
      ),
    );
  }

  Widget _buildEmojiBackground() {
    return Stack(
      children: List.generate(25, (index) {
        final emojis = ['💕', '💖', '💗', '💓', '💝', '💞', '💟', '❤️', '🧡', '💛', '✨', '🌟'];
        final emoji = emojis[index % emojis.length];
        return Positioned(
          left: (index * 47.0) % 400,
          top: (index * 53.0) % 800,
          child: Opacity(
            opacity: 0.08,
            child: Text(
              emoji,
              style: TextStyle(fontSize: 25 + (index % 4) * 8),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteColor,
      appBar: AppBar(
        backgroundColor: pinkColor,
        elevation: 0,
        title: const Text(
          'Pending Registrations 💕',
          style: TextStyle(
            color: whiteColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: whiteColor),
            onPressed: _fetchUnverifiedUsers,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: whiteColor,
          labelColor: whiteColor,
          unselectedLabelColor: whiteColor.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Players 👥'),
            Tab(text: 'Court Owners 🏢'),
          ],
        ),
      ),
      body: Stack(
        children: [
          _buildEmojiBackground(),
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: pinkColor),
                )
              : errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            errorMessage!,
                            style: const TextStyle(color: pinkColor),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchUnverifiedUsers,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pinkColor,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(pendingPlayers, 'No pending players 💕'),
                        _buildList(pendingOwners, 'No pending court owners 💕'),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> data, String emptyMessage) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '💕',
              style: TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: pinkColor,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final user = data[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pinkColor.withOpacity(0.1), lightPink.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pinkColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pinkColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, color: pinkColor, size: 28),
            ),
            title: Text(
              user['name'],
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${user['email']} • ${user['registeredAt']}',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.check, color: whiteColor),
                    onPressed: () => _approveUser(user),
                    tooltip: 'Approve',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: whiteColor),
                    onPressed: () => _rejectUser(user),
                    tooltip: 'Reject',
                  ),
                ),
              ],
            ),
            onTap: () => _openDetail(user),
          ),
        );
      },
    );
  }
}

class UserDetailPage extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  static const Color pinkColor = Color(0xFFFF69B4);
  static const Color lightPink = Color(0xFFFFB6C1);
  static const Color whiteColor = Colors.white;

  const UserDetailPage({
    super.key,
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final id = user['id'];
    final name = user['name'];
    final email = user['email'];
    final role = user['role'];

    return Scaffold(
      backgroundColor: whiteColor,
      appBar: AppBar(
        backgroundColor: pinkColor,
        elevation: 0,
        title: const Text(
          'User Detail 💕',
          style: TextStyle(color: whiteColor),
        ),
      ),
      body: Stack(
        children: [
          // Emoji background
          Stack(
            children: List.generate(15, (index) {
              final emojis = ['💕', '💖', '💗', '💓', '💝'];
              final emoji = emojis[index % emojis.length];
              return Positioned(
                left: (index * 50.0) % 400,
                top: (index * 60.0) % 800,
                child: Opacity(
                  opacity: 0.05,
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: 40 + (index % 3) * 15),
                  ),
                ),
              );
            }),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [pinkColor, lightPink],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: whiteColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('ID', id),
                      const SizedBox(height: 8),
                      _buildDetailRow('Email', email),
                      const SizedBox(height: 8),
                      _buildDetailRow('Role', role.toString()),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Approve 💖',
                          style: TextStyle(
                            color: whiteColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onReject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Reject 💔',
                          style: TextStyle(
                            color: whiteColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: whiteColor.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: whiteColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
