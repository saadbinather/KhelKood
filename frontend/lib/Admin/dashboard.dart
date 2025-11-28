import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_page.dart';

/// ADMIN PAGES (single-file demo)
/// - AdminDashboard
/// - PendingRegistrationsPage (+ UserDetailPage)
/// - PendingCourtsPage (+ CourtDetailPage)
/// - ManageBlocksPage

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
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Welcome, Admin',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),

            // Cards/Quick actions
            _actionCard(
              context,
              title: 'Pending Registrations',
              subtitle: 'Approve players & court owners',
              icon: Icons.person_add,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PendingRegistrationsPage(),
                ),
              ),
            ),

            _actionCard(
              context,
              title: 'Pending Courts',
              subtitle: 'Approve newly created courts',
              icon: Icons.sports_soccer,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PendingCourtsPage()),
              ),
            ),

            _actionCard(
              context,
              title: 'Manage Blocks',
              subtitle: 'Block / Unblock teams and court owners',
              icon: Icons.block,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageBlocksPage()),
              ),
            ),

            const Spacer(),

            // small footer
            const Text(
              'KhelKood Admin Panel',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[900],
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUnverifiedUsers();
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
      const SnackBar(
        content: Text('Approving...'),
        backgroundColor: Colors.blue,
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
            content: Text('User ${user['name']} verified successfully'),
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
        backgroundColor: Colors.grey[900],
        title: const Text('Reject User', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject ${user['name']}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Optional reason (e.g., incomplete documents)',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            child:
                const Text('Reject', style: TextStyle(color: Colors.redAccent)),
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
        content: Text('Rejecting...'),
        backgroundColor: Colors.blue,
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
            content: Text('Rejected ${user['name']}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text(
          'Pending Registrations',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchUnverifiedUsers,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Players'),
            Tab(text: 'Court Owners'),
          ],
        ),
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
                        onPressed: _fetchUnverifiedUsers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(pendingPlayers, 'No pending players'),
                    _buildList(pendingOwners, 'No pending court owners'),
                  ],
                ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> data, String emptyMessage) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final user = data[i];
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(
              user['name'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${user['email']} • ${user['registeredAt']}',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _approveUser(user),
                  tooltip: 'Approve',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () => _rejectUser(user),
                  tooltip: 'Reject',
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text('User Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('ID: $id', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              'Email: $email',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Role: ${role.toString()}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            // TODO: show additional details (CNIC, phone, uploaded docs)
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// --------------------- PENDING COURTS ---------------------
class PendingCourtsPage extends StatefulWidget {
  const PendingCourtsPage({super.key});

  @override
  State<PendingCourtsPage> createState() => _PendingCourtsPageState();
}

class _PendingCourtsPageState extends State<PendingCourtsPage> {
  // Dummy data - replace with API
  List<Map<String, dynamic>> pendingCourts = [
    {
      "id": "C100",
      "name": "Zee Sports Complex",
      "location": "Model Town",
      "sport": "futsal",
      "rate": 2000,
      "ownerName": "Zee Sports",
      "createdAt": "2025-11-23",
    },
    {
      "id": "C101",
      "name": "Urban Arena",
      "location": "Downtown",
      "sport": "basketball",
      "rate": 1500,
      "ownerName": "Urban Owner",
      "createdAt": "2025-11-22",
    },
  ];

  Future<void> _approveCourt(Map<String, dynamic> court) async {
    final id = court['id'];
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Approving court...')));
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => pendingCourts.removeWhere((c) => c['id'] == id));
    // TODO: call api.approveCourt(courtId: id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Approved $id'), backgroundColor: Colors.green),
    );
  }

  Future<void> _rejectCourt(Map<String, dynamic> court) async {
    final id = court['id'];
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rejecting court...')));
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => pendingCourts.removeWhere((c) => c['id'] == id));
    // TODO: call api.rejectCourt(courtId: id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rejected $id'), backgroundColor: Colors.red),
    );
  }

  void _openCourtDetail(Map<String, dynamic> court) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourtDetailPage(
          court: court,
          onApprove: () => _approveCourt(court),
          onReject: () => _rejectCourt(court),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text('Pending Courts'),
      ),
      body: pendingCourts.isEmpty
          ? const Center(
              child: Text(
                'No courts pending approval',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pendingCourts.length,
              itemBuilder: (_, i) {
                final court = pendingCourts[i];
                return Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                      court['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${court['location']} • ${court['sport']} • Rs ${court['rate']}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _approveCourt(court),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _rejectCourt(court),
                        ),
                      ],
                    ),
                    onTap: () => _openCourtDetail(court),
                  ),
                );
              },
            ),
    );
  }
}

class CourtDetailPage extends StatelessWidget {
  final Map<String, dynamic> court;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const CourtDetailPage({
    super.key,
    required this.court,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text('Court Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              court['name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${court['location']}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Sport: ${court['sport']}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Rate: Rs ${court['rate']}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              'Owner: ${court['ownerName']}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            // TODO: Show images, facilities, documents etc.
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// --------------------- MANAGE BLOCKS ---------------------
class ManageBlocksPage extends StatefulWidget {
  const ManageBlocksPage({super.key});

  @override
  State<ManageBlocksPage> createState() => _ManageBlocksPageState();
}

class _ManageBlocksPageState extends State<ManageBlocksPage> {
  // Dummy data: teams and owners (status: active/blocked)
  List<Map<String, dynamic>> teams = [
    {"id": "T100", "name": "Red Tigers", "status": "active"},
    {"id": "T101", "name": "Blue Sharks", "status": "blocked"},
  ];

  List<Map<String, dynamic>> owners = [
    {"id": "O200", "name": "Zee Sports", "status": "active"},
    {"id": "O201", "name": "Urban Owner", "status": "active"},
  ];

  Future<void> _toggleBlock(Map<String, dynamic> item, bool isTeam) async {
    final id = item['id'];
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Updating...')));
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      final list = isTeam ? teams : owners;
      final idx = list.indexWhere((x) => x['id'] == id);
      if (idx != -1) {
        list[idx]['status'] = list[idx]['status'] == 'active'
            ? 'blocked'
            : 'active';
      }
    });

    // TODO: call api.blockUser(id) or api.unblockUser(id)
    final newStatus = item['status'] == 'active' ? 'blocked' : 'active';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$id is now $newStatus'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, bool isTeam) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final blocked = item['status'] == 'blocked';
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(
              item['name'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'ID: ${item['id']}',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: ElevatedButton(
              onPressed: () => _toggleBlock(item, isTeam),
              style: ElevatedButton.styleFrom(
                backgroundColor: blocked ? Colors.green : Colors.redAccent,
              ),
              child: Text(blocked ? 'Unblock' : 'Block'),
            ),
          ),
        );
      },
    );
  }

  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text('Manage Blocks'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          ToggleButtons(
            borderRadius: BorderRadius.circular(10),
            isSelected: [_currentTab == 0, _currentTab == 1],
            onPressed: (idx) => setState(() => _currentTab = idx),
            color: Colors.white70,
            selectedColor: Colors.white,
            fillColor: Colors.redAccent.withOpacity(0.2),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Text('Teams'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Text('Court Owners'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _currentTab == 0
                ? _buildList(teams, true)
                : _buildList(owners, false),
          ),
        ],
      ),
    );
  }
}
