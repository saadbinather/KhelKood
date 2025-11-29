import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../widgets/time_slot_grid.dart';

class CourtDetailPage extends StatefulWidget {
  final Map<String, dynamic> court;

  const CourtDetailPage({
    super.key,
    required this.court,
  });

  @override
  State<CourtDetailPage> createState() => _CourtDetailPageState();
}

class _CourtDetailPageState extends State<CourtDetailPage> {
  Map<String, dynamic>? courtData;
  List<Map<String, dynamic>> reviews = [];
  bool isLoadingCourt = true;
  bool isLoadingReviews = false;
  bool isSubmittingReview = false;
  
  // Review form
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 0;
  
  // Time slot selection
  Map<String, dynamic>? selectedCourt;
  int? selectedStartSlot;
  int? selectedEndSlot;

  @override
  void initState() {
    super.initState();
    _loadCourtData();
    _fetchReviews();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadCourtData() async {
    setState(() {
      isLoadingCourt = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          isLoadingCourt = false;
        });
        return;
      }

      // Fetch updated court data to get latest rating
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/courts/verified'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final courts = List<Map<String, dynamic>>.from(
          data['data']?['courts'] ?? data['courts'] ?? [],
        );
        final updatedCourt = courts.firstWhere(
          (c) => c['id'] == widget.court['id'],
          orElse: () => widget.court,
        );
        
