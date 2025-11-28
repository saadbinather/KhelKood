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
          return DateTime.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
        }
        if (timestamp.containsKey('seconds')) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp['seconds'] * 1000);
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
        backgroundColor: Colors.blue,
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
            backgroundColor: Colors.green,
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
        title: const Text('Reject Booking', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reject this booking?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rejecting booking...'),
        backgroundColor: Colors.blue,
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
        title: Text("Add Result for ${booking['sport']}"),
        content: TextField(
          controller: resultController,
          decoration: InputDecoration(
            labelText: booking['sport'] == "Cricket"
                ? "Runs scored / Winner"
                : booking['sport'] == "Football"
                    ? "Score (Team A - Team B)"
                    : "Padel Result",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              // Send result to backend later
              print(
                  "Result for booking ${booking['id']}: ${resultController.text}");
              Navigator.pop(context);
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // Widgets
  // -----------------------------
  Widget buildIncomingBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text("${booking['court']} - ${booking['sport']}"),
        subtitle: Text(
            "${booking['team']} | ${booking['date']} at ${booking['time']} - ${booking['endTime']}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => acceptBooking(booking),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Accept"),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => rejectBooking(booking),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Reject"),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------
  // Build Booking Card
  // ----------------------------------
  Widget buildBookingCard(Map<String, dynamic> booking, {bool isUpcoming = true}) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text("${booking['court']} - ${booking['sport']}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${booking['team']}"),
            Text("${booking['date']} at ${booking['time']} - ${booking['endTime']}"),
            Text(
              "Status: ${booking['status']}",
              style: TextStyle(
                color: booking['status'] == 'Confirmed'
                    ? Colors.green
                    : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            if (isUpcoming) {
              cancelBooking(booking['id']);
            } else {
              addResult(booking);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isUpcoming ? Colors.redAccent : Colors.green,
          ),
          child: Text(isUpcoming ? "Cancel" : "Add Result"),
        ),
      ),
    );
  }

  // ----------------------------------
  // Build Page
  // ----------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Bookings"),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
                        onPressed: _fetchBookings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -----------------------------
                        // Incoming Bookings
                        // -----------------------------
                        const Text(
                          "Incoming Bookings",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        incomingBookings.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No incoming bookings'),
                              )
                            : Column(
                                children: incomingBookings
                                    .map((booking) => buildIncomingBookingCard(booking))
                                    .toList(),
                              ),
                        const SizedBox(height: 20),
                        // -----------------------------
                        // Upcoming Bookings
                        // -----------------------------
                        const Text(
                          "Upcoming Bookings",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        upcomingBookings.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No upcoming bookings'),
                              )
                            : Column(
                                children: upcomingBookings
                                    .map((booking) => buildBookingCard(booking, isUpcoming: true))
                                    .toList(),
                              ),
                        const SizedBox(height: 20),
                        // -----------------------------
                        // Past Bookings
                        // -----------------------------
                        const Text(
                          "Past Bookings",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        pastBookings.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No past bookings'),
                              )
                            : Column(
                                children: pastBookings
                                    .map((booking) => buildBookingCard(booking, isUpcoming: false))
                                    .toList(),
                              ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
