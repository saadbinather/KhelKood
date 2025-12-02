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
              backgroundColor: Color(0xFF4CAF50),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Select Match Winner',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      payment['team']?.toString() ?? 'Match',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sport.toLowerCase() == 'futsal' || sport.toLowerCase() == 'football') ...[
                    RadioListTile<String>(
                      title: Text('$hostTeamName (Host)', style: const TextStyle(color: Color(0xFF2E7D32))),
                      value: 'host',
                      groupValue: isTie ? null : (selectedWinner ?? ''),
                      activeColor: const Color(0xFF4CAF50),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWinner = value ?? '';
                          isTie = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('$guestTeamName (Guest)', style: const TextStyle(color: Color(0xFF2E7D32))),
                      value: 'guest',
                      groupValue: isTie ? null : (selectedWinner ?? ''),
                      activeColor: const Color(0xFF4CAF50),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWinner = value ?? '';
                          isTie = false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Tie', style: TextStyle(color: Color(0xFF2E7D32))),
                      value: isTie,
                      activeColor: const Color(0xFF4CAF50),
                      onChanged: (value) {
                        setDialogState(() {
                          isTie = value ?? false;
                          if (isTie) selectedWinner = null;
                        });
                      },
                    ),
                  ] else ...[
                    RadioListTile<String>(
                      title: Text('$hostTeamName (Host)', style: const TextStyle(color: Color(0xFF2E7D32))),
                      value: 'host',
                      groupValue: selectedWinner ?? '',
                      activeColor: const Color(0xFF4CAF50),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWinner = value ?? '';
                          isTie = false;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('$guestTeamName (Guest)', style: const TextStyle(color: Color(0xFF2E7D32))),
                      value: 'guest',
                      groupValue: selectedWinner ?? '',
                      activeColor: const Color(0xFF4CAF50),
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
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
              backgroundColor: Color(0xFF4CAF50),
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
    final isMatch = payment['type'] == 'match';
    final amount = payment['amount'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (isPaid 
              ? const Color(0xFF4CAF50) 
              : Colors.orange).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isPaid 
                        ? const Color(0xFF4CAF50) 
                        : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isMatch ? Icons.sports_soccer : Icons.event,
                    color: isPaid 
                        ? const Color(0xFF4CAF50) 
                        : Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment['team'] ?? 'Unknown Team',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          fontSize: 16,
                        ),
                      ),
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
                            payment['court'] ?? 'Unknown Court',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isPaid 
                        ? const Color(0xFF4CAF50) 
                        : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPaid 
                          ? const Color(0xFF4CAF50) 
                          : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isPaid ? "Paid" : "Pending",
                    style: TextStyle(
                      color: isPaid 
                          ? const Color(0xFF4CAF50) 
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF2E7D32).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Rs. ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        amount.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPaid)
                  ElevatedButton.icon(
                    onPressed: () => _markAsPaid(
                      payment['id']?.toString() ?? '',
                      matchID: payment['matchID']?.toString(),
                      sport: payment['sport']?.toString(),
                    ),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      isMatch ? 'Mark Paid' : 'Mark Paid',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  // -----------------------------
  // Build page
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "Payments",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
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
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                )
              : errorMessagePending != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessagePending!,
                        style: const TextStyle(color: Color(0xFF2E7D32)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPendingPayments,
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
              : (pendingBookings.isEmpty && pendingMatches.isEmpty)
              ? const Center(
                  child: Text(
                    'No pending payments',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPendingPayments,
                  color: const Color(0xFF4CAF50),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // Bookings Section
                      if (pendingBookings.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Bookings (Friendly Matches)',
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...pendingBookings.map((payment) => buildPaymentCard(payment, false)),
                        const SizedBox(height: 8),
                      ],
                      // Matches/Challenges Section
                      if (pendingMatches.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Challenges (Competitive Matches)',
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 18,
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
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                )
              : errorMessagePaid != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessagePaid!,
                        style: const TextStyle(color: Color(0xFF2E7D32)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPaidBookings,
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
              : paidBookings.isEmpty
              ? const Center(
                  child: Text(
                    'No paid bookings',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPaidBookings,
                  color: const Color(0xFF4CAF50),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
