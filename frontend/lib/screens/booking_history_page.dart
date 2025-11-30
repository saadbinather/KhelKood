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

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBookingHistory();
  }

  Future<void> _fetchBookingHistory() async {
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
        Uri.parse('$baseUrl/booking/history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          bookings = List<Map<String, dynamic>>.from(
            data['data']?['bookings'] ?? [],
          );
          isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error']?.toString() ?? 
                        errorData['message']?.toString() ?? 
                        'Failed to fetch booking history';
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'won':
        return Colors.green;
      case 'lost':
        return Colors.red;
      case 'tie':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'friendly':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text("Booking History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBookingHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchBookingHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : bookings.isEmpty
                  ? const Center(
                      child: Text(
                        'No booking history found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchBookingHistory,
                      color: Colors.deepPurple,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: bookings.length,
                        itemBuilder: (context, index) {
                          final booking = bookings[index];
                          final status = booking['status']?.toString() ?? 'Unknown';
                          final statusColor = _getStatusColor(status);
                          final isMatch = booking['isMatch'] == true;
                          final opponent = booking['opponent'];

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Left Column: Date, Time, Court, Opponent
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          booking['date']?.toString() ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          booking['time']?.toString() ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Court: ${booking['court']?.toString() ?? 'Unknown'}",
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        if (isMatch && opponent != null)
                                          Text(
                                            "Opponent: $opponent",
                                            style: const TextStyle(fontSize: 14),
                                          )
                                        else if (isMatch && opponent == null)
                                          const Text(
                                            "Opponent: Unknown",
                                            style: TextStyle(fontSize: 14),
                                          )
                                        else
                                          const Text(
                                            "Type: Friendly Booking",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Right Column: Status & Points
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        status,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (isMatch && status != 'Friendly')
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            "Points: ${booking['pointsEarned'] ?? 0}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
