import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'booking_history_page.dart';

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

// Phone number formatter: allows 10 digits with optional dash after 4th digit
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Remove all non-digit characters except dash
    final digitsOnly = text.replaceAll(RegExp(r'[^\d-]'), '');
    
    // Limit to 10 digits + 1 optional dash
    String formatted = '';
    int digitCount = 0;
    
    for (int i = 0; i < digitsOnly.length && digitCount < 10; i++) {
      final char = digitsOnly[i];
      if (char == '-') {
        // Only allow dash after exactly 4 digits
        if (digitCount == 4 && !formatted.contains('-')) {
          formatted += '-';
        }
      } else {
        formatted += char;
        digitCount++;
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool showEditText = false;
  bool showViewText = false;
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  bool _hasChanges = false;

  Map<String, dynamic>? teamData;
  List<String> players = [];

  final TextEditingController teamNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTeamProfile();
  }

  @override
  void dispose() {
    teamNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeamProfile() async {
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
        Uri.parse('$baseUrl/team/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final team = data['data']['team'] as Map<String, dynamic>;
        
        setState(() {
          teamData = team;
          players = List<String>.from(team['players'] ?? []);
          teamNameController.text = team['teamName']?.toString() ?? '';
          phoneController.text = team['phone']?.toString() ?? '';
          emailController.text = team['email']?.toString() ?? '';
          isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error']?.toString() ?? 'Failed to fetch team profile';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(_hasChanges);
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Row(
            children: [
              // Edit Profile Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => showEditText = true),
                onExit: (_) => setState(() => showEditText = false),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: teamData == null ? null : () {
                        _showEditDialog();
                      },
                    ),
                    if (showEditText)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Text(
                          "Edit",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),

              // View Booking History Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => showViewText = true),
                onExit: (_) => setState(() => showViewText = false),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookingHistoryPage(),
                          ),
                        );
                      },
                    ),
                    if (showViewText)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Text(
                          "View History",
                          style:
                              TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchTeamProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : teamData == null
                  ? const Center(
                      child: Text('No team data found'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.deepPurple,
                              child: Icon(Icons.person, size: 70, color: Colors.white),
                            ),
                            const SizedBox(height: 20),

                            // Team Name
                            Text(
                              teamData!['teamName']?.toString() ?? 'Team',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Info Card
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    profileRow(Icons.email, "Email", teamData!['email']?.toString() ?? 'N/A'),
                                    profileRow(Icons.phone, "Phone", teamData!['phone']?.toString() ?? 'N/A'),
                                    profileRow(Icons.sports_soccer, "Sport", teamData!['sports']?.toString() ?? 'N/A'),
                                    profileRow(Icons.star, "Points", (teamData!['points'] ?? 0).toString()),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Player List
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Players",
                                          style: TextStyle(
                                              fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, color: Colors.deepPurple),
                                          onPressed: isSaving ? null : () {
                                            _showAddPlayerDialog();
                                          },
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    if (players.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: Text(
                                            'No players added yet',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        ),
                                      )
                                    else
                                      for (int i = 0; i < players.length; i++)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.person,
                                                      color: Colors.deepPurple),
                                                  const SizedBox(width: 10),
                                                  Text(players[i],
                                                      style: const TextStyle(fontSize: 16)),
                                                ],
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: isSaving ? null : () {
                                                  _removePlayer(players[i]);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget profileRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$title: $value",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Validate phone number format
  bool _validatePhoneFormat(String phone) {
    if (phone.isEmpty) return false;
    
    // Remove dash for validation
    final cleaned = phone.replaceAll('-', '');
    
    // Must be exactly 10 digits
    if (!RegExp(r'^\d{10}$').hasMatch(cleaned)) {
      return false;
    }
    
    // If dash is present, it must be after exactly 4 digits
    if (phone.contains('-')) {
      final parts = phone.split('-');
      if (parts.length != 2 || parts[0].length != 4 || parts[1].length != 6) {
        return false;
      }
    }
    
    return true;
  }

  // Validate email format
  bool _validateEmailFormat(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  void _showEditDialog() {
    final formKey = GlobalKey<FormState>();
    String? phoneError;
    String? emailError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (buildContext, setDialogState) => AlertDialog(
          title: const Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: teamNameController,
                    decoration: const InputDecoration(labelText: "Team Name"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      errorText: emailError,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      if (emailError != null) {
                        setDialogState(() {
                          emailError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: "Phone Number (e.g., 1234-567890 or 1234567890)",
                      errorText: phoneError,
                      helperText: "10 digits, optional dash after 4th digit",
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneNumberFormatter()],
                    onChanged: (value) {
                      if (phoneError != null) {
                        setDialogState(() {
                          phoneError = null;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () {
                // Validate before submitting
                bool isValid = true;
                
                // Validate phone
                if (!_validatePhoneFormat(phoneController.text.trim())) {
                  setDialogState(() {
                    phoneError = "Invalid format. Must be 10 digits (e.g., 1234-567890)";
                  });
                  isValid = false;
                }
                
                // Validate email
                if (!_validateEmailFormat(emailController.text.trim())) {
                  setDialogState(() {
                    emailError = "Invalid email format";
                  });
                  isValid = false;
                }
                
                if (isValid) {
                  Navigator.pop(context);
                  _updateProfile();
                }
              },
              child: isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    setState(() {
      isSaving = true;
    });

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

      final response = await http.put(
        Uri.parse('$baseUrl/team/edit-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'teamName': teamNameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          _hasChanges = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchTeamProfile();
        }
      } else {
        final errorData = jsonDecode(response.body);
        String errorMessage = 'Failed to update profile';
        
        // Extract error message from response
        if (errorData['error'] != null) {
          errorMessage = errorData['error'].toString();
        } else if (errorData['message'] != null) {
          errorMessage = errorData['message'].toString();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
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
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showAddPlayerDialog() {
    final TextEditingController playerController = TextEditingController();
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (buildContext, setDialogState) => AlertDialog(
          title: const Text("Add Player"),
          content: TextField(
            controller: playerController,
            decoration: const InputDecoration(labelText: "Player Name"),
            enabled: !isAdding,
          ),
          actions: [
            TextButton(
              onPressed: isAdding ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isAdding ? null : () async {
                if (playerController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(buildContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a player name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  isAdding = true;
                });

                try {
                  final token = await _getAuthToken();
                  if (token == null) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No authentication token found'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  final response = await http.post(
                    Uri.parse('$baseUrl/team/add-player'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                    body: jsonEncode({
                      'playerName': playerController.text.trim(),
                    }),
                  );

                  if (response.statusCode == 200) {
                    if (mounted) {
                      _hasChanges = true;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Player added successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      await _fetchTeamProfile();
                    }
                  } else {
                    final errorData = jsonDecode(response.body);
                    setDialogState(() {
                      isAdding = false;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(buildContext).showSnackBar(
                        SnackBar(
                          content: Text(errorData['error']?.toString() ?? 'Failed to add player'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  setDialogState(() {
                    isAdding = false;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(buildContext).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: isAdding
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
      ),
    );
  }

  Future<void> _removePlayer(String playerName) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Player"),
        content: Text("Are you sure you want to remove $playerName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      isSaving = true;
    });

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

      final response = await http.post(
        Uri.parse('$baseUrl/team/remove-player'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'playerName': playerName,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          _hasChanges = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Player removed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchTeamProfile();
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error']?.toString() ?? 'Failed to remove player'),
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
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }
}
