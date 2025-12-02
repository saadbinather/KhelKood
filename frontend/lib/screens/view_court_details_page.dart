import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'payment_summary_page.dart';
import 'login_page.dart';

class ViewCourtDetailsPage extends StatefulWidget {
  final String courtId;
  final String actionType;

  const ViewCourtDetailsPage({
    super.key,
    required this.courtId,
    required this.actionType,
  });

  @override
  State<ViewCourtDetailsPage> createState() => _ViewCourtDetailsPageState();
}

class _ViewCourtDetailsPageState extends State<ViewCourtDetailsPage> {
  Map<String, dynamic>? courtData;
  List<String> allTimes = [];

  DateTime selectedDate = DateTime.now();
  List<String> selectedSlots = [];
  String? selectedFieldName;
  bool isCreatingChallenge = false;
  bool isCreatingBooking = false;

  // -------------------- SIMULATED API --------------------
  Future<Map<String, dynamic>> _fetchCourtDetails() async {
    await Future.delayed(const Duration(milliseconds: 400));

    return {
      "courtId": widget.courtId,
      "name": "Zee Sports Complex",
      "address": "Main Boulevard, Model Town",
      "openingTime": 8,
      "closingTime": 23,
      "rating": 9.5,
      "sport": "futsal",
      "rate": 2000,
      "numOfFields": 3,
      "contact": "0312-9876543",
      "fields": [
        {
          "name": "Futsal Field 1",
          "slots": List.generate(23 - 8, (i) {
            final start = 8 + i;
            final end = start + 1;
            return {"time": "$start–$end", "available": i % 3 != 0};
          }),
        },
        {
          "name": "Futsal Field 2",
          "slots": List.generate(23 - 8, (i) {
            final start = 8 + i;
            final end = start + 1;
            return {"time": "$start–$end", "available": i % 4 != 0};
          }),
        },
        {
          "name": "Futsal Field 3",
          "slots": List.generate(23 - 8, (i) {
            final start = 8 + i;
            final end = start + 1;
            return {"time": "$start–$end", "available": i % 2 == 0};
          }),
        },
      ],
    };
  }

  bool isConsecutive(List<String> selected) {
    if (selected.length < 2) return true;

    List<int> indices = selected.map((t) => allTimes.indexOf(t)).toList()
      ..sort();

    for (int i = 1; i < indices.length; i++) {
      if (indices[i] - indices[i - 1] != 1) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadCourt();
  }

  Future<void> _loadCourt() async {
    final data = await _fetchCourtDetails();
    if (!mounted) return;

    final open = data["openingTime"];
    final close = data["closingTime"];

    allTimes = [for (int h = open; h < close; h++) "$h–${h + 1}"];

    setState(() {
      courtData = data;
      selectedSlots = [];
      selectedFieldName = null;
    });
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  DateTime? _getStartDateTime() {
    if (selectedSlots.isEmpty) return null;
    final sortedSlots = List<String>.from(selectedSlots)..sort();
    final firstSlot = sortedSlots.first;
    final parts = firstSlot.split('–');
    if (parts.length != 2) return null;
    final startHour = int.tryParse(parts[0]);
    if (startHour == null) return null;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startHour,
    );
  }

  DateTime? _getEndDateTime() {
    if (selectedSlots.isEmpty) return null;
    final sortedSlots = List<String>.from(selectedSlots)..sort();
    final lastSlot = sortedSlots.last;
    final parts = lastSlot.split('–');
    if (parts.length != 2) return null;
    final endHour = int.tryParse(parts[1]);
    if (endHour == null) return null;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      endHour,
    );
  }

