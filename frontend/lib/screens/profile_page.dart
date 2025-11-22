import 'package:flutter/material.dart';
import 'booking_history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool showEditText = false;
  bool showViewText = false;

  final Map<String, dynamic> user = {
    'createdAt': 'November 7, 2025 at 9:39:31 PM UTC+5',
    'email': 'ali.teamfreaks@khelkood.com',
    'phone': '0333-111453453',
    'points': 42,
    'players': ['Ali', 'Usman', 'Ahmed', 'Raza'],
    'sports': 'Futsal',
    'teamName': 'Team Freaks',
    'userId': 'HPOa5RRnxhQAMHV50PVrzDDeMjn1',
  };

  final TextEditingController teamNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    teamNameController.text = user['teamName'];
    phoneController.text = user['phone'];
  }

  @override
  void dispose() {
    teamNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Row(
            children: [
              // Edit Profile Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => showEditText = true),
                onExit: (_) => setState(() => showEditText = false),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                        _showEditDialog();
                      },
                    ),
                    if (showEditText)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Text(
                          "Edit",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),

              // View Booking History Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => showViewText = true),
                onExit: (_) => setState(() => showViewText = false),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookingHistoryPage(),
                          ),
                        );
                      },
                    ),
                    if (showViewText)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Text(
                          "View History",
                          style:
                              TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 55,
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.person, size: 70, color: Colors.white),
              ),
              const SizedBox(height: 20),

              // Team Name
              Text(
                user['teamName'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Info Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      profileRow(Icons.email, "Email", user['email']),
                      profileRow(Icons.phone, "Phone", user['phone']),
                      profileRow(Icons.sports_soccer, "Sport", user['sports']),
                      profileRow(Icons.star, "Points", user['points'].toString()),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Player List
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Players",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.deepPurple),
                            onPressed: () {
                              _showAddPlayerDialog();
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      for (int i = 0; i < user['players'].length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person,
                                      color: Colors.deepPurple),
                                  const SizedBox(width: 10),
                                  Text(user['players'][i],
                                      style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    user['players'].removeAt(i);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget profileRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$title: $value",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: teamNameController,
              decoration: const InputDecoration(labelText: "Team Name"),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone Number"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  user['teamName'] = teamNameController.text;
                  user['phone'] = phoneController.text;
                });
                Navigator.pop(context);
              },
              child: const Text("Save")),
        ],
      ),
    );
  }

  void _showAddPlayerDialog() {
    TextEditingController playerController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Player"),
        content: TextField(
          controller: playerController,
          decoration: const InputDecoration(labelText: "Player Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  user['players'].add(playerController.text);
                });
                Navigator.pop(context);
              },
              child: const Text("Add")),
        ],
      ),
    );
  }
}
