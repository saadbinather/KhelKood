import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/time_slot_grid.dart';
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

class CourtManagementPage extends StatefulWidget {
  const CourtManagementPage({super.key});

  @override
  State<CourtManagementPage> createState() => _CourtManagementPageState();
}

class _CourtManagementPageState extends State<CourtManagementPage> {
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  Map<String, dynamic>? courtData;

  // Rate controllers
  final TextEditingController _cricketRateController = TextEditingController();
  final TextEditingController _futsalRateController = TextEditingController();
  final TextEditingController _padelRateController = TextEditingController();

  // Store original rates for validation
  int _originalCricketRate = 0;
  int _originalFutsalRate = 0;
  int _originalPadelRate = 0;

  String _selectedSport = "Cricket";

  // Unavailable slots
  int? selectedCourtNum; // Selected court number for marking unavailable
  int? selectedStartSlot;
  int? selectedEndSlot;
  bool isMarkingUnavailable = false;

  @override
  void initState() {
    super.initState();
    _fetchCourtData();
  }

  @override
  void dispose() {
    _cricketRateController.dispose();
    _futsalRateController.dispose();
    _padelRateController.dispose();
    super.dispose();
  }

  Future<void> _fetchCourtData() async {
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
        Uri.parse('$baseUrl/courtowner/my-court'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final court = data['data']['court'];

        setState(() {
          courtData = court;
          _originalCricketRate = court['cricketRate'] ?? 0;
          _originalFutsalRate = court['futsalRate'] ?? 0;
          _originalPadelRate = court['padelRate'] ?? 0;
          _cricketRateController.text = _originalCricketRate.toString();
          _futsalRateController.text = _originalFutsalRate.toString();
          _padelRateController.text = _originalPadelRate.toString();
          isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Failed to fetch court data';
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

  Future<void> _updateRates() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          errorMessage = 'No authentication token found';
          isSaving = false;
        });
        return;
      }

      final cricketRate = int.tryParse(_cricketRateController.text.trim()) ?? 0;
      final futsalRate = int.tryParse(_futsalRateController.text.trim()) ?? 0;
      final padelRate = int.tryParse(_padelRateController.text.trim()) ?? 0;

      // Validate that all rates are greater than 0, revert invalid ones to original
      List<String> revertedFields = [];
      bool hasInvalidRate = false;
      int finalCricketRate = cricketRate;
      int finalFutsalRate = futsalRate;
      int finalPadelRate = padelRate;

      if (cricketRate <= 0) {
        _cricketRateController.text = _originalCricketRate.toString();
        finalCricketRate = _originalCricketRate;
        revertedFields.add('Cricket');
        hasInvalidRate = true;
      }
      if (futsalRate <= 0) {
        _futsalRateController.text = _originalFutsalRate.toString();
        finalFutsalRate = _originalFutsalRate;
        revertedFields.add('Futsal');
        hasInvalidRate = true;
      }
      if (padelRate <= 0) {
        _padelRateController.text = _originalPadelRate.toString();
        finalPadelRate = _originalPadelRate;
        revertedFields.add('Padel');
        hasInvalidRate = true;
      }

      if (hasInvalidRate) {
        setState(() {
          isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${revertedFields.join(', ')} rate(s) must be greater than 0. Reverted to original value(s).',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final updateData = {
        'cricketRate': finalCricketRate,
        'futsalRate': finalFutsalRate,
        'padelRate': finalPadelRate,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/courtowner/edit-court'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rates updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchCourtData();
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Failed to update rates';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage!), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _addField() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          errorMessage = 'No authentication token found';
          isSaving = false;
        });
        return;
      }

      // Map sport names to backend format
      String sportType = _selectedSport.toLowerCase();
      if (sportType == "football") {
        sportType = "futsal"; // Backend uses futsal for football
      }

      final response = await http.put(
        Uri.parse('$baseUrl/courtowner/add-field'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'sportType': sportType}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_selectedSport field added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchCourtData();
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Failed to add field';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage!), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showAddFieldDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Add Field",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedSport,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              items: ["Cricket", "Football", "Padel"]
                  .map(
                    (sport) =>
                        DropdownMenuItem(value: sport, child: Text(sport)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedSport = value;
                  });
                }
              },
              decoration: InputDecoration(
                labelText: "Sport Type",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: isSaving ? null : _addField,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text("Add"),
          ),
        ],
      ),
    );
  }

  List<DateTime> _getNext7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  Map<String, List<Map<String, dynamic>>> _getAllCourtNumbers() {
    if (courtData == null) return {};

    final cricketCount = courtData!['numOfCricketFields'] ?? 0;
    final futsalCount = courtData!['numOfFutsalFields'] ?? 0;
    final padelCount = courtData!['numOfPadelCourts'] ?? 0;

    return {
      'cricket': List.generate(
        cricketCount,
        (i) => {
          'encodedNum': i + 1,
          'actualNum': i + 1,
          'sport': 'cricket',
          'label': 'Cricket Field ${i + 1}',
        },
      ),
      'futsal': List.generate(
        futsalCount,
        (i) => {
          'encodedNum': 1000 + (i + 1),
          'actualNum': i + 1,
          'sport': 'futsal',
          'label': 'Futsal Field ${i + 1}',
        },
      ),
      'padel': List.generate(
        padelCount,
        (i) => {
          'encodedNum': 2000 + (i + 1),
          'actualNum': i + 1,
          'sport': 'padel',
          'label': 'Padel Court ${i + 1}',
        },
      ),
    };
  }

  // Decode encoded court number to get actual court number
  int _decodeCourtNum(int encodedNum) {
    if (encodedNum < 1000) {
      return encodedNum; // Cricket
    } else if (encodedNum < 2000) {
      return encodedNum - 1000; // Futsal
    } else {
      return encodedNum - 2000; // Padel
    }
  }

  // Get sport type from encoded court number
  String? _getSportTypeFromCourtNum(int encodedNum) {
    if (encodedNum < 1000) {
      return 'cricket';
    } else if (encodedNum < 2000) {
      return 'futsal';
    } else {
      return 'padel';
    }
  }

  void _selectTimeSlot(int dayIndex, int hour) {
    final slotIndex = dayIndex * 24 + hour;

    setState(() {
      if (selectedStartSlot == null) {
        // First selection - set as start
        selectedStartSlot = slotIndex;
        selectedEndSlot = slotIndex;
      } else {
        // Check if clicking on the same day
        final startDay = selectedStartSlot! ~/ 24;
        final startHour = selectedStartSlot! % 24;
        final endDay = selectedEndSlot! ~/ 24;
        final endHour = selectedEndSlot! % 24;

        if (dayIndex == startDay && dayIndex == endDay) {
          // Same day - check if clicking within selected range or consecutive
          if (slotIndex == selectedStartSlot && slotIndex == selectedEndSlot) {
            // Clicking the same single slot - deselect
            selectedStartSlot = null;
            selectedEndSlot = null;
          } else if (hour == startHour - 1 || hour == endHour + 1) {
            // Clicking consecutive slot - extend selection
            if (hour == startHour - 1) {
              selectedStartSlot = slotIndex;
            } else {
              selectedEndSlot = slotIndex;
            }
            // Limit to 3 hours max
            final range =
                (selectedEndSlot! ~/ 24 * 24 + selectedEndSlot! % 24) -
                (selectedStartSlot! ~/ 24 * 24 + selectedStartSlot! % 24);
            if (range > 2) {
              // Too many hours - reset to clicked slot
              selectedStartSlot = slotIndex;
              selectedEndSlot = slotIndex;
            }
          } else {
            // Clicking non-consecutive slot - replace selection
            selectedStartSlot = slotIndex;
            selectedEndSlot = slotIndex;
          }
        } else {
          // Different day or clicking outside range - replace selection
          selectedStartSlot = slotIndex;
          selectedEndSlot = slotIndex;
        }
      }
    });
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

  Future<void> _markUnavailable() async {
    if (selectedCourtNum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a court/field number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedStartSlot == null || selectedEndSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select 2-3 consecutive time slots'),
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
          content: Text('Invalid time selection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isMarkingUnavailable = true;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authentication token found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isMarkingUnavailable = false;
        });
        return;
      }

      // Decode the encoded court number to get the actual court number
      final actualCourtNum = _decodeCourtNum(selectedCourtNum!);

      final response = await http.post(
        Uri.parse('$baseUrl/booking/mark-unavailable'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'courtID': courtData!['id'],
          'startTime': startDateTime.toIso8601String(),
          'endTime': endDateTime.toIso8601String(),
          'courtNum': actualCourtNum,
        }),
      );

      setState(() {
        isMarkingUnavailable = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Court marked as unavailable successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Clear selection
          setState(() {
            selectedCourtNum = null;
            selectedStartSlot = null;
            selectedEndSlot = null;
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['error'] ?? 'Failed to mark court as unavailable',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isMarkingUnavailable = false;
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

  Widget _buildCourtNumberSelector() {
    final allCourtNumbers = _getAllCourtNumbers();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cricket Fields
        if (allCourtNumbers['cricket']!.isNotEmpty) ...[
          const Text(
            'Cricket Fields',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allCourtNumbers['cricket']!.map((courtInfo) {
              final encodedNum = courtInfo['encodedNum'] as int;
              final isSelected = selectedCourtNum == encodedNum;
              return _buildCourtNumberButton(
                courtInfo['label'] as String,
                encodedNum,
                isSelected,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Futsal Fields
        if (allCourtNumbers['futsal']!.isNotEmpty) ...[
          const Text(
            'Futsal Fields',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allCourtNumbers['futsal']!.map((courtInfo) {
              final encodedNum = courtInfo['encodedNum'] as int;
              final isSelected = selectedCourtNum == encodedNum;
              return _buildCourtNumberButton(
                courtInfo['label'] as String,
                encodedNum,
                isSelected,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Padel Courts
        if (allCourtNumbers['padel']!.isNotEmpty) ...[
          const Text(
            'Padel Courts',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allCourtNumbers['padel']!.map((courtInfo) {
              final encodedNum = courtInfo['encodedNum'] as int;
              final isSelected = selectedCourtNum == encodedNum;
              return _buildCourtNumberButton(
                courtInfo['label'] as String,
                encodedNum,
                isSelected,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildCourtNumberButton(String label, int courtNum, bool isSelected) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCourtNum = courtNum;
          selectedStartSlot = null;
          selectedEndSlot = null;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.redAccent.withOpacity(0.1)
              : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.redAccent : Colors.grey[700]!,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.redAccent : Colors.grey[400]!,
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            "Court Management",
            style: TextStyle(
              color: Colors.grey[900],
              fontSize: isSmallScreen ? 18 : 20,
            ),
          ),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            tabs: const [
              Tab(text: 'Settings'),
              Tab(text: 'Mark Unavailable'),
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
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchCourtData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : courtData == null
            ? const Center(
                child: Text(
                  'No court data found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : TabBarView(
                children: [
                  // Settings Tab
                  SingleChildScrollView(
                    padding: EdgeInsets.all(
                      isSmallScreen
                          ? 12
                          : isTablet
                          ? 24
                          : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Court Name
                        Text(
                          courtData!['name'] ?? 'Court',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: isSmallScreen
                                ? 20
                                : isTablet
                                ? 28
                                : 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Text(
                          courtData!['address'] ?? 'No address',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isSmallScreen
                                ? 14
                                : isTablet
                                ? 18
                                : 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(
                          height: isSmallScreen
                              ? 16
                              : isTablet
                              ? 32
                              : 24,
                        ),

                        // Field Counts
                        Text(
                          'Field Counts',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: isSmallScreen
                                ? 18
                                : isTablet
                                ? 24
                                : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildFieldCountCard(
                          'Cricket Fields',
                          courtData!['numOfCricketFields'] ?? 0,
                          Icons.sports_cricket,
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        _buildFieldCountCard(
                          'Futsal Fields',
                          courtData!['numOfFutsalFields'] ?? 0,
                          Icons.sports_soccer,
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        _buildFieldCountCard(
                          'Padel Courts',
                          courtData!['numOfPadelCourts'] ?? 0,
                          Icons.sports_tennis,
                        ),
                        SizedBox(
                          height: isSmallScreen
                              ? 16
                              : isTablet
                              ? 32
                              : 24,
                        ),

                        // Rates Section
                        Text(
                          'Per Hour Rates',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: isSmallScreen
                                ? 18
                                : isTablet
                                ? 24
                                : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildRateField(
                          'Cricket Rate (Rs./hour)',
                          _cricketRateController,
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildRateField(
                          'Futsal Rate (Rs./hour)',
                          _futsalRateController,
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildRateField(
                          'Padel Rate (Rs./hour)',
                          _padelRateController,
                        ),
                        SizedBox(
                          height: isSmallScreen
                              ? 16
                              : isTablet
                              ? 32
                              : 24,
                        ),
                        ElevatedButton(
                          onPressed: isSaving ? null : _updateRates,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 12 : 16,
                            ),
                            minimumSize: Size(
                              double.infinity,
                              isSmallScreen ? 44 : 50,
                            ),
                          ),
                          child: isSaving
                              ? SizedBox(
                                  height: isSmallScreen ? 18 : 20,
                                  width: isSmallScreen ? 18 : 20,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Update Rates',
                                  style: TextStyle(
                                    color: Colors.grey[900],
                                    fontSize: isSmallScreen
                                        ? 14
                                        : isTablet
                                        ? 18
                                        : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Mark Unavailable Tab
                  SingleChildScrollView(
                    padding: EdgeInsets.all(
                      isSmallScreen
                          ? 12
                          : isTablet
                          ? 24
                          : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Instructions
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mark Time Slots as Unavailable',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: isSmallScreen
                                      ? 16
                                      : isTablet
                                      ? 20
                                      : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 6 : 8),
                              Text(
                                'Select 2-3 consecutive time slots on the same day to mark them as unavailable. These slots will be blocked for all bookings and challenges.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isSmallScreen
                                      ? 12
                                      : isTablet
                                      ? 16
                                      : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: isSmallScreen
                              ? 16
                              : isTablet
                              ? 24
                              : 20,
                        ),

                        // Court Number Selector
                        if (courtData != null) ...[
                          Text(
                            'Select Court/Field Number',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: isSmallScreen
                                  ? 16
                                  : isTablet
                                  ? 20
                                  : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            'Choose which court/field to mark as unavailable',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isSmallScreen
                                  ? 12
                                  : isTablet
                                  ? 16
                                  : 14,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          _buildCourtNumberSelector(),
                        ],

                        // Time Slot Grid (show only after court number is selected)
                        if (courtData != null && selectedCourtNum != null) ...[
                          SizedBox(
                            height: isSmallScreen
                                ? 16
                                : isTablet
                                ? 24
                                : 20,
                          ),
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TimeSlotGrid(
                              selectedCourt: courtData,
                              selectedCourtNum: _decodeCourtNum(
                                selectedCourtNum!,
                              ),
                              selectedStartSlot: selectedStartSlot,
                              selectedEndSlot: selectedEndSlot,
                              onSlotSelected: _selectTimeSlot,
                              onChallengeAccepted:
                                  null, // Not needed for court owner
                              days: _getNext7Days(),
                              sportType: _getSportTypeFromCourtNum(
                                selectedCourtNum!,
                              ),
                            ),
                          ),
                        ],

                        // Mark Unavailable Button
                        if (selectedCourtNum != null &&
                            selectedStartSlot != null &&
                            selectedEndSlot != null)
                          Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isMarkingUnavailable
                                    ? null
                                    : _markUnavailable,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 12 : 16,
                                  ),
                                  minimumSize: Size(
                                    double.infinity,
                                    isSmallScreen ? 44 : 50,
                                  ),
                                ),
                                child: isMarkingUnavailable
                                    ? SizedBox(
                                        height: isSmallScreen ? 18 : 20,
                                        width: isSmallScreen ? 18 : 20,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Mark as Unavailable',
                                        style: TextStyle(
                                          color: Colors.grey[900],
                                          fontSize: isSmallScreen
                                              ? 14
                                              : isTablet
                                              ? 18
                                              : 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: showAddFieldDialog,
          backgroundColor: Colors.redAccent,
          mini: isSmallScreen,
          child: Icon(
            Icons.add,
            color: Colors.grey[900],
            size: isSmallScreen ? 20 : 24,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCountCard(String label, int count, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      color: Colors.grey[900],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.redAccent,
            size: isSmallScreen ? 20 : 24,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        trailing: Text(
          count.toString(),
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRateField(String label, TextEditingController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(
        color: Colors.redAccent,
        fontSize: isSmallScreen
            ? 14
            : isTablet
            ? 18
            : 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey,
          fontSize: isSmallScreen
              ? 13
              : isTablet
              ? 17
              : 15,
        ),
        prefixText: 'Rs. ',
        prefixStyle: TextStyle(
          color: Colors.redAccent,
          fontSize: isSmallScreen
              ? 14
              : isTablet
              ? 18
              : 16,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.grey[900],
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 14 : 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}
