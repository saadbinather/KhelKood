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

  List<Map<String, dynamic>> pendingBookings = [];
  List<Map<String, dynamic>> pendingMatches = [];
  List<Map<String, dynamic>> paidBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0 && pendingBookings.isEmpty && pendingMatches.isEmpty) {
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

      print('Pending payments response status: ${response.statusCode}');
      print('Pending payments response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final dataObj = data['data'] as Map<String, dynamic>?;
        
        // Handle bookings
        final bookingsList = dataObj?['bookings'] as List<dynamic>? ?? [];
        final bookings = bookingsList.map((item) {
          final payment = item as Map<String, dynamic>?;
          final booking = payment?['booking'] as Map<String, dynamic>?;
          final team = payment?['team'] as Map<String, dynamic>?;
          final court = payment?['court'] as Map<String, dynamic>?;
          
          return {
            'id': payment?['id']?.toString() ?? '',
            'amount': payment?['amount'] ?? 0,
            'type': 'booking',
            'team': team?['teamName']?.toString() ?? 'Unknown Team',
            'court': court?['name']?.toString() ?? 'Unknown Court',
            'startTime': booking?['startTime'],
            'endTime': booking?['endTime'],
          };
        }).toList();

        // Handle matches
        final matchesList = dataObj?['matches'] as List<dynamic>? ?? [];
        final matches = matchesList.map((item) {
          final payment = item as Map<String, dynamic>?;
          final match = payment?['match'] as Map<String, dynamic>?;
          final hostTeam = payment?['hostTeam'] as Map<String, dynamic>?;
          final guestTeam = payment?['guestTeam'] as Map<String, dynamic>?;
          final court = payment?['court'] as Map<String, dynamic>?;
          
          return {
            'id': payment?['id']?.toString() ?? '',
            'amount': payment?['amount'] ?? 0,
            'type': 'match',
            'matchID': match?['id']?.toString() ?? '',
            'sport': match?['Sport']?.toString() ?? 'Unknown',
            'hostTeam': hostTeam?['teamName']?.toString() ?? 'Unknown',
            'guestTeam': guestTeam?['teamName']?.toString() ?? 'Unknown',
            'hostTeamID': match?['Host_Team_ID']?.toString() ?? '',
            'guestTeamID': match?['Guest_Team_ID']?.toString() ?? '',
            'team': '${hostTeam?['teamName'] ?? 'Unknown'} vs ${guestTeam?['teamName'] ?? 'Unknown'}',
            'court': court?['name']?.toString() ?? 'Unknown Court',
            'startTime': match?['StartTime'],
            'endTime': match?['EndTime'],
          };
        }).toList();

        setState(() {
          pendingBookings = bookings;
          pendingMatches = matches;
          isLoadingPending = false;
        });
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        setState(() {
          errorMessagePending =
              errorData?['error']?.toString() ?? 'Failed to fetch pending payments';
          isLoadingPending = false;
        });
      }
    } catch (e) {
      print('Error fetching pending payments: $e');
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final dataObj = data['data'] as Map<String, dynamic>?;
        final bookingsList = dataObj?['bookings'] as List<dynamic>? ?? [];

        setState(() {
          paidBookings = bookingsList.map((item) {
            final booking = item['booking'] as Map<String, dynamic>?;
            final payment = item['payment'] as Map<String, dynamic>?;
            final team = item['team'] as Map<String, dynamic>?;
            final court = item['court'] as Map<String, dynamic>?;
            
            return {
              'id': booking?['id']?.toString() ?? '',
              'amount': payment?['amount'] ?? 0,
              'team': team?['teamName']?.toString() ?? 'Unknown Team',
              'court': court?['name']?.toString() ?? 'Unknown Court',
              'startTime': booking?['startTime'],
              'endTime': booking?['endTime'],
            };
          }).toList();
          isLoadingPaid = false;
        });
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        setState(() {
          errorMessagePaid =
              errorData?['error']?.toString() ?? 'Failed to fetch paid bookings';
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

  Future<void> _markAsPaid(String paymentID, {String? matchID, String? sport}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No authentication token found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // If it's a match, show winner selection dialog
      if (matchID != null && matchID.isNotEmpty) {
        _showMatchWinnerDialog(paymentID, matchID, sport ?? '');
        return;
      }

      // For bookings, just mark as paid
      final response = await http.put(
        Uri.parse('$baseUrl/payments/update-payment/$paymentID'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment marked as paid successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchPendingPayments();
          await _fetchPaidBookings();
        }
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData?['error']?.toString() ?? 'Failed to update payment'),
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

  void _showMatchWinnerDialog(String paymentID, String matchID, String sport) {
    String? selectedWinner;
    bool isTie = false;

    // Get the payment to extract team IDs (check both lists)
    final payment = [...pendingBookings, ...pendingMatches].firstWhere(
      (p) => p['id']?.toString() == paymentID,
      orElse: () => <String, dynamic>{},
    );
    
    final hostTeamID = payment['hostTeamID']?.toString() ?? '';
    final guestTeamID = payment['guestTeamID']?.toString() ?? '';
    final hostTeamName = payment['hostTeam']?.toString() ?? 'Host Team';
    final guestTeamName = payment['guestTeam']?.toString() ?? 'Guest Team';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (buildContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Select Match Winner',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    payment['team']?.toString() ?? 'Match',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  if (sport.toLowerCase() == 'futsal' || sport.toLowerCase() == 'football') ...[
                    RadioListTile<String>(
                      title: Text('$hostTeamName (Host)', style: const TextStyle(color: Colors.white)),
                      value: 'host',
                      groupValue: isTie ? null : (selectedWinner ?? ''),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWinner = value ?? '';
                          isTie = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('$guestTeamName (Guest)', style: const TextStyle(color: Colors.white)),
                      value: 'guest',
                      groupValue: isTie ? null : (selectedWinner ?? ''),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWinner = value ?? '';
                          isTie = false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Tie', style: TextStyle(color: Colors.white)),
                      value: isTie,
                      onChanged: (value) {
                        setDialogState(() {
                          isTie = value ?? false;
                          if (isTie) selectedWinner = null;
                        });
                      },
                    ),
                  ] else ...[
                    RadioListTile<String>(
                      title: Text('$hostTeamName (Host)', style: const TextStyle(color: Colors.white)),
                      value: 'host',
                      groupValue: selectedWinner ?? '',
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWinner = value ?? '';
                          isTie = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('$guestTeamName (Guest)', style: const TextStyle(color: Colors.white)),
                      value: 'guest',
                      groupValue: selectedWinner ?? '',
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWinner = value ?? '';
                          isTie = false;
                        });
                      },
                    ),
                  ],
                ],
              ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: (selectedWinner == null && !isTie)
                  ? null
                  : () async {
                      await _updatePaymentStatus(
                        paymentID,
                        matchID,
                        selectedWinner,
                        isTie,
                        payment,
                      );
                      if (mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePaymentStatus(
    String paymentID,
    String matchID,
    String? winner,
    bool isTie,
    Map<String, dynamic> payment,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No authentication token found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Determine winnerID based on selection
      String? winnerID;
      if (isTie) {
        winnerID = null; // Will be handled as tie
      } else if (winner == 'host') {
        winnerID = payment['hostTeamID']?.toString();
      } else if (winner == 'guest') {
        winnerID = payment['guestTeamID']?.toString();
      }

      final response = await http.put(
        Uri.parse('$baseUrl/payments/update-payment/$paymentID'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'matchID': matchID,
          'winnerID': winnerID,
          'isTie': isTie,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment updated and winner selected successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchPendingPayments();
          await _fetchPaidBookings();
        }
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData?['error']?.toString() ?? 'Failed to update payment'),
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
                onPressed: () => _markAsPaid(
                  payment['id']?.toString() ?? '',
                  matchID: payment['matchID']?.toString(),
                  sport: payment['sport']?.toString(),
                ),
                tooltip: payment['type'] == 'match' 
                    ? 'Select winner & mark paid' 
                    : 'Mark as paid',
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
              : (pendingBookings.isEmpty && pendingMatches.isEmpty)
              ? const Center(
                  child: Text(
                    'No pending payments',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPendingPayments,
                  color: Colors.redAccent,
                  child: ListView(
                    children: [
                      // Bookings Section
                      if (pendingBookings.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Bookings (Friendly Matches)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...pendingBookings.map((payment) => buildPaymentCard(payment, false)),
                        const SizedBox(height: 16),
                      ],
                      // Matches/Challenges Section
                      if (pendingMatches.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Challenges (Competitive Matches)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...pendingMatches.map((payment) => buildPaymentCard(payment, false)),
                      ],
                    ],
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
