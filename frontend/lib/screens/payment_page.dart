import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<Map<String, dynamic>> bookingPayments = [];
  List<Map<String, dynamic>> matchPayments = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, bool> updatingPayments = {};
  Map<String, String?> selectedWinners = {};
  Map<String, bool> selectedTies = {};

  @override
  void initState() {
    super.initState();
    _fetchPendingPayments();
  }

  Future<void> _fetchPendingPayments() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          errorMessage = 'No authentication token found';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/payments/pending-payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        print('=== PAYMENTS DATA ===');
        print('Full response: $data');
        final bookingsList = data['data']?['bookings'] ?? data['bookings'];
        final matchesList = data['data']?['matches'] ?? data['matches'];
        print('Bookings: $bookingsList');
        print('Matches: $matchesList');
        print('===================');
        
        setState(() {
          bookingPayments = bookingsList != null && bookingsList is List
              ? List<Map<String, dynamic>>.from(
                  bookingsList.map((item) => item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{})
                )
              : <Map<String, dynamic>>[];
          matchPayments = matchesList != null && matchesList is List
              ? List<Map<String, dynamic>>.from(
                  matchesList.map((item) => item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{})
                )
              : <Map<String, dynamic>>[];
          isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Failed to load payments';
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

  Future<void> _updatePaymentStatus(String paymentID, {String? matchID, String? winnerID, bool? isTie}) async {
    setState(() {
      updatingPayments[paymentID] = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          updatingPayments[paymentID] = false;
        });
        return;
      }

      final body = <String, dynamic>{};
      if (matchID != null) body['matchID'] = matchID;
      if (winnerID != null) body['winnerID'] = winnerID;
      if (isTie != null) body['isTie'] = isTie;

      final response = await http.put(
        Uri.parse('http://localhost:5000/api/payments/update-payment/$paymentID'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh payments
        await _fetchPendingPayments();
      } else {
        if (!mounted) return;
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to update payment'),
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
    } finally {
      setState(() {
        updatingPayments[paymentID] = false;
        selectedWinners.remove(paymentID);
        selectedTies.remove(paymentID);
      });
    }
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Map) {
        if (dateValue['_seconds'] != null) {
          date = DateTime.fromMillisecondsSinceEpoch(dateValue['_seconds'] * 1000);
        } else if (dateValue['seconds'] != null) {
          date = DateTime.fromMillisecondsSinceEpoch(dateValue['seconds'] * 1000);
        } else {
          return 'Unknown';
        }
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Unknown';
      }
      // Format: "Dec 05, 2024 14:30"
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[date.month - 1];
      final day = date.day.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$month $day, $year $hour:$minute';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showMatchWinnerDialog(Map<String, dynamic> payment) {
    final match = payment['match'] as Map<String, dynamic>?;
    final hostTeam = payment['hostTeam'] as Map<String, dynamic>?;
    final guestTeam = payment['guestTeam'] as Map<String, dynamic>?;
    final sport = match?['Sport']?.toString() ?? 'futsal';
    final isFutsal = sport.toLowerCase() == 'futsal';

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match data not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (buildContext, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Select Match Result',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${hostTeam?['teamName'] ?? 'Host Team'} vs ${guestTeam?['teamName'] ?? 'Guest Team'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 20),
                // Winner options
                RadioListTile<String>(
                  title: Text(
                    '${hostTeam?['teamName'] ?? 'Host Team'} Wins',
                    style: const TextStyle(color: Colors.white),
                  ),
                  value: match['Host_Team_ID']?.toString() ?? '',
                  groupValue: selectedWinners[payment['id']],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedWinners[payment['id']] = value;
                      selectedTies[payment['id']] = false;
                    });
                  },
                  activeColor: Colors.redAccent,
                ),
                RadioListTile<String>(
                  title: Text(
                    '${guestTeam?['teamName'] ?? 'Guest Team'} Wins',
                    style: const TextStyle(color: Colors.white),
                  ),
                  value: match['Guest_Team_ID']?.toString() ?? '',
                  groupValue: selectedWinners[payment['id']],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedWinners[payment['id']] = value;
                      selectedTies[payment['id']] = false;
                    });
                  },
                  activeColor: Colors.redAccent,
                ),
                if (isFutsal)
                  CheckboxListTile(
                    title: const Text(
                      'Tie',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: selectedTies[payment['id']] ?? false,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedTies[payment['id']] = value ?? false;
                        if (value == true) {
                          selectedWinners[payment['id']] = null;
                        }
                      });
                    },
                    activeColor: Colors.redAccent,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(buildContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  final winnerID = selectedWinners[payment['id']];
                  final isTie = selectedTies[payment['id']] ?? false;
                  
                  if (winnerID == null && !isTie) {
                    ScaffoldMessenger.of(buildContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a winner or tie'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.pop(buildContext);
                  final paymentId = payment['id']?.toString();
                  final matchId = match?['id']?.toString();
                  if (paymentId != null) {
                    _updatePaymentStatus(
                      paymentId,
                      matchID: matchId,
                      winnerID: winnerID,
                      isTie: isTie,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.redAccent,
        title: const Text(
            'Pending Payments',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Bookings'),
              Tab(text: 'Matches'),
            ],
          ),
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
                          onPressed: _fetchPendingPayments,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchPendingPayments,
                    color: Colors.redAccent,
                    child: TabBarView(
                      children: [
                        // Bookings Tab
                        _buildBookingsList(),
                        // Matches Tab
                        _buildMatchesList(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildBookingsList() {
    if (bookingPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No pending booking payments',
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookingPayments.length,
      itemBuilder: (context, index) {
        final payment = bookingPayments[index];
        return _buildBookingCard(payment);
      },
    );
  }

  Widget _buildMatchesList() {
    if (matchPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_soccer, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No pending match payments',
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matchPayments.length,
      itemBuilder: (context, index) {
        final payment = matchPayments[index];
        return _buildMatchCard(payment);
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> payment) {
    final booking = payment['booking'] is Map 
        ? Map<String, dynamic>.from(payment['booking'] as Map) 
        : null;
    final court = payment['court'] is Map 
        ? Map<String, dynamic>.from(payment['court'] as Map) 
        : null;
    final team = payment['team'] is Map 
        ? Map<String, dynamic>.from(payment['team'] as Map) 
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court?['name'] ?? 'Unknown Court',
                      style: const TextStyle(
                      color: Colors.white,
                        fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                    const SizedBox(height: 4),
                    Text(
                      team?['teamName'] ?? 'Unknown Team',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
              Text(
                'Rs ${(payment['amount'] ?? 0).toString()}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (booking != null && booking['startTime'] != null && booking['endTime'] != null) ...[
            Text(
              'Time: ${_formatDate(booking['startTime'])} - ${_formatDate(booking['endTime'])}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (updatingPayments[payment['id']] ?? false) == true
                  ? null
                  : () => _updatePaymentStatus(payment['id']?.toString() ?? ''),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: (updatingPayments[payment['id']] ?? false) == true
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Mark as Paid'),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> payment) {
    final match = payment['match'] is Map 
        ? Map<String, dynamic>.from(payment['match'] as Map) 
        : null;
    final court = payment['court'] is Map 
        ? Map<String, dynamic>.from(payment['court'] as Map) 
        : null;
    final hostTeam = payment['hostTeam'] is Map 
        ? Map<String, dynamic>.from(payment['hostTeam'] as Map) 
        : null;
    final guestTeam = payment['guestTeam'] is Map 
        ? Map<String, dynamic>.from(payment['guestTeam'] as Map) 
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court?['name'] ?? 'Unknown Court',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
          Text(
                      '${hostTeam?['teamName'] ?? 'Host'} vs ${guestTeam?['teamName'] ?? 'Guest'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
          ),
          Text(
                'Rs ${(payment['amount'] ?? 0).toString()}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (match != null) ...[
            if (match['StartTime'] != null && match['EndTime'] != null)
              Text(
                'Time: ${_formatDate(match['StartTime'])} - ${_formatDate(match['EndTime'])}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (match['StartTime'] != null && match['EndTime'] != null)
              const SizedBox(height: 4),
            Text(
              'Sport: ${match['Sport']?.toString() ?? 'Unknown'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (updatingPayments[payment['id']] ?? false) == true
                  ? null
                  : () => _showMatchWinnerDialog(payment),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: (updatingPayments[payment['id']] ?? false) == true
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
              color: Colors.white,
                      ),
                    )
                  : const Text('Select Winner & Mark Paid'),
            ),
          ),
        ],
      ),
    );
  }
}
