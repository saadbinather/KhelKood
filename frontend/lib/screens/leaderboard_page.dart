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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen
        ? 12.0
        : isTablet
        ? 24.0
        : 16.0;

    // Filter teams by search query (already sorted by points descending from API)
    final List<Map<String, dynamic>> filteredTeams = teams
        .where((team) =>
            (team['teamName'] ?? '').toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Row(
          children: [
            Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(
              child: Text(
                sport != null ? 'Leaderboard - ${sport?.toUpperCase()}' : 'Leaderboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
                      Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: isSmallScreen ? 48 : 64,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      ElevatedButton.icon(
                        onPressed: _fetchLeaderboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 24 : 32,
                            vertical: isSmallScreen ? 12 : 14,
                          ),
                        ),
                        icon: Icon(Icons.refresh, size: isSmallScreen ? 18 : 20),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: Column(
                    children: [
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      // Search bar
                      TextField(
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search Team',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.redAccent,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.redAccent.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),

                      // Leaderboard list
                      Expanded(
                        child: filteredTeams.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.emoji_events_outlined,
                                      size: isSmallScreen ? 56 : 64,
                                      color: Colors.grey[700],
                                    ),
                                    SizedBox(height: isSmallScreen ? 12 : 16),
                                    Text(
                                      searchQuery.isNotEmpty
                                          ? 'No teams found'
                                          : 'No teams in leaderboard',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: isSmallScreen ? 14 : 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchLeaderboard,
                                color: Colors.redAccent,
                                child: ListView.builder(
                                  padding: EdgeInsets.only(
                                    top: isSmallScreen ? 8 : 12,
                                    bottom: isSmallScreen ? 12 : 16,
                                  ),
                                  itemCount: filteredTeams.length,
                                  itemBuilder: (context, index) {
                                    final team = filteredTeams[index];

                                    // Determine if we show trophy for top 3
                                    Widget rankWidget;
                                    if (index == 0) {
                                      rankWidget = Icon(
                                        Icons.emoji_events,
                                        color: Colors.amber,
                                        size: isSmallScreen ? 28 : 32,
                                      );
                                    } else if (index == 1) {
                                      rankWidget = Icon(
                                        Icons.emoji_events,
                                        color: Colors.grey[400],
                                        size: isSmallScreen ? 24 : 28,
                                      );
                                    } else if (index == 2) {
                                      rankWidget = Icon(
                                        Icons.emoji_events,
                                        color: Colors.brown[300],
                                        size: isSmallScreen ? 24 : 28,
                                      );
                                    } else {
                                      rankWidget = Container(
                                        width: isSmallScreen ? 32 : 36,
                                        height: isSmallScreen ? 32 : 36,
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: isSmallScreen ? 14 : 16,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final playerCount = team['playerCount'] ?? (team['players'] as List?)?.length ?? 0;

                                    return Container(
                                      margin: EdgeInsets.only(
                                        bottom: isSmallScreen ? 10 : 12,
                                      ),
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
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () {
                                            // Could navigate to team details
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.all(
                                              isSmallScreen ? 12 : 16,
                                            ),
                                            child: Row(
                                              children: [
                                                rankWidget,
                                                SizedBox(width: isSmallScreen ? 12 : 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        team['teamName'] ?? 'Unknown Team',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: isSmallScreen ? 15 : 16,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      SizedBox(height: isSmallScreen ? 3 : 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.sports_soccer,
                                                            color: Colors.white54,
                                                            size: isSmallScreen ? 14 : 16,
                                                          ),
                                                          SizedBox(width: isSmallScreen ? 4 : 6),
                                                          Text(
                                                            '${team['sports'] ?? ''}',
                                                            style: TextStyle(
                                                              color: Colors.white54,
                                                              fontSize: isSmallScreen ? 12 : 13,
                                                            ),
                                                          ),
                                                          SizedBox(width: isSmallScreen ? 6 : 8),
                                                          Icon(
                                                            Icons.people,
                                                            color: Colors.white54,
                                                            size: isSmallScreen ? 14 : 16,
                                                          ),
                                                          SizedBox(width: isSmallScreen ? 4 : 6),
                                                          Text(
                                                            '$playerCount ${playerCount == 1 ? 'player' : 'players'}',
                                                            style: TextStyle(
                                                              color: Colors.white54,
                                                              fontSize: isSmallScreen ? 12 : 13,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: isSmallScreen ? 8 : 12),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
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
                                                            color: Colors.redAccent,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: isSmallScreen ? 15 : 16,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: isSmallScreen ? 2 : 4),
                                                    Text(
                                                      'pts',
                                                      style: TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: isSmallScreen ? 11 : 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
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
