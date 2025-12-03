import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TimeSlotGrid extends StatefulWidget {
  final Map<String, dynamic>? selectedCourt;
  final int? selectedCourtNum; // Added: Selected court number
  final int? selectedStartSlot;
  final int? selectedEndSlot;
  final Function(int dayIndex, int hour) onSlotSelected;
  final VoidCallback?
  onChallengeAccepted; // Callback to clear selection after accepting challenge
  final List<DateTime> days;
  final String? sportType; // Sport type for showing appropriate icons

  const TimeSlotGrid({
    super.key,
    required this.selectedCourt,
    this.selectedCourtNum, // Added: Optional court number
    required this.selectedStartSlot,
    required this.selectedEndSlot,
    required this.onSlotSelected,
    this.onChallengeAccepted,
    required this.days,
    this.sportType,
  });

  @override
  State<TimeSlotGrid> createState() => _TimeSlotGridState();
}

class _TimeSlotGridState extends State<TimeSlotGrid> {
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> challenges = [];
  bool isLoadingConflicts = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedCourt != null) {
      _fetchConflicts();
    }
  }

  @override
  void didUpdateWidget(TimeSlotGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCourt != null &&
        (widget.selectedCourt!['id'] != oldWidget.selectedCourt?['id'] ||
            widget.selectedCourtNum != oldWidget.selectedCourtNum)) {
      _fetchConflicts();
    }
  }

  Future<void> _fetchConflicts() async {
    if (widget.selectedCourt == null) return;

    setState(() {
      isLoadingConflicts = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          isLoadingConflicts = false;
        });
        return;
      }

      final courtID = widget.selectedCourt!['id'];
      final courtNum = widget.selectedCourtNum;

      // Build URLs with courtNum query parameter if provided
      final bookingUrl = courtNum != null
          ? 'http://localhost:5000/api/booking/court/$courtID?courtNum=$courtNum'
          : 'http://localhost:5000/api/booking/court/$courtID';

      final challengeUrl = courtNum != null
          ? 'http://localhost:5000/api/challenges/court/$courtID?courtNum=$courtNum'
          : 'http://localhost:5000/api/challenges/court/$courtID';

      // Fetch bookings and challenges in parallel
      final bookingResponse = await http.get(
        Uri.parse(bookingUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final challengeResponse = await http.get(
        Uri.parse(challengeUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      setState(() {
        if (bookingResponse.statusCode >= 200 &&
            bookingResponse.statusCode < 300) {
          final bookingData = jsonDecode(bookingResponse.body);
          final allBookings = List<Map<String, dynamic>>.from(
            bookingData['data']?['bookings'] ?? bookingData['bookings'] ?? [],
          );

          // Filter bookings by sport type if sportType is provided
          if (widget.sportType != null) {
            final normalizedSport = widget.sportType!.toLowerCase();
            bookings = allBookings.where((booking) {
              // Show unavailable bookings (no sportType) - they block slots for everyone
              if (booking['isUnavailable'] == true ||
                  booking['sportType'] == null) {
                return true;
              }

              final bookingSport = (booking['sportType'] ?? '')
                  .toString()
                  .toLowerCase();
              // Handle football/futsal mapping
              if ((normalizedSport == 'futsal' ||
                      normalizedSport == 'football') &&
                  (bookingSport == 'futsal' || bookingSport == 'football')) {
                return true;
              }
              return bookingSport == normalizedSport;
            }).toList();
          } else {
            bookings = allBookings;
          }
        }

        if (challengeResponse.statusCode >= 200 &&
            challengeResponse.statusCode < 300) {
          final challengeData = jsonDecode(challengeResponse.body);
          final allChallenges = List<Map<String, dynamic>>.from(
            challengeData['data']?['challenges'] ??
                challengeData['challenges'] ??
                [],
          );

          // Filter challenges by sport type if sportType is provided
          if (widget.sportType != null) {
            final normalizedSport = widget.sportType!.toLowerCase();
            challenges = allChallenges.where((challenge) {
              final challengeSport = (challenge['sport'] ?? '')
                  .toString()
                  .toLowerCase();
              // Handle football/futsal mapping
              if ((normalizedSport == 'futsal' ||
                      normalizedSport == 'football') &&
                  (challengeSport == 'futsal' ||
                      challengeSport == 'football')) {
                return true;
              }
              return challengeSport == normalizedSport;
            }).toList();
          } else {
            challenges = allChallenges;
          }
        }

        isLoadingConflicts = false;
      });
    } catch (e) {
      setState(() {
        isLoadingConflicts = false;
      });
    }
  }

  List<int> _getAvailableHours() {
    if (widget.selectedCourt == null) return [];
    final openingTime = widget.selectedCourt!['openingTime'] ?? 8;
    final closingTime = widget.selectedCourt!['closingTime'] ?? 23;
    return List.generate(
      closingTime - openingTime + 1,
      (index) => openingTime + index,
    );
  }

  bool _isSlotBooked(int dayIndex, int hour) {
    if (widget.selectedCourt == null) return false;
    final days = widget.days;
    if (dayIndex >= days.length) return false;

    // Create slot time in local timezone (same as the day)
    final slotStart = DateTime(
      days[dayIndex].year,
      days[dayIndex].month,
      days[dayIndex].day,
      hour,
    );
    final slotEnd = slotStart.add(const Duration(hours: 1));

    // Check bookings - all bookings are considered (no status filtering)
    for (final booking in bookings) {
      final startTime = _parseTimestamp(booking['startTime']);
      final endTime = _parseTimestamp(booking['endTime']);

      if (startTime != null && endTime != null) {
        // Normalize times to same timezone for comparison
        final bookingStart = DateTime(
          startTime.year,
          startTime.month,
          startTime.day,
          startTime.hour,
        );
        final bookingEnd = DateTime(
          endTime.year,
          endTime.month,
          endTime.day,
          endTime.hour,
        );

        // Check if slot is completely within booking time range
        // Only mark as booked if the slot hour is within the booking's hour range
        // This ensures only the exact hours of the booking are marked, not adjacent hours
        final slotHour = slotStart.hour;
        final bookingStartHour = bookingStart.hour;
        final bookingEndHour = bookingEnd.hour;

        // Check if slot hour is within booking hours (inclusive start, exclusive end for hour comparison)
        // For example: booking 9:00-11:00 should block 9:00 and 10:00, but not 11:00
        // But if booking is exactly 10:00-11:00, only 10:00 should be blocked
        bool overlaps = false;
        if (slotStart.year == bookingStart.year &&
            slotStart.month == bookingStart.month &&
            slotStart.day == bookingStart.day) {
          // Same day - check hour overlap
          // Slot is booked if its hour is >= booking start hour and < booking end hour
          overlaps = slotHour >= bookingStartHour && slotHour < bookingEndHour;
        }

        if (overlaps) {
          // Debug: print when we find a match

          return true;
        }
      }
    }

    return false;
  }

  Map<String, dynamic>? _getChallengeForSlot(int dayIndex, int hour) {
    if (widget.selectedCourt == null) return null;
    final days = widget.days;
    if (dayIndex >= days.length) return null;

    // Create slot time in local timezone (same as the day)
    final slotStart = DateTime(
      days[dayIndex].year,
      days[dayIndex].month,
      days[dayIndex].day,
      hour,
    );

    // Check challenges - only show challenge for exact hour matches
    for (final challenge in challenges) {
      final startTime = _parseTimestamp(challenge['stime']);
      final endTime = _parseTimestamp(challenge['etime']);

      if (startTime != null && endTime != null) {
        // Normalize times to same timezone for comparison
        final challengeStart = DateTime(
          startTime.year,
          startTime.month,
          startTime.day,
          startTime.hour,
        );
        final challengeEnd = DateTime(
          endTime.year,
          endTime.month,
          endTime.day,
          endTime.hour,
        );

        // Only show challenge if the slot hour is within the challenge's hour range
        // This ensures only the exact hours of the challenge are shown, not adjacent hours
        final slotHour = slotStart.hour;
        final challengeStartHour = challengeStart.hour;
        final challengeEndHour = challengeEnd.hour;

        // Check if slot hour is within challenge hours (inclusive start, exclusive end)
        bool isWithinChallenge = false;
        if (slotStart.year == challengeStart.year &&
            slotStart.month == challengeStart.month &&
            slotStart.day == challengeStart.day) {
          // Same day - check hour overlap
          isWithinChallenge =
              slotHour >= challengeStartHour && slotHour < challengeEndHour;
        }

        if (isWithinChallenge) {
          return challenge;
        }
      }
    }

    return null;
  }

  bool _isChallengeOpen(Map<String, dynamic> challenge) {
    // Backend now includes isOpen flag
    return challenge['isOpen'] ?? true; // Default to open if flag not present
  }

  IconData _getSportIcon() {
    final sport = (widget.sportType ?? '').toLowerCase();
    switch (sport) {
      case 'padel':
        return Icons.sports_tennis;
      case 'cricket':
        return Icons.sports_cricket;
      case 'futsal':
      case 'football':
        return Icons.sports_soccer;
      default:
        return Icons.sports_soccer;
    }
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    try {
      if (timestamp is String) {
        // ISO 8601 string format (e.g., "2025-11-13T20:00:00Z")
        return DateTime.parse(timestamp).toLocal();
      } else if (timestamp is Map) {
        // Firestore Timestamp object - can come in different formats
        int? seconds;
        int? nanoseconds = 0;

        // Try different possible field names
        if (timestamp['_seconds'] != null) {
          seconds = timestamp['_seconds'] is int
              ? timestamp['_seconds']
              : int.tryParse(timestamp['_seconds'].toString());
          nanoseconds = timestamp['_nanoseconds'] is int
              ? timestamp['_nanoseconds']
              : (timestamp['_nanoseconds'] != null
                    ? int.tryParse(timestamp['_nanoseconds'].toString())
                    : 0);
        } else if (timestamp['seconds'] != null) {
          seconds = timestamp['seconds'] is int
              ? timestamp['seconds']
              : int.tryParse(timestamp['seconds'].toString());
          nanoseconds = timestamp['nanoseconds'] is int
              ? timestamp['nanoseconds']
              : (timestamp['nanoseconds'] != null
                    ? int.tryParse(timestamp['nanoseconds'].toString())
                    : 0);
        }

        if (seconds != null) {
          // Convert to milliseconds (nanoseconds / 1000000)
          final milliseconds =
              (seconds * 1000) + ((nanoseconds ?? 0) ~/ 1000000);
          return DateTime.fromMillisecondsSinceEpoch(
            milliseconds,
            isUtc: true,
          ).toLocal();
        }

        // Try toDate method if available
        if (timestamp['toDate'] != null) {
          final date = timestamp['toDate']();
          if (date is DateTime) {
            return date.toLocal();
          }
        }
      } else if (timestamp is DateTime) {
        return timestamp.toLocal();
      }
    } catch (e) {
      // Print error for debugging
      print(
        'Error parsing timestamp: $e, type: ${timestamp.runtimeType}, value: $timestamp',
      );
    }
    return null;
  }

  bool _isSlotSelected(int dayIndex, int hour) {
    if (widget.selectedStartSlot == null || widget.selectedEndSlot == null) {
      return false;
    }
    final slotIndex = dayIndex * 24 + hour;
    final start = widget.selectedStartSlot!;
    final end = widget.selectedEndSlot!;
    return slotIndex >= start && slotIndex <= end;
  }

  bool _isSlotInRange(int dayIndex, int hour) {
    if (widget.selectedCourt == null) return false;
    final openingTime = widget.selectedCourt!['openingTime'] ?? 8;
    final closingTime = widget.selectedCourt!['closingTime'] ?? 23;

    // First check if hour is within court's operating hours
    if (hour < openingTime || hour > closingTime) {
      return false;
    }

    // Check if slot is booked
    if (_isSlotBooked(dayIndex, hour)) {
      return false;
    }

    // Check if slot is in the past for today
    if (_isSlotInPast(dayIndex, hour)) {
      return false;
    }

    if (widget.selectedStartSlot == null) {
      // No selection yet - all hours within operating hours and not booked are available
      return true;
    }

    final startDay = widget.selectedStartSlot! ~/ 24;
    final startHour = widget.selectedStartSlot! % 24;

    if (dayIndex == startDay) {
      // Same day - allow 2-3 hours from start, but within operating hours
      return hour >= startHour && hour <= startHour + 2 && hour <= closingTime;
    }
    return false;
  }

  bool _isSlotInPast(int dayIndex, int hour) {
    final days = widget.days;
    if (dayIndex >= days.length) return false;

    final now = DateTime.now();
    final slotDate = DateTime(
      days[dayIndex].year,
      days[dayIndex].month,
      days[dayIndex].day,
      hour,
    );

    // Check if this slot is today and in the past
    final isToday =
        slotDate.year == now.year &&
        slotDate.month == now.month &&
        slotDate.day == now.day;

    if (isToday) {
      // If it's today, check if the hour has passed
      // If current time is 9:45, mark 9:00 as passed (current hour >= slot hour)
      // If current hour is greater than slot hour, it's passed
      // If current hour equals slot hour, it's also passed (we're past the start of that hour)
      return now.hour >= slotDate.hour;
    }

    // If it's a past day, it's in the past
    return slotDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  String _getDayName(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  void _showBookedSlotDialog(int dayIndex, int hour) {
    final days = widget.days;
    if (dayIndex >= days.length) return;

    final slotDate = days[dayIndex];
    final dateStr = '${slotDate.day}/${slotDate.month}/${slotDate.year}';
    final timeStr = '${hour.toString().padLeft(2, '0')}:00';

    // Find the booking for this slot
    Map<String, dynamic>? booking;
    for (final b in bookings) {
      final startTime = _parseTimestamp(b['startTime']);
      final endTime = _parseTimestamp(b['endTime']);

      if (startTime != null && endTime != null) {
        final bookingStart = DateTime(
          startTime.year,
          startTime.month,
          startTime.day,
          startTime.hour,
        );
        final bookingEnd = DateTime(
          endTime.year,
          endTime.month,
          endTime.day,
          endTime.hour,
        );
        final slotStart = DateTime(
          slotDate.year,
          slotDate.month,
          slotDate.day,
          hour,
        );

        if (slotStart.year == bookingStart.year &&
            slotStart.month == bookingStart.month &&
            slotStart.day == bookingStart.day &&
            hour >= bookingStart.hour &&
            hour < bookingEnd.hour) {
          booking = b;
          break;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red.shade300, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Slot Booked',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.red.shade300,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Date: $dateStr',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.red.shade300,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Time: $timeStr',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This time slot is already booked and unavailable.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (booking != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                'Booking Details:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (booking['teamName'] != null)
                Text(
                  'Team: ${booking['teamName']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChallengeDetails(
    Map<String, dynamic> challenge,
    int dayIndex,
    int hour,
  ) {
    final startTime = _parseTimestamp(challenge['stime']);
    final endTime = _parseTimestamp(challenge['etime']);

    String timeStr = 'Unknown';
    if (startTime != null && endTime != null) {
      timeStr =
          '${startTime.hour.toString().padLeft(2, '0')}:00 - ${endTime.hour.toString().padLeft(2, '0')}:00';
    }

    String dateStr = 'Unknown';
    if (startTime != null) {
      dateStr = '${startTime.day}/${startTime.month}/${startTime.year}';
    }

    final challengeID = challenge['id'] ?? challenge['challengeID'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Open Challenge',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team: ${challenge['teamName'] ?? 'Unknown Team'}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Sport: ${(challenge['sport'] ?? 'Unknown').toUpperCase()}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: $dateStr',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Time: $timeStr',
              style: const TextStyle(color: Colors.white70),
            ),
            if (challenge['Price'] != null && challenge['Price'] > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Price: Rs. ${challenge['Price']}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This slot has an open challenge. You can accept it to create a match.',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptChallenge(challengeID);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept Challenge'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptChallenge(String challengeID) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:5000/api/match/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'challengeID': challengeID}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Challenge accepted successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Clear selection in parent widget if callback provided
        if (widget.onChallengeAccepted != null) {
          widget.onChallengeAccepted!();
        }
        // Refresh conflicts to update the grid
        _fetchConflicts();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Failed to accept challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedCourt == null) {
      return const SizedBox.shrink();
    }

    final days = widget.days;
    final availableHours = _getAvailableHours();
    final openingTime = widget.selectedCourt!['openingTime'] ?? 8;
    final closingTime = widget.selectedCourt!['closingTime'] ?? 23;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.redAccent.withOpacity(0.2),
                Colors.redAccent.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Time Slot',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$openingTime:00 - $closingTime:00',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Select 2-3 consecutive hours on the same day',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (isLoadingConflicts) ...[
          const SizedBox(height: 12),
          const Center(
            child: CircularProgressIndicator(
              color: Colors.redAccent,
              strokeWidth: 2,
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Time slot grid
        ...days.asMap().entries.map((entry) {
          final dayIndex = entry.key;
          final day = entry.value;
          final dayName = _getDayName(day);
          final dateStr = '${day.day}/${day.month}';

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[900]!, Colors.grey[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent.withOpacity(0.3),
                            Colors.redAccent.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$dayName, $dateStr',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: availableHours.map((hour) {
                    final isSelected = _isSlotSelected(dayIndex, hour);
                    final isBooked = _isSlotBooked(dayIndex, hour);
                    // Only show challenges if onChallengeAccepted callback is provided (i.e., for teams, not court owners)
                    final challenge = widget.onChallengeAccepted != null
                        ? _getChallengeForSlot(dayIndex, hour)
                        : null;
                    final hasChallenge = challenge != null;
                    final isChallengeOpen = hasChallenge
                        ? _isChallengeOpen(challenge)
                        : false;
                    final isInRange = _isSlotInRange(dayIndex, hour);
                    final isInPast = _isSlotInPast(dayIndex, hour);

                    return GestureDetector(
                      onTap: isBooked
                          ? () => _showBookedSlotDialog(dayIndex, hour)
                          : hasChallenge && isChallengeOpen
                          ? () =>
                                _showChallengeDetails(challenge, dayIndex, hour)
                          : (isInRange &&
                                !isBooked &&
                                !hasChallenge &&
                                !isInPast)
                          ? () => widget.onSlotSelected(dayIndex, hour)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: 60,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: hasChallenge
                              ? (isChallengeOpen
                                    ? LinearGradient(
                                        colors: [
                                          Colors.green.withOpacity(0.4),
                                          Colors.green.withOpacity(0.2),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.red.withOpacity(0.4),
                                          Colors.red.withOpacity(0.2),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ))
                              : isBooked
                              ? LinearGradient(
                                  colors: [
                                    Colors.red.withOpacity(0.3),
                                    Colors.red.withOpacity(0.15),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : isInPast
                              ? null
                              : isSelected
                              ? LinearGradient(
                                  colors: [
                                    Colors.redAccent,
                                    Colors.redAccent.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : isInRange
                              ? LinearGradient(
                                  colors: [
                                    Colors.grey[800]!,
                                    Colors.grey[900]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isInPast
                              ? Colors.black.withOpacity(0.5)
                              : (hasChallenge ||
                                    isBooked ||
                                    isSelected ||
                                    isInRange)
                              ? null
                              : Colors.grey[900],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasChallenge
                                ? (isChallengeOpen
                                      ? Colors.green.withOpacity(0.8)
                                      : Colors.red.withOpacity(0.8))
                                : isBooked
                                ? Colors.red.withOpacity(0.7)
                                : isInPast
                                ? Colors.grey[600]!.withOpacity(0.3)
                                : isSelected
                                ? Colors.redAccent
                                : Colors.white24,
                            width: isSelected || isBooked || hasChallenge
                                ? 2.5
                                : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : isBooked || hasChallenge
                              ? [
                                  BoxShadow(
                                    color:
                                        (isBooked
                                                ? Colors.red
                                                : (isChallengeOpen
                                                      ? Colors.green
                                                      : Colors.red))
                                            .withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$hour:00',
                                style: TextStyle(
                                  color: hasChallenge
                                      ? (isChallengeOpen
                                            ? Colors.green.shade300
                                            : Colors.red.shade300)
                                      : isBooked
                                      ? Colors.red.shade300
                                      : isInPast
                                      ? Colors.grey[600]
                                      : isSelected
                                      ? Colors.white
                                      : isInRange
                                      ? Colors.white70
                                      : Colors.white38,
                                  fontSize: 12,
                                  fontWeight:
                                      isSelected || isBooked || hasChallenge
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (hasChallenge)
                                Icon(
                                  _getSportIcon(),
                                  size: 14,
                                  color: isChallengeOpen
                                      ? Colors.green
                                      : Colors.red,
                                )
                              else if (isBooked)
                                Icon(
                                  _getSportIcon(),
                                  size: 14,
                                  color: Colors.yellow,
                                )
                              else if (isInPast)
                                Icon(
                                  Icons.lock_clock,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                            ],
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
      ],
    );
  }
}
