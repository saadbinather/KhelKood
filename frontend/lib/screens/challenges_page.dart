import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'view_challenge_page.dart';
import 'create_booking_or_challenge_page.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  List<Map<String, dynamic>> incomingChallenges = [];
  List<Map<String, dynamic>> outgoingChallenges = [];
  bool isLoading = true;
  String? errorMessage;
  Set<String> acceptingChallengeIds =
      {}; // Track which challenges are being accepted
  Set<String> deletingChallengeIds =
      {}; // Track which challenges are being deleted

  @override
  void initState() {
    super.initState();
    _fetchOpenChallenges();
  }

  Future<void> _fetchOpenChallenges() async {
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
        Uri.parse('http://localhost:5000/api/challenges/open'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        setState(() {
          incomingChallenges = List<Map<String, dynamic>>.from(
            data['data']?['incoming'] ?? data['incoming'] ?? [],
          );
          outgoingChallenges = List<Map<String, dynamic>>.from(
            data['data']?['outgoing'] ?? data['outgoing'] ?? [],
          );
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load challenges';
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Icon(
              Icons.sports_mma,
              color: Colors.redAccent,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              'Challenges',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 18 : 20,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: _fetchOpenChallenges,
            tooltip: 'Refresh',
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
                    onPressed: _fetchOpenChallenges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchOpenChallenges,
              color: Colors.redAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Row(
                      children: [
                        Icon(
                          Icons.inbox,
                          color: Colors.redAccent,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Text(
                          'Incoming Challenges',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Text(
                      'Challenges from other teams',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    if (incomingChallenges.isEmpty)
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                color: Colors.white24,
                                size: isSmallScreen ? 40 : 48,
                              ),
                              SizedBox(height: isSmallScreen ? 8 : 12),
                              Text(
                                'No incoming challenges',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...incomingChallenges.map(
                        (c) => _buildChallengeCard(c, isIncoming: true),
                      ),

                    SizedBox(height: isSmallScreen ? 24 : 30),

                    Row(
                      children: [
                        Icon(
                          Icons.send,
                          color: Colors.redAccent,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Text(
                          'Outgoing Challenges',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Text(
                      'Challenges you created',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    if (outgoingChallenges.isEmpty)
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.send_outlined,
                                color: Colors.white24,
                                size: isSmallScreen ? 40 : 48,
                              ),
                              SizedBox(height: isSmallScreen ? 8 : 12),
                              Text(
                                'No outgoing challenges',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...outgoingChallenges.map(
                        (c) => _buildChallengeCard(c, isIncoming: false),
                      ),

                    SizedBox(height: isSmallScreen ? 24 : 30),

                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 24 : 30,
                              vertical: isSmallScreen ? 12 : 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CreateBookingOrChallengePage(
                                      actionType: 'challenge',
                                    ),
                              ),
                            );
                            if (result == true) {
                              _fetchOpenChallenges();
                            }
                          },
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: isSmallScreen ? 18 : 20,
                          ),
                          label: Text(
                            'Create New Challenge',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildChallengeCard(
    Map<String, dynamic> challenge, {
    required bool isIncoming,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final startTime = _parseTimestamp(challenge["Start_Time"]);
    final endTime = _parseTimestamp(challenge["End_Time"]);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewChallengePage(
                challenge: challenge,
                isIncoming: isIncoming,
              ),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
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
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sports_soccer,
                        color: Colors.redAccent,
                        size: isSmallScreen ? 18 : 20,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge["Court_Name"] ?? "Unknown Court",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 3 : 4),
                          if (challenge["Court_Address"] != null)
                            Text(
                              challenge["Court_Address"],
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          SizedBox(height: isSmallScreen ? 10 : 12),
                          // Host Team Info - Prominently displayed
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(
                                    isSmallScreen ? 6 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.group,
                                    color: Colors.redAccent,
                                    size: isSmallScreen ? 18 : 20,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 10 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        challenge["Host_Team_Name"] ??
                                            "Unknown Team",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 14 : 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: isSmallScreen ? 3 : 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.stars,
                                            color: Colors.amber,
                                            size: isSmallScreen ? 14 : 16,
                                          ),
                                          SizedBox(
                                            width: isSmallScreen ? 4 : 6,
                                          ),
                                          Text(
                                            '${challenge["Host_Team_Points"] ?? 0} Points',
                                            style: TextStyle(
                                              color: Colors.amber,
                                              fontSize: isSmallScreen ? 12 : 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          if (challenge["Court_Rating"] != null &&
                              challenge["Court_Rating"] > 0)
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: isSmallScreen ? 12 : 14,
                                ),
                                SizedBox(width: isSmallScreen ? 3 : 4),
                                Text(
                                  'Court Rating: ${challenge["Court_Rating"]}',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isSmallScreen ? 11 : 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: isIncoming
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isIncoming ? "Incoming" : "Outgoing",
                        style: TextStyle(
                          color: isIncoming ? Colors.orange : Colors.blue,
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 10 : 12),
                if (startTime != null && endTime != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.redAccent,
                        size: isSmallScreen ? 14 : 16,
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Expanded(
                        child: Text(
                          _formatTimeSlot(startTime, endTime),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.redAccent,
                        size: isSmallScreen ? 14 : 16,
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Expanded(
                        child: Text(
                          _formatDate(startTime),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: isSmallScreen ? 6 : 8),
                Row(
                  children: [
                    Icon(
                      Icons.sports,
                      color: Colors.redAccent,
                      size: isSmallScreen ? 14 : 16,
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Expanded(
                      child: Text(
                        (challenge["Sport"] ?? "Unknown").toUpperCase(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                      ),
                    ),
                    if (challenge["Price"] != null && challenge["Price"] > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 10,
                          vertical: isSmallScreen ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.currency_rupee,
                              color: Colors.green,
                              size: isSmallScreen ? 12 : 14,
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 4),
                            Text(
                              '${challenge["Price"]}',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.redAccent,
                      size: isSmallScreen ? 14 : 16,
                    ),
                  ],
                ),
                if (isIncoming) ...[
                  SizedBox(height: isSmallScreen ? 10 : 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          acceptingChallengeIds.contains(
                            challenge['challengeID'] ?? challenge['id'],
                          )
                          ? null
                          : () => _acceptChallenge(challenge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 10 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          acceptingChallengeIds.contains(
                            challenge['challengeID'] ?? challenge['id'],
                          )
                          ? SizedBox(
                              height: isSmallScreen ? 18 : 20,
                              width: isSmallScreen ? 18 : 20,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Accept Challenge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  // Delete button for outgoing challenges
                  SizedBox(height: isSmallScreen ? 10 : 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          deletingChallengeIds.contains(
                            challenge['challengeID'] ?? challenge['id'],
                          )
                          ? null
                          : () => _deleteChallenge(challenge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 10 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          deletingChallengeIds.contains(
                            challenge['challengeID'] ?? challenge['id'],
                          )
                          ? SizedBox(
                              height: isSmallScreen ? 18 : 20,
                              width: isSmallScreen ? 18 : 20,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: isSmallScreen ? 16 : 18,
                                ),
                                SizedBox(width: isSmallScreen ? 6 : 8),
                                Text(
                                  'Delete Challenge',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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

  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    try {
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is Map) {
        // Firestore Timestamp
        if (timestamp['_seconds'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            timestamp['_seconds'] * 1000,
          );
        }
      } else if (timestamp is DateTime) {
        return timestamp;
      }
    } catch (e) {
      print('Error parsing timestamp: $e');
    }
    return null;
  }

  String _formatTimeSlot(DateTime start, DateTime end) {
    return "${_formatTime(start)} - ${_formatTime(end)}";
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${date.day} ${months[date.month - 1]}, ${date.year}";
  }

  Future<void> _deleteChallenge(Map<String, dynamic> challenge) async {
    final challengeID = challenge['challengeID'] ?? challenge['id'];
    if (challengeID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid challenge ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Challenge',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this challenge?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              'Court: ${challenge["Court_Name"] ?? "Unknown"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            if (challenge["Date"] != null)
              Text(
                'Date: ${challenge["Date"]}',
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      deletingChallengeIds.add(challengeID);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          deletingChallengeIds.remove(challengeID);
        });
        return;
      }

      final response = await http.delete(
        Uri.parse('http://localhost:5000/api/challenges/$challengeID'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      setState(() {
        deletingChallengeIds.remove(challengeID);
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Challenge deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh challenges list
        _fetchOpenChallenges();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to delete challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        deletingChallengeIds.remove(challengeID);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptChallenge(Map<String, dynamic> challenge) async {
    final challengeID = challenge['challengeID'] ?? challenge['id'];
    if (challengeID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid challenge ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Accept Challenge',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Court: ${challenge["Court_Name"] ?? "Unknown"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Host: ${challenge["Host_Team_Name"] ?? "Unknown"}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (challenge["Price"] != null && challenge["Price"] > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Price: Rs. ${challenge["Price"]}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'This will create a match, booking, and payment. Continue?',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      acceptingChallengeIds.add(challengeID);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          acceptingChallengeIds.remove(challengeID);
        });
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:5000/api/match/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'challengeID': challengeID}),
      );

      setState(() {
        acceptingChallengeIds.remove(challengeID);
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Challenge accepted successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh challenges list
        _fetchOpenChallenges();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to accept challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        acceptingChallengeIds.remove(challengeID);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
