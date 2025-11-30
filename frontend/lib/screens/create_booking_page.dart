import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../widgets/time_slot_grid.dart';

class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({super.key});

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  List<Map<String, dynamic>> verifiedCourts = [];
  bool isLoadingCourts = true;
  String? errorMessage;
  String? selectedCourtId;
  Map<String, dynamic>? selectedCourt;
  int? selectedStartSlot; // Index of selected start slot (dayIndex * 24 + hour)
  int? selectedEndSlot; // Index of selected end slot
  bool isCreatingBooking = false;

  @override
  void initState() {
    super.initState();
    _fetchVerifiedCourts();
  }

  Future<void> _fetchVerifiedCourts() async {
    setState(() {
      isLoadingCourts = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          errorMessage = 'No authentication token found';
          isLoadingCourts = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/courts/verified'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        setState(() {
          verifiedCourts = List<Map<String, dynamic>>.from(
            data['data']?['courts'] ?? data['courts'] ?? [],
          );
          isLoadingCourts = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load courts';
          isLoadingCourts = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoadingCourts = false;
      });
    }
  }

  void _selectCourt(Map<String, dynamic> court) {
    setState(() {
      selectedCourtId = court['id'];
      selectedCourt = court;
      selectedStartSlot = null;
      selectedEndSlot = null;
    });
  }

  List<DateTime> _getNext7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  List<int> _getAvailableHours() {
    if (selectedCourt == null) return [];
    final openingTime = selectedCourt!['openingTime'] ?? 8;
    final closingTime = selectedCourt!['closingTime'] ?? 23;
    return List.generate(closingTime - openingTime + 1, (index) => openingTime + index);
  }

  void _selectTimeSlot(int dayIndex, int hour) {
    final slotIndex = dayIndex * 24 + hour;

    setState(() {
      if (selectedStartSlot == null) {
        // First selection - set as start
        selectedStartSlot = slotIndex;
        selectedEndSlot = slotIndex;
      } else if (selectedStartSlot == slotIndex && selectedEndSlot == slotIndex) {
        // Clicking the same slot again - deselect
        selectedStartSlot = null;
        selectedEndSlot = null;
      } else {
        // Check if clicking on the same day
        final startDay = selectedStartSlot! ~/ 24;
        final startHour = selectedStartSlot! % 24;

        if (dayIndex == startDay) {
          // Same day - allow selecting 2-3 consecutive hours
          if (hour == startHour + 1 || hour == startHour + 2) {
            selectedEndSlot = slotIndex;
          } else if (hour < startHour) {
            // Selecting before start - make it new start
            selectedStartSlot = slotIndex;
            selectedEndSlot = selectedStartSlot;
          } else if (hour > startHour + 2) {
            // Too far - reset selection
            selectedStartSlot = slotIndex;
            selectedEndSlot = slotIndex;
          }
        } else {
          // Different day - reset to new selection
          selectedStartSlot = slotIndex;
          selectedEndSlot = slotIndex;
        }
      }
    });
  }


  DateTime? _getSelectedStartDateTime() {
    if (selectedStartSlot == null || selectedCourt == null) return null;
    final days = _getNext7Days();
    final startDay = selectedStartSlot! ~/ 24;
    final startHour = selectedStartSlot! % 24;
    final day = days[startDay];
    return DateTime(day.year, day.month, day.day, startHour);
  }

  DateTime? _getSelectedEndDateTime() {
    if (selectedEndSlot == null || selectedCourt == null) return null;
    final days = _getNext7Days();
    final endDay = selectedEndSlot! ~/ 24;
    final endHour = selectedEndSlot! % 24;
    final day = days[endDay];
    return DateTime(day.year, day.month, day.day, endHour + 1); // End time is hour + 1
  }

  String _formatDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dateTime.day} ${months[dateTime.month - 1]}, ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:00';
  }

  String _getDayName(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  Future<void> _createBooking() async {
    if (selectedCourtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a court'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final startDateTime = _getSelectedStartDateTime();
    final endDateTime = _getSelectedEndDateTime();

    if (startDateTime == null || endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select 2-3 consecutive time slots'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid time selection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isCreatingBooking = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication token not found'),
            backgroundColor: Colors.red,
          ),
        );
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
          'courtID': selectedCourtId!,
          'startTime': startDateTime.toIso8601String(),
          'endTime': endDateTime.toIso8601String(),
        }),
      );

      setState(() {
        isCreatingBooking = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Booking created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to create booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isCreatingBooking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCourtCard(Map<String, dynamic> court) {
    final isSelected = selectedCourtId == court['id'];
    return InkWell(
      onTap: () => _selectCourt(court),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent.withOpacity(0.2) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.redAccent : Colors.redAccent.withOpacity(0.3),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: Colors.redAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    court['name'] ?? 'Unknown Court',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    court['address'] ?? 'Unknown Address',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${court['rating'] ?? 0}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.redAccent,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotGrid() {
    if (selectedCourtId == null) {
      return const SizedBox.shrink();
    }

    final days = _getNext7Days();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TimeSlotGrid(
          selectedCourt: selectedCourt,
          selectedStartSlot: selectedStartSlot,
          selectedEndSlot: selectedEndSlot,
          onSlotSelected: _selectTimeSlot,
          onChallengeAccepted: () {
            setState(() {
              selectedStartSlot = null;
              selectedEndSlot = null;
            });
          },
          days: days,
        ),
        
        const SizedBox(height: 20),
        
        // Selected time display
        if (selectedStartSlot != null && selectedEndSlot != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Time:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDateTime(_getSelectedStartDateTime()!)} - ${_formatDateTime(_getSelectedEndDateTime()!)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 30),
        
        // Create Booking Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isCreatingBooking ? null : _createBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isCreatingBooking
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Book Court',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text(
          'Book a Court',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoadingCourts
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
                        onPressed: _fetchVerifiedCourts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select a Court',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a court for your friendly match',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (verifiedCourts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'No courts available',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      else
                        ...verifiedCourts.map((court) => _buildCourtCard(court)),
                      _buildTimeSlotGrid(),
                    ],
                  ),
                ),
    );
  }
}
