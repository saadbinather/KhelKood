import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CreateChallengePage extends StatefulWidget {
  const CreateChallengePage({super.key});

  @override
  State<CreateChallengePage> createState() => _CreateChallengePageState();
}

class _CreateChallengePageState extends State<CreateChallengePage> {
  List<Map<String, dynamic>> verifiedCourts = [];
  bool isLoadingCourts = true;
  String? errorMessage;
  String? selectedCourtId;
  Map<String, dynamic>? selectedCourt;
  int? selectedStartSlot; // Index of selected start slot (dayIndex * 24 + hour)
  int? selectedEndSlot; // Index of selected end slot
  bool isCreatingChallenge = false;

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
            // Selecting before start - make it new start, keep old start as end
            final oldStartSlot = selectedStartSlot!;
            selectedStartSlot = slotIndex;
            selectedEndSlot = oldStartSlot;
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

  bool _isSlotSelected(int dayIndex, int hour) {
    if (selectedStartSlot == null || selectedEndSlot == null) return false;
    final slotIndex = dayIndex * 24 + hour;
    final start = selectedStartSlot!;
    final end = selectedEndSlot!;
    return slotIndex >= start && slotIndex <= end;
  }

  bool _isSlotInRange(int dayIndex, int hour) {
    if (selectedCourt == null) return false;
    final openingTime = selectedCourt!['openingTime'] ?? 8;
    final closingTime = selectedCourt!['closingTime'] ?? 23;
    return hour >= openingTime && hour <= closingTime;
  }

  DateTime? _getSelectedStartDateTime() {
    if (selectedStartSlot == null) return null;
    final days = _getNext7Days();
    final dayIndex = selectedStartSlot! ~/ 24;
    final hour = selectedStartSlot! % 24;
    if (dayIndex >= days.length) return null;
    return DateTime(
      days[dayIndex].year,
      days[dayIndex].month,
      days[dayIndex].day,
      hour,
    );
  }

  DateTime? _getSelectedEndDateTime() {
    if (selectedEndSlot == null) return null;
    final days = _getNext7Days();
    final dayIndex = selectedEndSlot! ~/ 24;
    final hour = selectedEndSlot! % 24;
    if (dayIndex >= days.length) return null;
    // End time is the next hour (e.g., if selected 2-3, end is 4)
    return DateTime(
      days[dayIndex].year,
      days[dayIndex].month,
      days[dayIndex].day,
      hour + 1,
    );
  }


  Future<void> _createChallenge() async {
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
      isCreatingChallenge = true;
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
          'courtFirebaseUID': selectedCourtId!,
          'stime': startDateTime.toIso8601String(),
          'etime': endDateTime.toIso8601String(),
        }),
      );

      setState(() {
        isCreatingChallenge = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Challenge created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to create challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isCreatingChallenge = false;
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
    final availableHours = _getAvailableHours();
    final openingTime = selectedCourt!['openingTime'] ?? 8;
    final closingTime = selectedCourt!['closingTime'] ?? 23;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Divider(color: Colors.white24),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Select Time Slot',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${openingTime}:00 - ${closingTime}:00',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Select 2-3 consecutive hours on the same day',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 20),
        
        // Time slot grid
        ...days.asMap().entries.map((entry) {
          final dayIndex = entry.key;
          final day = entry.value;
          final dayName = _getDayName(day);
          final dateStr = '${day.day}/${day.month}';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayName, $dateStr',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableHours.map((hour) {
                    final isSelected = _isSlotSelected(dayIndex, hour);
                    final isInRange = _isSlotInRange(dayIndex, hour);
                    
                    return GestureDetector(
                      onTap: isInRange ? () => _selectTimeSlot(dayIndex, hour) : null,
                      child: Container(
                        width: 60,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.redAccent
                              : isInRange
                                  ? Colors.grey[800]
                                  : Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.redAccent
                                : Colors.white24,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$hour:00',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isInRange
                                      ? Colors.white70
                                      : Colors.white38,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
        
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
        
        // Create Challenge Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isCreatingChallenge ? null : _createChallenge,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isCreatingChallenge
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Create Challenge',
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

  String _getDayName(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text(
          'Create Challenge',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Court',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a verified court for your challenge',
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
                              'No verified courts available',
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

