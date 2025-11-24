import 'package:flutter/material.dart';

/// ADMIN PAGES (single-file demo)
/// - AdminDashboard
/// - PendingRegistrationsPage (+ UserDetailPage)
/// - PendingCourtsPage (+ CourtDetailPage)
/// - ManageBlocksPage
///
/// Replace dummy data with real API calls where TODO comments are placed.

class AdminDashboardEntry extends StatelessWidget {
  const AdminDashboardEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboard();
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

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

  // Dummy data: replace with API-loaded lists
  List<Map<String, dynamic>> pendingPlayers = [
    {
      "id": "P001",
      "name": "Ali Khan",
      "email": "ali@example.com",
      "role": "player",
      "registeredAt": "2025-11-22",
    },
    {
      "id": "P002",
      "name": "Sara Ahmed",
      "email": "sara@example.com",
      "role": "player",
      "registeredAt": "2025-11-23",
    },
  ];

  List<Map<String, dynamic>> pendingOwners = [
    {
      "id": "O001",
      "name": "Zee Sports",
      "email": "owner1@zee.com",
      "role": "courtOwner",
      "registeredAt": "2025-11-22",
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // TODO: Replace dummy lists by calling API to fetch pending registrations
  }

  Future<void> _approveUser(Map<String, dynamic> user) async {
    // Simulate API call
    final id = user['id'];
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Approving...'),
        backgroundColor: Colors.blue,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      if (user['role'] == 'player') {
        pendingPlayers.removeWhere((u) => u['id'] == id);
      } else {
        pendingOwners.removeWhere((u) => u['id'] == id);
      }
    });

    // TODO: Replace the above with:
    // await api.approveUser(userId: id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Approved $id'), backgroundColor: Colors.green),
    );
  }

  Future<void> _rejectUser(Map<String, dynamic> user) async {
    final id = user['id'];
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rejecting...'),
        backgroundColor: Colors.blue,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      if (user['role'] == 'player') {
        pendingPlayers.removeWhere((u) => u['id'] == id);
      } else {
        pendingOwners.removeWhere((u) => u['id'] == id);
      }
    });

    // TODO: api.rejectUser(userId: id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rejected $id'), backgroundColor: Colors.red),
    );
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Players'),
            Tab(text: 'Court Owners'),
          ],
        ),
      ),
      body: TabBarView(
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
