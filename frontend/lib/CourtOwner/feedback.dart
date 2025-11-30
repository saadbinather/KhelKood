import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'http://localhost:5000/api';

Future<String?> _getAuthToken() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  } catch (e) {
    print('Error getting token: $e');
    return null;
  }
}

class CourtFeedbackPage extends StatefulWidget {
  const CourtFeedbackPage({super.key});

  @override
  State<CourtFeedbackPage> createState() => _CourtFeedbackPageState();
}

class _CourtFeedbackPageState extends State<CourtFeedbackPage> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> feedbackList = [];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          errorMessage = 'No authentication token found';
          isLoading = false;
        });
        return;
      }

      final url = '$baseUrl/reviews/courtowner';
      print('Fetching reviews from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final reviews = data['data']?['reviews'] ?? data['reviews'] ?? [];

        setState(() {
          feedbackList = (reviews as List).map((review) {
            return {
              'team': review['teamName'] ?? 'Unknown Team',
              'rating': review['rating'] ?? 0,
              'comment': review['comment'] ?? '',
              'publishedAt': review['createdAt'],
              'court': review['court'] != null
                  ? {
                      'name': review['court']['name'] ?? 'Unknown Court',
                      'address': review['court']['address'] ?? '',
                    }
                  : null,
            };
          }).toList();
          isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Failed to fetch reviews';
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

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Recently';
    try {
      DateTime date;
      if (dateValue is Map) {
        if (dateValue['_seconds'] != null) {
          date = DateTime.fromMillisecondsSinceEpoch(dateValue['_seconds'] * 1000);
        } else if (dateValue['seconds'] != null) {
          date = DateTime.fromMillisecondsSinceEpoch(dateValue['seconds'] * 1000);
        } else {
          return 'Recently';
        }
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Recently';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Recently';
    }
  }

  // -----------------------------
  // Widget to display star rating (out of 10)
  // -----------------------------
  Widget buildStars(int rating) {
    return Row(
      children: List.generate(
        10,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        ),
      ),
    );
  }

  // -----------------------------
  // Feedback card
  // -----------------------------
  Widget buildFeedbackCard(Map<String, dynamic> feedback) {
    final court = feedback['court'] as Map<String, dynamic>?;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback['team'] ?? 'Unknown Team',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (court != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          court['name'] ?? 'Unknown Court',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (feedback['publishedAt'] != null)
                  Text(
                    _formatDate(feedback['publishedAt']),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                buildStars(feedback['rating'] ?? 0),
                const SizedBox(width: 8),
                Text(
                  '${feedback['rating'] ?? 0}/10',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (feedback['comment'] != null && feedback['comment'].toString().isNotEmpty)
              Text(
                feedback['comment'] ?? "No comment provided.",
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              )
            else
              const Text(
                "No comment provided.",
                style: TextStyle(fontSize: 14, color: Colors.white54, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------------
  // Build page
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Court Feedback",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchReviews,
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
                    onPressed: _fetchReviews,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : feedbackList.isEmpty
          ? const Center(
              child: Text(
                'No reviews yet',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchReviews,
              color: Colors.redAccent,
              child: ListView.builder(
                itemCount: feedbackList.length,
                itemBuilder: (context, index) {
                  return buildFeedbackCard(feedbackList[index]);
                },
              ),
            ),
    );
  }
}