        setState(() {
          courtData = updatedCourt;
          selectedCourt = updatedCourt;
          isLoadingCourt = false;
        });
      } else {
        setState(() {
          courtData = widget.court;
          selectedCourt = widget.court;
          isLoadingCourt = false;
        });
      }
    } catch (e) {
      setState(() {
        courtData = widget.court;
        selectedCourt = widget.court;
        isLoadingCourt = false;
      });
    }
  }

  Future<void> _fetchReviews() async {
    setState(() {
      isLoadingReviews = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          isLoadingReviews = false;
        });
        return;
      }

      final courtId = widget.court['id'] ?? widget.court['courtId'];
      print('Fetching reviews for court ID: $courtId');
      print('Full court object: ${widget.court}');
      
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/reviews/court/$courtId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('=== FETCHING REVIEWS ===');
      print('Court ID: ${widget.court['id']}');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        print('Parsed Data: $data');
        
        final reviewsList = List<Map<String, dynamic>>.from(
          data['data']?['reviews'] ?? data['reviews'] ?? [],
        );
        
        // Print reviews for debugging
        print('=== COURT REVIEWS ===');
        print('Court ID: ${widget.court['id']}');
        print('Total Reviews: ${reviewsList.length}');
        print('Data structure: ${data.keys}');
        print('Reviews from data.data: ${data['data']?['reviews']}');
        print('Reviews from data: ${data['reviews']}');
        
        for (var i = 0; i < reviewsList.length; i++) {
          final review = reviewsList[i];
          print('Review ${i + 1}:');
          print('  - Team: ${review['teamName'] ?? 'Unknown'}');
          print('  - Rating: ${review['rating'] ?? 0}/10');
          print('  - Comment: ${review['comment'] ?? 'No comment'}');
          print('  - Date: ${review['createdAt']}');
          print('  - Full Data: $review');
        }
        print('===================');
        
        setState(() {
          reviews = reviewsList;
          isLoadingReviews = false;
        });
      } else {
        print('Failed to fetch reviews. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        setState(() {
          isLoadingReviews = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingReviews = false;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSubmittingReview = true;
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
          isSubmittingReview = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:5000/api/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'courtID': widget.court['id'] ?? widget.court['courtId'],
          'rating': _selectedRating,
          'comment': _reviewController.text.trim(),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        
        // Print review submission response
        print('=== REVIEW SUBMITTED ===');
        print('Response: $data');
        print('Updated Court Rating: ${data['data']?['updatedCourtRating'] ?? 'N/A'}');
        print('=======================');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Review added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        _reviewController.clear();
        _selectedRating = 0;
        
        // Refresh reviews and court data
        await Future.wait([
          _fetchReviews(),
          _loadCourtData(),
        ]);
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to add review'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSubmittingReview = false;
      });
    }
  }

  void _selectTimeSlot(int dayIndex, int hour) {
    setState(() {
      if (selectedStartSlot == null) {
        selectedStartSlot = dayIndex * 24 + hour;
        selectedEndSlot = selectedStartSlot;
      } else {
        final currentSlot = dayIndex * 24 + hour;
        final startDay = selectedStartSlot! ~/ 24;
        final startHour = selectedStartSlot! % 24;
        
        if (dayIndex == startDay) {
          if (currentSlot < selectedStartSlot!) {
            selectedStartSlot = currentSlot;
          } else {
            selectedEndSlot = currentSlot;
          }
        } else {
          selectedStartSlot = currentSlot;
          selectedEndSlot = currentSlot;
        }
      }
    });
  }

  List<DateTime> _getNext7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  String _getSportType() {
    if (courtData == null) return 'futsal';
    
    // Determine sport based on court facilities
    if ((courtData!['numOfCricketFields'] ?? 0) > 0) return 'cricket';
    if ((courtData!['numOfFutsalFields'] ?? 0) > 0) return 'futsal';
    if ((courtData!['numOfPadelCourts'] ?? 0) > 0) return 'padel';
    return 'futsal';
  }

  double _getRate() {
    if (courtData == null) return 0;
    final sport = _getSportType();
    if (sport == 'cricket') return (courtData!['cricketRate'] ?? 0).toDouble();
    if (sport == 'futsal') return (courtData!['futsalRate'] ?? 0).toDouble();
    if (sport == 'padel') return (courtData!['padelRate'] ?? 0).toDouble();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingCourt || courtData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: const Text(
            'Court Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: Text(
            courtData!['name'] ?? 'Court Details',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Time Slots'),
              Tab(text: 'Reviews'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Time Slots Tab
            _buildTimeSlotsTab(),
            // Reviews Tab
            _buildReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Court Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courtData!['name'] ?? 'Unknown Court',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  courtData!['address'] ?? 'Unknown Address',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${courtData!['rating'] ?? 0}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${courtData!['openingTime'] ?? 8}:00 - ${courtData!['closingTime'] ?? 23}:00',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Rs ${_getRate()}/hr',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Time Slot Grid
          TimeSlotGrid(
            selectedCourt: selectedCourt,
            selectedStartSlot: selectedStartSlot,
            selectedEndSlot: selectedEndSlot,
            onSlotSelected: _selectTimeSlot,
            days: _getNext7Days(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Review Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Your Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Rating Stars (out of 10)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 4,
                      children: List.generate(10, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRating = index + 1;
                            });
                          },
                          child: Icon(
                            index < _selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedRating > 0 ? 'Rating: $_selectedRating/10' : 'Select rating (1-10)',
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Comment Field
                TextField(
                  controller: _reviewController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Write your review (optional)...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmittingReview ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isSubmittingReview
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Review',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Reviews List
          Text(
            'All Reviews (${reviews.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          if (isLoadingReviews)
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          else if (reviews.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.reviews, size: 64, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text(
                      'No reviews yet',
                      style: TextStyle(color: Colors.grey[700], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ...reviews.map((review) => _buildReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = review['rating'] ?? 0;
    final comment = review['comment'] ?? '';
    final teamName = review['teamName'] ?? 'Unknown Team';
    final createdAt = review['createdAt'];
    
    String dateStr = 'Recently';
    if (createdAt != null) {
      try {
        DateTime date;
        if (createdAt is Map) {
          if (createdAt['_seconds'] != null) {
            date = DateTime.fromMillisecondsSinceEpoch(createdAt['_seconds'] * 1000);
          } else if (createdAt['seconds'] != null) {
            date = DateTime.fromMillisecondsSinceEpoch(createdAt['seconds'] * 1000);
          } else {
            date = DateTime.now();
          }
        } else if (createdAt is String) {
          date = DateTime.parse(createdAt);
        } else {
          date = DateTime.now();
        }
        final now = DateTime.now();
        final difference = now.difference(date);
        if (difference.inDays == 0) {
          dateStr = 'Today';
        } else if (difference.inDays == 1) {
          dateStr = 'Yesterday';
        } else if (difference.inDays < 7) {
          dateStr = '${difference.inDays} days ago';
        } else {
          dateStr = '${date.day}/${date.month}/${date.year}';
        }
      } catch (e) {
        dateStr = 'Recently';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  teamName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: List.generate(10, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '$rating/10',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (comment.isNotEmpty)
            Text(
              comment,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

