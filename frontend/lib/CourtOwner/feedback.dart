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
  List<Map<String, dynamic>> filteredFeedbackList = [];

  // Filter states
  String?
  selectedRatingFilter; // null = all, "high" = 8-10, "medium" = 5-7, "low" = 1-4
  bool sortByLatest = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(feedbackList);

    // Apply rating filter
    if (selectedRatingFilter != null) {
      filtered = filtered.where((feedback) {
        final rating = feedback['rating'] ?? 0;
        switch (selectedRatingFilter) {
          case 'high':
            return rating >= 8;
          case 'medium':
            return rating >= 5 && rating < 8;
          case 'low':
            return rating < 5;
          default:
            return true;
        }
      }).toList();
    }

    // Apply date sort
    if (sortByLatest) {
      filtered.sort((a, b) {
        final dateA = _parseDate(a['publishedAt']);
        final dateB = _parseDate(b['publishedAt']);
        return dateB.compareTo(dateA); // Latest first
      });
    } else {
      filtered.sort((a, b) {
        final dateA = _parseDate(a['publishedAt']);
        final dateB = _parseDate(b['publishedAt']);
        return dateA.compareTo(dateB); // Oldest first
      });
    }

    setState(() {
      filteredFeedbackList = filtered;
    });
  }

  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime(1970);
    try {
      if (dateValue is Map) {
        if (dateValue['_seconds'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            dateValue['_seconds'] * 1000,
          );
        } else if (dateValue['seconds'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            dateValue['seconds'] * 1000,
          );
        }
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
    } catch (e) {
      return DateTime(1970);
    }
    return DateTime(1970);
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
        _applyFilters();
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
          date = DateTime.fromMillisecondsSinceEpoch(
            dateValue['_seconds'] * 1000,
          );
        } else if (dateValue['seconds'] != null) {
          date = DateTime.fromMillisecondsSinceEpoch(
            dateValue['seconds'] * 1000,
          );
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
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        10,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating
              ? (rating >= 8
                    ? const Color(0xFF4CAF50)
                    : rating >= 5
                    ? Colors.orange
                    : Colors.red)
              : Colors.grey[300],
          size: 18,
        ),
      ),
    );
  }

  // -----------------------------
  // Feedback card
  // -----------------------------
  Widget buildFeedbackCard(Map<String, dynamic> feedback) {
    final court = feedback['court'] as Map<String, dynamic>?;
    final rating = feedback['rating'] ?? 0;
    final isHighRating = rating >= 8;
    final isMediumRating = rating >= 5 && rating < 8;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              (isHighRating
                      ? const Color(0xFF4CAF50)
                      : isMediumRating
                      ? Colors.orange
                      : Colors.red)
                  .withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (isHighRating
                                ? const Color(0xFF4CAF50)
                                : isMediumRating
                                ? Colors.orange
                                : Colors.red)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: isHighRating
                        ? const Color(0xFF4CAF50)
                        : isMediumRating
                        ? Colors.orange
                        : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback['team'] ?? 'Unknown Team',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      if (court != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              court['name'] ?? 'Unknown Court',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (feedback['publishedAt'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDate(feedback['publishedAt']),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                buildStars(rating),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isHighRating
                                ? const Color(0xFF4CAF50)
                                : isMediumRating
                                ? Colors.orange
                                : Colors.red)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHighRating
                          ? const Color(0xFF4CAF50)
                          : isMediumRating
                          ? Colors.orange
                          : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$rating/10',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isHighRating
                          ? const Color(0xFF4CAF50)
                          : isMediumRating
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            if (feedback['comment'] != null &&
                feedback['comment'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Text(
                  feedback['comment'] ?? "No comment provided.",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "No comment provided.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Court Feedback",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Color(0xFF2E7D32)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchReviews,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Filter Section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Rating Filter
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedRatingFilter,
                                  isExpanded: true,
                                  hint: const Text(
                                    'Filter by Rating',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  icon: const Icon(
                                    Icons.filter_list,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('All Ratings'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'high',
                                      child: Text('High (8-10)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'medium',
                                      child: Text('Medium (5-7)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text('Low (1-4)'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedRatingFilter = value;
                                    });
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Date Sort Filter
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    sortByLatest = !sortByLatest;
                                  });
                                  _applyFilters();
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        sortByLatest
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        color: const Color(0xFF2E7D32),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        sortByLatest ? 'Latest' : 'Oldest',
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Feedback List
                Expanded(
                  child: feedbackList.isEmpty
                      ? const Center(
                          child: Text(
                            'No reviews yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : filteredFeedbackList.isEmpty
                      ? const Center(
                          child: Text(
                            'No reviews match the selected filter',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchReviews,
                          color: const Color(0xFF4CAF50),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredFeedbackList.length,
                            itemBuilder: (context, index) {
                              return buildFeedbackCard(
                                filteredFeedbackList[index],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
