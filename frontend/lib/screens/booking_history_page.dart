import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

// Use AppConstants.baseUrl for platform-aware base URL
final String baseUrl = AppConstants.baseUrl;

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
        backgroundColor: Colors.redAccent,
        title: Row(
          children: [
            Icon(
              Icons.history,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              "Booking History",
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: _fetchBookingHistory,
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
                        onPressed: _fetchBookingHistory,
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
              : bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: isSmallScreen ? 56 : 64,
                            color: Colors.grey[700],
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Text(
                            'No booking history found',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchBookingHistory,
                      color: Colors.redAccent,
                      child: ListView.builder(
                        padding: EdgeInsets.all(horizontalPadding),
                        itemCount: bookings.length,
                        itemBuilder: (context, index) {
                          final booking = bookings[index];
                          final status = booking['status']?.toString() ?? 'Unknown';
                          final statusColor = _getStatusColor(status);
                          final isMatch = booking['isMatch'] == true;
                          final opponent = booking['opponent'];

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
                            child: Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  color: Colors.redAccent,
                                                  size: isSmallScreen ? 16 : 18,
                                                ),
                                                SizedBox(width: isSmallScreen ? 6 : 8),
                                                Expanded(
                                                  child: Text(
                                                    booking['date']?.toString() ?? 'N/A',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 15 : 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: isSmallScreen ? 6 : 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  color: Colors.white54,
                                                  size: isSmallScreen ? 14 : 16,
                                                ),
                                                SizedBox(width: isSmallScreen ? 6 : 8),
                                                Expanded(
                                                  child: Text(
                                                    booking['time']?.toString() ?? 'N/A',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 13 : 14,
                                                      color: Colors.white70,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: isSmallScreen ? 8 : 10),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.sports_soccer,
                                                  color: Colors.white54,
                                                  size: isSmallScreen ? 14 : 16,
                                                ),
                                                SizedBox(width: isSmallScreen ? 6 : 8),
                                                Expanded(
                                                  child: Text(
                                                    "Court: ${booking['court']?.toString() ?? 'Unknown'}",
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 13 : 14,
                                                      color: Colors.white70,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (isMatch && opponent != null) ...[
                                              SizedBox(height: isSmallScreen ? 6 : 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.group,
                                                    color: Colors.white54,
                                                    size: isSmallScreen ? 14 : 16,
                                                  ),
                                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                                  Expanded(
                                                    child: Text(
                                                      "Opponent: $opponent",
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen ? 13 : 14,
                                                        color: Colors.white70,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else if (isMatch && opponent == null) ...[
                                              SizedBox(height: isSmallScreen ? 6 : 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.group,
                                                    color: Colors.white54,
                                                    size: isSmallScreen ? 14 : 16,
                                                  ),
                                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                                  Text(
                                                    "Opponent: Unknown",
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 13 : 14,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else ...[
                                              SizedBox(height: isSmallScreen ? 6 : 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.favorite,
                                                    color: Colors.blue,
                                                    size: isSmallScreen ? 14 : 16,
                                                  ),
                                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                                  Text(
                                                    "Type: Friendly Booking",
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 13 : 14,
                                                      color: Colors.blue,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isSmallScreen ? 8 : 10,
                                              vertical: isSmallScreen ? 4 : 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: statusColor,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                                fontSize: isSmallScreen ? 11 : 12,
                                              ),
                                            ),
                                          ),
                                          if (isMatch && status != 'Friendly') ...[
                                            SizedBox(height: isSmallScreen ? 6 : 8),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.stars,
                                                  color: Colors.amber,
                                                  size: isSmallScreen ? 14 : 16,
                                                ),
                                                SizedBox(width: isSmallScreen ? 4 : 6),
                                                Text(
                                                  "${booking['pointsEarned'] ?? 0}",
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 13 : 14,
                                                    color: Colors.amber,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
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
