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

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoadingPending = true;
  bool isLoadingPaid = true;
  String? errorMessagePending;
  String? errorMessagePaid;

  List<Map<String, dynamic>> pendingPayments = [];
  List<Map<String, dynamic>> paidBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0 && pendingPayments.isEmpty) {
        _fetchPendingPayments();
      } else if (_tabController.index == 1 && paidBookings.isEmpty) {
        _fetchPaidBookings();
      }
    });
    _fetchPendingPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingPayments() async {
    setState(() {
      isLoadingPending = true;
      errorMessagePending = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          errorMessagePending = 'No authentication token found';
          isLoadingPending = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/payments/pending-payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final payments = data['data']['payments'] as List<dynamic>;

        setState(() {
          pendingPayments = payments.map((payment) {
            return {
              'id': payment['id'],
              'amount': payment['amount'],
              'team': payment['team']?['teamName'] ?? 'Unknown Team',
              'court': payment['court']?['name'] ?? 'Unknown Court',
              'startTime': payment['booking']?['startTime'],
              'endTime': payment['booking']?['endTime'],
            };
          }).toList();
          isLoadingPending = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessagePending =
              errorData['error'] ?? 'Failed to fetch pending payments';
          isLoadingPending = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessagePending = 'Error: ${e.toString()}';
        isLoadingPending = false;
      });
    }
  }

  Future<void> _fetchPaidBookings() async {
    setState(() {
      isLoadingPaid = true;
      errorMessagePaid = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          errorMessagePaid = 'No authentication token found';
          isLoadingPaid = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/payments/paid-bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bookings = data['data']['bookings'] as List<dynamic>;

        setState(() {
          paidBookings = bookings.map((item) {
            return {
              'id': item['booking']?['id'],
              'amount': item['payment']?['amount'] ?? 0,
              'team': item['team']?['teamName'] ?? 'Unknown Team',
              'court': item['court']?['name'] ?? 'Unknown Court',
              'startTime': item['booking']?['startTime'],
              'endTime': item['booking']?['endTime'],
            };
          }).toList();
          isLoadingPaid = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessagePaid =
              errorData['error'] ?? 'Failed to fetch paid bookings';
          isLoadingPaid = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessagePaid = 'Error: ${e.toString()}';
        isLoadingPaid = false;
      });
    }
  }

  Future<void> _markAsPaid(String paymentID) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/payments/update-payment/$paymentID'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment marked as paid successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh both lists
          await _fetchPendingPayments();
          await _fetchPaidBookings();
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Failed to update payment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown date';
    try {
      DateTime date;
      if (dateValue is Map) {
        // Firestore Timestamp format
        if (dateValue['_seconds'] != null) {
          date = DateTime.fromMillisecondsSinceEpoch(
            dateValue['_seconds'] * 1000,
          );
        } else {
          return 'Invalid date';
        }
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Invalid date';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatTime(dynamic dateValue) {
    if (dateValue == null) return 'Unknown time';
    try {
      DateTime date;
      if (dateValue is Map) {
        // Firestore Timestamp format
        if (dateValue['_seconds'] != null) {
          date = DateTime.fromMillisecondsSinceEpoch(
            dateValue['_seconds'] * 1000,
          );
        } else {
          return 'Invalid time';
        }
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Invalid time';
      }
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } catch (e) {
      return 'Invalid time';
    }
  }

  // -----------------------------
  // Payment card widget
  // -----------------------------
  Widget buildPaymentCard(Map<String, dynamic> payment, bool isPaid) {
    final date = _formatDate(payment['endTime'] ?? payment['startTime']);
    final time = _formatTime(payment['endTime'] ?? payment['startTime']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(
          payment['team'] ?? 'Unknown Team',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          "${payment['court'] ?? 'Unknown Court'} | $date at $time",
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "₹${payment['amount'] ?? 0}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaid ? "Paid" : "Pending",
                  style: TextStyle(
                    color: isPaid ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (!isPaid) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _markAsPaid(payment['id']),
                tooltip: 'Mark as paid',
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text("Payments", style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Paid"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // -------------------------
          // Pending Payments
          // -------------------------
          isLoadingPending
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                )
              : errorMessagePending != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessagePending!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPendingPayments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : pendingPayments.isEmpty
              ? const Center(
                  child: Text(
                    'No pending payments',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPendingPayments,
                  color: Colors.redAccent,
                  child: ListView.builder(
                    itemCount: pendingPayments.length,
                    itemBuilder: (context, index) {
                      return buildPaymentCard(pendingPayments[index], false);
                    },
                  ),
                ),

          // -------------------------
          // Paid Bookings
          // -------------------------
          isLoadingPaid
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                )
              : errorMessagePaid != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessagePaid!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPaidBookings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : paidBookings.isEmpty
              ? const Center(
                  child: Text(
                    'No paid bookings',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPaidBookings,
                  color: Colors.redAccent,
                  child: ListView.builder(
                    itemCount: paidBookings.length,
                    itemBuilder: (context, index) {
                      return buildPaymentCard(paidBookings[index], true);
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
