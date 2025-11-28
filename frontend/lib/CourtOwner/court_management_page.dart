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

  String _selectedSport = "Cricket";

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
          _cricketRateController.text = (court['cricketRate'] ?? 0).toString();
          _futsalRateController.text = (court['futsalRate'] ?? 0).toString();
          _padelRateController.text = (court['padelRate'] ?? 0).toString();
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

      final updateData = {
        'cricketRate': int.tryParse(_cricketRateController.text.trim()) ?? 0,
        'futsalRate': int.tryParse(_futsalRateController.text.trim()) ?? 0,
        'padelRate': int.tryParse(_padelRateController.text.trim()) ?? 0,
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
              content: Text('${_selectedSport} field added successfully!'),
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
        title: const Text("Add Field", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSport,
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
              decoration: const InputDecoration(
                labelText: "Sport Type",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Court Management",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
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
                style: TextStyle(color: Colors.white70),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Court Name
                  Text(
                    courtData!['name'] ?? 'Court',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    courtData!['address'] ?? 'No address',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),

                  // Field Counts
                  const Text(
                    'Field Counts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFieldCountCard(
                    'Cricket Fields',
                    courtData!['numOfCricketFields'] ?? 0,
                    Icons.sports_cricket,
                  ),
                  const SizedBox(height: 8),
                  _buildFieldCountCard(
                    'Futsal Fields',
                    courtData!['numOfPadelFields'] ?? 0,
                    Icons.sports_soccer,
                  ),
                  const SizedBox(height: 8),
                  _buildFieldCountCard(
                    'Padel Courts',
                    courtData!['numOfPadelCourts'] ?? 0,
                    Icons.sports_tennis,
                  ),
                  const SizedBox(height: 24),

                  // Rates Section
                  const Text(
                    'Per Hour Rates',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRateField(
                    'Cricket Rate (Rs/hour)',
                    _cricketRateController,
                    Icons.currency_rupee,
                  ),
                  const SizedBox(height: 12),
                  _buildRateField(
                    'Futsal Rate (Rs/hour)',
                    _futsalRateController,
                    Icons.currency_rupee,
                  ),
                  const SizedBox(height: 12),
                  _buildRateField(
                    'Padel Rate (Rs/hour)',
                    _padelRateController,
                    Icons.currency_rupee,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSaving ? null : _updateRates,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Rates',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddFieldDialog,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFieldCountCard(String label, int count, IconData icon) {
    return Card(
      color: Colors.grey[900],
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRateField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.redAccent),
        filled: true,
        fillColor: Colors.grey[900],
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
