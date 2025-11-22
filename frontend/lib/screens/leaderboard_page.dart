import 'package:flutter/material.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  // Dummy leaderboard data
  final List<Map<String, dynamic>> teams = [
    {
      'teamName': 'Team Freaks',
      'sports': 'Futsal',
      'points': 42,
      'players': ['Ali', 'Usman', 'Ahmed', 'Raza']
    },
    {
      'teamName': 'Team Lightning',
      'sports': 'Futsal',
      'points': 55,
      'players': ['Sarah', 'Zain', 'Nora']
    },
    {
      'teamName': 'Team Thunder',
      'sports': 'Basketball',
      'points': 35,
      'players': ['Omar', 'Hassan', 'Ali']
    },
    {
      'teamName': 'Team Hurricanes',
      'sports': 'Futsal',
      'points': 60,
      'players': ['Aisha', 'Sami', 'Rida']
    },
  ];

  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // Filter and sort teams by points descending
    final List<Map<String, dynamic>> filteredTeams = teams
        .where((team) =>
            team['teamName'].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList()
      ..sort((a, b) => b['points'].compareTo(a['points']));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text("Leaderboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search Team',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Leaderboard list
            Expanded(
              child: ListView.builder(
                itemCount: filteredTeams.length,
                itemBuilder: (context, index) {
                  final team = filteredTeams[index];

                  // Determine if we show crown for top 3
                  Widget rankWidget;
                  if (index == 0) {
                    rankWidget = const Icon(Icons.emoji_events, color: Colors.amber);
                  } else if (index == 1) {
                    rankWidget = const Icon(Icons.emoji_events, color: Colors.grey);
                  } else if (index == 2) {
                    rankWidget = const Icon(Icons.emoji_events, color: Colors.brown);
                  } else {
                    rankWidget = CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: rankWidget,
                      title: Text(
                        team['teamName'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                          '${team['sports']} · ${team['players'].length} players'),
                      trailing: Text(
                        '${team['points']} pts',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