  Future<bool> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null;
  }

  Future<void> _showLoginDialog(Function onLoginSuccess) async {
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Login Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You need to login to continue. Would you like to login now?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );

    if (shouldLogin == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      
      // Check if user logged in after returning
      if (mounted) {
        final isAuthenticated = await _checkAuth();
        if (isAuthenticated) {
          onLoginSuccess();
        }
      }
    }
  }

  Future<void> _createChallenge() async {
    if (selectedSlots.isEmpty) {
      _error("Select at least one time slot.");
      return;
    }
    if (!isConsecutive(selectedSlots)) {
      _error("Select consecutive time slots only.");
      return;
    }

    final startDateTime = _getStartDateTime();
    final endDateTime = _getEndDateTime();

    if (startDateTime == null || endDateTime == null) {
      _error("Invalid time selection.");
      return;
    }

    // Check authentication
    final isAuthenticated = await _checkAuth();
    if (!isAuthenticated) {
      await _showLoginDialog(_createChallenge);
      return;
    }

    setState(() {
      isCreatingChallenge = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          isCreatingChallenge = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:5000/api/challenges/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'courtFirebaseUID': widget.courtId,
          'stime': startDateTime.toIso8601String(),
          'etime': endDateTime.toIso8601String(),
        }),
      );

      setState(() {
        isCreatingChallenge = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Challenge created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear selection
          setState(() {
            selectedSlots.clear();
            selectedFieldName = null;
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Failed to create challenge'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isCreatingChallenge = false;
      });
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

  void _showActionDialog() {
    if (selectedSlots.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Select Action',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What would you like to do with the selected slots?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createChallenge();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Create Challenge',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _bookForYourself();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Book for Yourself (Friendly)',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bookForYourself() async {
    if (selectedSlots.isEmpty) {
      _error("Select at least one time slot.");
      return;
    }
    if (!isConsecutive(selectedSlots)) {
      _error("Select consecutive time slots only.");
      return;
    }

    final startDateTime = _getStartDateTime();
    final endDateTime = _getEndDateTime();

    if (startDateTime == null || endDateTime == null) {
      _error("Invalid time selection.");
      return;
    }

    // Check authentication
    final isAuthenticated = await _checkAuth();
    if (!isAuthenticated) {
      await _showLoginDialog(_bookForYourself);
      return;
    }

    setState(() {
      isCreatingBooking = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          isCreatingBooking = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:5000/api/booking/book-court'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'courtID': widget.courtId,
          'startTime': startDateTime.toIso8601String(),
          'endTime': endDateTime.toIso8601String(),
        }),
      );

      setState(() {
        isCreatingBooking = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Booking created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear selection
          setState(() {
            selectedSlots.clear();
            selectedFieldName = null;
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Failed to create booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isCreatingBooking = false;
      });
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

  @override
  Widget build(BuildContext context) {
    if (courtData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0E0E),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final fields = courtData!['fields'] as List;

    final screenWidth = MediaQuery.of(context).size.width;
    final timeColWidth = screenWidth * 0.25;
    final fieldColWidth = screenWidth * 0.45;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        centerTitle: true,
        title: Text(
          "${courtData!['name']} • ${courtData!['sport'].toString().toUpperCase()}",
          style: const TextStyle(color: Colors.white),
        ),
      ),

      body: Column(
        children: [
          // -------------------- TOP INFO --------------------
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courtData!['address'],
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      "Rate: Rs ${courtData!['rate']}/hr",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Fields: ${courtData!['numOfFields']}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amberAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          courtData!['rating'].toString(),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // -------------------- CALENDAR --------------------
          SizedBox(
            height: 85,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (_, i) {
                final date = DateTime.now().add(Duration(days: i));
                final selected =
                    date.day == selectedDate.day &&
                    date.month == selectedDate.month;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDate = date;
                      selectedSlots.clear();
                      selectedFieldName = null;
                    });
                  },
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.deepPurpleAccent
                          : Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            [
                              "Sun",
                              "Mon",
                              "Tue",
                              "Wed",
                              "Thu",
                              "Fri",
                              "Sat",
                            ][date.weekday % 7],
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${date.day}",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // -------------------- SLOTS TABLE --------------------
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // ------------ TIME COLUMN -------------
                  Column(
                    children: [
                      _header("Time", timeColWidth),
                      ...allTimes.map(
                        (t) => _cell(t, timeColWidth, Colors.transparent, true),
                      ),
                    ],
                  ),

                  // ------------ FIELD COLUMNS -------------
                  ...fields.map((field) {
                    final name = field['name'];
                    final slots = field['slots'] as List;

                    return Column(
                      children: [
                        _header(name, fieldColWidth),
                        ...slots.map((slot) {
                          final time = slot["time"];
                          final available = slot["available"];

                          final selected =
                              selectedSlots.contains(time) &&
                              selectedFieldName == name;

                          return GestureDetector(
                            onTap: () {
                              if (!available) return;

                              setState(() {
                                selectedFieldName ??= name;

                                if (selectedFieldName != name) {
                                  _error("Select slots only from one field.");
                                  return;
                                }

                                if (selected) {
                                  selectedSlots.remove(time);
                                  if (selectedSlots.isEmpty) {
                                    selectedFieldName = null;
                                  }
                                } else {
                                  selectedSlots.add(time);
                                  // Show dialog when slots are selected
                                  if (selectedSlots.length == 1) {
                                    _showActionDialog();
                                  }
                                }
                              });
                            },
                            child: _slot(
                              available: available,
                              selected: selected,
                              width: fieldColWidth,
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),

          // -------------------- SELECTED SLOTS INFO --------------------
          if (selectedSlots.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Slots:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedSlots.join(', '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isCreatingChallenge || isCreatingBooking) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: CircularProgressIndicator(
                        color: Colors.redAccent,
                      ),
              ),
                  ],
                ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- UI HELPERS --------------------

  Widget _header(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.red,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _cell(String text, double width, Color bg, bool isTime) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      height: 55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.red),
      ),
      child: Text(
        text,
        style: TextStyle(color: isTime ? Colors.white70 : Colors.white),
      ),
    );
  }

  Widget _slot({
    required bool available,
    required bool selected,
    required double width,
  }) {
    return Container(
      width: width,
      height: 55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: !available
            ? Colors.black
            : selected
            ? Colors.deepPurpleAccent
            : Colors.grey[900],
        border: Border.all(color: Colors.red),
      ),
      child: available
          ? (selected
                ? const Icon(Icons.check, color: Colors.white)
                : const SizedBox.shrink())
          : const Icon(Icons.block, color: Colors.red),
    );
  }
}
