import 'package:flutter/material.dart';

import 'view_challenge_page.dart';
import 'available_courts_page.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  // Mock JSON data (in real app, fetched via API)
  final List<Map<String, dynamic>> challenges = [
    {
      "Court_Name": "Urban Futsal Arena",
      "Host_Team_Name": "Street Wolves",
      "Sport": "futsal",
      "Status": "Pending",
      "Start_Time": "2025-11-09T18:30:00Z",
      "End_Time": "2025-11-09T19:30:00Z",
      "Date": "2025-11-09",
      "Total_Price": 5000,
      "Type": "Incoming",
    },
    {
      "Court_Name": "Downtown Hoops Court",
      "Host_Team_Name": "Sky Dunkers",
      "Sport": "basketball",
      "Status": "Pending",
      "Start_Time": "2025-11-11T20:00:00Z",
      "End_Time": "2025-11-11T21:30:00Z",
      "Date": "2025-11-11",
      "Total_Price": 7000,
      "Type": "Outgoing",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final incoming = challenges.where((c) => c["Type"] == "Incoming").toList();
    final outgoing = challenges.where((c) => c["Type"] == "Outgoing").toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Challenges',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Incoming Challenges',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...incoming.map((c) => _buildChallengeCard(c, isIncoming: true)),

            const SizedBox(height: 25),

            const Text(
              'Outgoing Challenges',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...outgoing.map((c) => _buildChallengeCard(c, isIncoming: false)),

            const SizedBox(height: 25),

            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AvailableCourtsPage(
                        actionType: "challenge",
                      ), // 👈 navigate here
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Create New Challenge',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(
    Map<String, dynamic> challenge, {
    required bool isIncoming,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ViewChallengePage(challenge: challenge, isIncoming: isIncoming),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            challenge["Court_Name"],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "Time Slot: ${_formatTimeSlot(challenge["Start_Time"], challenge["End_Time"])}",
            style: const TextStyle(color: Colors.white60),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.deepPurpleAccent.shade100,
          ),
        ),
      ),
    );
  }

  String _formatTimeSlot(String start, String end) {
    DateTime s = DateTime.parse(start);
    DateTime e = DateTime.parse(end);
    return "${_formatTime(s)} - ${_formatTime(e)}";
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
