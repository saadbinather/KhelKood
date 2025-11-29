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

      final response = await http.get(
        Uri.parse('$baseUrl/review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reviews = data['data']['reviews'] as List<dynamic>;

        setState(() {
          feedbackList = reviews.map((review) {
            return {
              'team': review['teamName'] ?? 'Unknown Team',
              'rating': review['rating'] ?? 0,
              'comment': review['comment'],
              'publishedAt': review['publishedAt'],
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

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // -----------------------------
  // Widget to display star rating
  // -----------------------------
  Widget buildStars(int rating) {
    return Row(
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        ),
      ),
    );
  }

  // -----------------------------
  // Feedback card
  // -----------------------------
  Widget buildFeedbackCard(Map<String, dynamic> feedback) {
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
                Text(
                  feedback['team'] ?? 'Unknown Team',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                if (feedback['publishedAt'] != null)
                  Text(
                    _formatDate(feedback['publishedAt']),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            buildStars(feedback['rating'] ?? 0),
            const SizedBox(height: 8),
            Text(
              feedback['comment'] ?? "No comment provided.",
              style: const TextStyle(fontSize: 14, color: Colors.white70),
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
