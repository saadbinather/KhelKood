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

class BookingManagementPage extends StatefulWidget {
  const BookingManagementPage({super.key});

  @override
  State<BookingManagementPage> createState() => _BookingManagementPageState();
}

class _BookingManagementPageState extends State<BookingManagementPage> {
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> incomingBookings = [];
  List<Map<String, dynamic>> upcomingBookings = [];
  List<Map<String, dynamic>> pastBookings = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
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
        Uri.parse('$baseUrl/courtowner/bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bookingsData = data['data'];

        setState(() {
          incomingBookings = _formatBookings(bookingsData['incoming'] ?? []);
          upcomingBookings = _formatBookings(bookingsData['upcoming'] ?? []);
          pastBookings = _formatBookings(bookingsData['past'] ?? []);
          isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Failed to fetch bookings';
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

  List<Map<String, dynamic>> _formatBookings(List<dynamic> bookings) {
    return bookings.map((booking) {
      final startTime = _parseTimestamp(booking['startTime']);
      final endTime = _parseTimestamp(booking['endTime']);

      return {
        'id': booking['id'],
        'court': booking['court']?['name'] ?? 'Unknown Court',
        'sport': _determineSport(booking['court']),
        'team': booking['team']?['teamName'] ?? 'Unknown Team',
        'date': _formatDate(startTime),
        'time': _formatTime(startTime),
        'endTime': _formatTime(endTime),
        'status': booking['status'] ?? 'Pending',
        'rawBooking': booking,
      };
    }).toList();
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    try {
      if (timestamp is Map) {
        if (timestamp.containsKey('_seconds')) {
          return DateTime.fromMillisecondsSinceEpoch(
            timestamp['_seconds'] * 1000,
          );
        }
        if (timestamp.containsKey('seconds')) {
          return DateTime.fromMillisecondsSinceEpoch(
            timestamp['seconds'] * 1000,
          );
        }
      }
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      print('Error parsing timestamp: $e');
    }
    return DateTime.now();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _determineSport(Map<String, dynamic>? court) {
    if (court == null) return 'Unknown';
    // You can add logic here to determine sport based on court data
    return 'Sports'; // Default
  }

  // -----------------------------
  // Actions
  // -----------------------------
  Future<void> acceptBooking(Map<String, dynamic> booking) async {
    final bookingID = booking['id'];

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Accepting booking...'),
        backgroundColor: Colors.redAccent,
      ),
    );

    try {
      final token = await _getAuthToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/courtowner/bookings/$bookingID/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Remove from incoming, add to upcoming
        setState(() {
          incomingBookings.removeWhere((b) => b['id'] == bookingID);
          final updatedBooking = Map<String, dynamic>.from(booking);
          updatedBooking['status'] = 'Confirmed';
          upcomingBookings.add(updatedBooking);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking accepted successfully'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to accept booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> rejectBooking(Map<String, dynamic> booking) async {
    final bookingID = booking['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Booking',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to reject this booking?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rejecting booking...'),
        backgroundColor: Colors.orange,
      ),
    );

    try {
      final token = await _getAuthToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/courtowner/bookings/$bookingID/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          incomingBookings.removeWhere((b) => b['id'] == bookingID);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking rejected successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to reject booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void cancelBooking(dynamic id) {
    setState(() {
      upcomingBookings.removeWhere((booking) => booking['id'] == id);
    });
  }

  void addResult(Map<String, dynamic> booking) {
    final TextEditingController resultController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Add Result for ${booking['sport']}",
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: resultController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: booking['sport'] == "Cricket"
                ? "Runs scored / Winner"
                : booking['sport'] == "Football"
                ? "Score (Team A - Team B)"
                : "Padel Result",
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[900],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              // Send result to backend later
              print(
                "Result for booking ${booking['id']}: ${resultController.text}",
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Submit", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // Widgets
  // -----------------------------
  Widget buildIncomingBookingCard(Map<String, dynamic> booking) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final padding = isSmallScreen ? 12.0 : 16.0;
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final smallFontSize = isSmallScreen ? 12.0 : 14.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 4 : 8,
        vertical: isSmallScreen ? 4 : 6,
      ),
      color: Colors.grey[900],
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.redAccent.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.schedule,
                    color: Colors.redAccent,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${booking['court']} - ${booking['sport']}",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        booking['team'],
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: smallFontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Wrap(
              spacing: isSmallScreen ? 8 : 12,
              runSpacing: isSmallScreen ? 4 : 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: isSmallScreen ? 14 : 16,
                      color: Colors.white70,
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Text(
                      booking['date'],
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 11 : 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: isSmallScreen ? 14 : 16,
                      color: Colors.white70,
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Flexible(
                      child: Text(
                        "${booking['time']} - ${booking['endTime']}",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 11 : 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: ElevatedButton(
                    onPressed: () => rejectBooking(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 20,
                        vertical: isSmallScreen ? 8 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "Reject",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 10),
                Flexible(
                  child: ElevatedButton(
                    onPressed: () => acceptBooking(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 20,
                        vertical: isSmallScreen ? 8 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "Accept",
                      style: TextStyle(
                        color: Colors.grey[900],
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------
  // Build Booking Card
  // ----------------------------------
  Widget buildBookingCard(
    Map<String, dynamic> booking, {
    bool isUpcoming = true,
  }) {
    final isConfirmed = booking['status'] == 'Confirmed';
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final padding = isSmallScreen ? 12.0 : 16.0;
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final smallFontSize = isSmallScreen ? 12.0 : 14.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 4 : 8,
        vertical: isSmallScreen ? 4 : 6,
      ),
      color: Colors.grey[900],
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (isConfirmed ? Colors.redAccent : Colors.orange).withOpacity(
            0.2,
          ),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                  decoration: BoxDecoration(
                    color: (isConfirmed ? Colors.redAccent : Colors.orange)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isUpcoming ? Icons.event : Icons.history,
                    color: isConfirmed ? Colors.redAccent : Colors.orange,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${booking['court']} - ${booking['sport']}",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        booking['team'],
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: smallFontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 10,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: (isConfirmed ? Colors.redAccent : Colors.orange)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isConfirmed ? Colors.redAccent : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    booking['status'],
                    style: TextStyle(
                      color: isConfirmed ? Colors.redAccent : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 10 : 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Wrap(
              spacing: isSmallScreen ? 8 : 12,
              runSpacing: isSmallScreen ? 4 : 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: isSmallScreen ? 14 : 16,
                      color: Colors.white70,
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Text(
                      booking['date'],
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 11 : 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: isSmallScreen ? 14 : 16,
                      color: Colors.white70,
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Flexible(
                      child: Text(
                        "${booking['time']} - ${booking['endTime']}",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 11 : 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  if (isUpcoming) {
                    cancelBooking(booking['id']);
                  } else {
                    addResult(booking);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUpcoming ? Colors.red : Colors.redAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  isUpcoming ? "Cancel" : "Add Result",
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------
  // Build Page
  // ----------------------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final titleFontSize = isSmallScreen ? 18.0 : 20.0;
    final padding = isSmallScreen ? 8.0 : 12.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "Manage Bookings",
          style: TextStyle(
            color: Colors.grey[900],
            fontSize: isSmallScreen ? 18 : 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.grey[900],
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: _fetchBookings,
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
              child: Padding(
                padding: EdgeInsets.all(padding * 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    ElevatedButton(
                      onPressed: _fetchBookings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 24,
                          vertical: isSmallScreen ? 10 : 12,
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.grey[900],
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -----------------------------
                    // Incoming Bookings
                    // -----------------------------
                    Text(
                      "Incoming Bookings",
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    incomingBookings.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(
                              isSmallScreen ? 12.0 : 16.0,
                            ),
                            child: Text(
                              'No incoming bookings',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                          )
                        : Column(
                            children: incomingBookings
                                .map(
                                  (booking) =>
                                      buildIncomingBookingCard(booking),
                                )
                                .toList(),
                          ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    // -----------------------------
                    // Upcoming Bookings
                    // -----------------------------
                    Text(
                      "Upcoming Bookings",
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    upcomingBookings.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(
                              isSmallScreen ? 12.0 : 16.0,
                            ),
                            child: Text(
                              'No upcoming bookings',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                          )
                        : Column(
                            children: upcomingBookings
                                .map(
                                  (booking) => buildBookingCard(
                                    booking,
                                    isUpcoming: true,
                                  ),
                                )
                                .toList(),
                          ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    // -----------------------------
                    // Past Bookings
                    // -----------------------------
                    Text(
                      "Past Bookings",
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    pastBookings.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(
                              isSmallScreen ? 12.0 : 16.0,
                            ),
                            child: Text(
                              'No past bookings',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                          )
                        : Column(
                            children: pastBookings
                                .map(
                                  (booking) => buildBookingCard(
                                    booking,
                                    isUpcoming: false,
                                  ),
                                )
                                .toList(),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
