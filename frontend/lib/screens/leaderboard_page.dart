import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> teams = [];
  String searchQuery = "";
  bool isLoading = true;
  String? errorMessage;
  String? sport;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

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
        Uri.parse('http://localhost:5000/api/leaderboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        setState(() {
          teams = List<Map<String, dynamic>>.from(
            data['data']?['teams'] ?? data['teams'] ?? [],
          );
          sport = data['data']?['sport'] ?? data['sport'];
          isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Failed to load leaderboard';
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

  @override
  Widget build(BuildContext context) {
    // Filter teams by search query (already sorted by points descending from API)
    final List<Map<String, dynamic>> filteredTeams = teams
        .where((team) =>
            (team['teamName'] ?? '').toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Text(
          sport != null ? 'Leaderboard - ${sport?.toUpperCase()}' : 'Leaderboard',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                        onPressed: _fetchLeaderboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search Team',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
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
                        child: filteredTeams.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.emoji_events, size: 64, color: Colors.grey[700]),
                                    const SizedBox(height: 16),
                                    Text(
                                      searchQuery.isNotEmpty
                                          ? 'No teams found'
                                          : 'No teams in leaderboard',
                                      style: TextStyle(color: Colors.grey[700], fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchLeaderboard,
                                color: Colors.redAccent,
                                child: ListView.builder(
                                  itemCount: filteredTeams.length,
                                  itemBuilder: (context, index) {
                                    final team = filteredTeams[index];

                                    // Determine if we show trophy for top 3
                                    Widget rankWidget;
                                    if (index == 0) {
                                      rankWidget = const Icon(
                                        Icons.emoji_events,
                                        color: Colors.amber,
                                        size: 32,
                                      );
                                    } else if (index == 1) {
                                      rankWidget = const Icon(
                                        Icons.emoji_events,
                                        color: Colors.grey,
                                        size: 28,
                                      );
                                    } else if (index == 2) {
                                      rankWidget = const Icon(
                                        Icons.emoji_events,
                                        color: Colors.brown,
                                        size: 28,
                                      );
                                    } else {
                                      rankWidget = CircleAvatar(
                                        backgroundColor: Colors.redAccent,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }

                                    final playerCount = team['playerCount'] ?? (team['players'] as List?)?.length ?? 0;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.redAccent.withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        leading: rankWidget,
                                        title: Text(
                                          team['teamName'] ?? 'Unknown Team',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${team['sports'] ?? ''} · $playerCount ${playerCount == 1 ? 'player' : 'players'}',
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                        trailing: Text(
                                          '${team['points'] ?? 0} pts',
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
