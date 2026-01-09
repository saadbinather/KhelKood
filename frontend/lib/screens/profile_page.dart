import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'booking_history_page.dart';
import 'match_history_page.dart';
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
          errorMessage =
              errorData['error']?.toString() ?? 'Failed to fetch team profile';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen
        ? 16.0
        : isTablet
        ? 32.0
        : 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop(_hasChanges);
          },
        ),
        title: Row(
          children: [
            Icon(
              Icons.person,
              color: Colors.redAccent,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 18 : 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: teamData == null
                ? null
                : () {
                    _showEditDialog();
                  },
            tooltip: 'Edit Profile',
          ),
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
            tooltip: 'Booking History',
          ),
        ],
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
                  Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: isSmallScreen ? 48 : 60,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  ElevatedButton(
                    onPressed: _fetchTeamProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : teamData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    color: Colors.white24,
                    size: isSmallScreen ? 48 : 60,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    'No team data found',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: isSmallScreen ? 12 : 20),
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.group,
                      color: Colors.redAccent,
                      size: isSmallScreen ? 50 : 60,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),

                  // Team Name
                  Text(
                    teamData!['teamName']?.toString() ?? 'Team',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 4 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      teamData!['sports']?.toString().toUpperCase() ?? 'N/A',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 32),

                  // Info Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      child: Column(
                        children: [
                          profileRow(
                            Icons.email_outlined,
                            "Email",
                            teamData!['email']?.toString() ?? 'N/A',
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          profileRow(
                            Icons.phone_outlined,
                            "Phone",
                            teamData!['phone']?.toString() ?? 'N/A',
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          profileRow(
                            Icons.sports_soccer,
                            "Sport",
                            teamData!['sports']?.toString() ?? 'N/A',
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          profileRow(
                            Icons.stars,
                            "Points",
                            (teamData!['points'] ?? 0).toString(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 20 : 24),

                  // Match History Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MatchHistoryPage(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.history,
                                    color: Colors.redAccent,
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                  SizedBox(width: isSmallScreen ? 12 : 16),
                                  Text(
                                    "Match History",
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white54,
                                size: isSmallScreen ? 14 : 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 20 : 24),

                  // Player List
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    color: Colors.redAccent,
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                  SizedBox(width: isSmallScreen ? 8 : 12),
                                  Text(
                                    "Players",
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isSaving
                                      ? null
                                      : () {
                                          _showAddPlayerDialog();
                                        },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: EdgeInsets.all(
                                      isSmallScreen ? 8 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      color: Colors.redAccent,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Divider(color: Colors.white24),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          if (players.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 12 : 16,
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.person_add_outlined,
                                      color: Colors.white24,
                                      size: isSmallScreen ? 32 : 40,
                                    ),
                                    SizedBox(height: isSmallScreen ? 8 : 12),
                                    Text(
                                      'No players added yet',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: isSmallScreen ? 14 : 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...players.asMap().entries.map((entry) {
                              final index = entry.key;
                              final player = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < players.length - 1
                                      ? (isSmallScreen ? 10 : 12)
                                      : 0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(
                                            isSmallScreen ? 8 : 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.redAccent,
                                            size: isSmallScreen ? 18 : 20,
                                          ),
                                        ),
                                        SizedBox(
                                          width: isSmallScreen ? 10 : 12,
                                        ),
                                        Text(
                                          player,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 14 : 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: isSaving
                                            ? null
                                            : () {
                                                _removePlayer(player);
                                              },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            isSmallScreen ? 8 : 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.red,
                                            size: isSmallScreen ? 18 : 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 20 : 24),
                ],
              ),
            ),
    );
  }

  Widget profileRow(IconData icon, String title, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Row(
      children: [
        Icon(icon, color: Colors.redAccent, size: isSmallScreen ? 18 : 20),
        SizedBox(width: isSmallScreen ? 10 : 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
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
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.redAccent, size: 24),
              SizedBox(width: 12),
              Text(
                "Edit Profile",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: teamNameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Team Name",
                      labelStyle: TextStyle(color: Colors.white54),
                      prefixIcon: Icon(
                        Icons.flag_outlined,
                        color: Colors.redAccent.withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey[700]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: TextStyle(color: Colors.white54),
                      errorText: emailError,
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: Colors.redAccent.withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey[700]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                      ),
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
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText:
                          "Phone Number (e.g., 1234-567890 or 1234567890)",
                      labelStyle: TextStyle(color: Colors.white54),
                      errorText: phoneError,
                      helperText: "10 digits, optional dash after 4th digit",
                      helperStyle: TextStyle(color: Colors.white54),
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                        color: Colors.redAccent.withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey[700]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                      ),
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
              child: Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: isSaving
                  ? null
                  : () {
                      // Validate before submitting
                      bool isValid = true;

                      // Validate phone
                      if (!_validatePhoneFormat(phoneController.text.trim())) {
                        setDialogState(() {
                          phoneError =
                              "Invalid format. Must be 10 digits (e.g., 1234-567890)";
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
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.redAccent, size: 24),
              SizedBox(width: 12),
              Text(
                "Add Player",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          content: TextField(
            controller: playerController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Player Name",
              labelStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(
                Icons.person_outline,
                color: Colors.redAccent.withOpacity(0.7),
              ),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.redAccent, width: 2),
              ),
            ),
            enabled: !isAdding,
          ),
          actions: [
            TextButton(
              onPressed: isAdding ? null : () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: isAdding
                  ? null
                  : () async {
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
                                content: Text(
                                  errorData['error']?.toString() ??
                                      'Failed to add player',
                                ),
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
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Remove Player",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to remove $playerName?",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
        body: jsonEncode({'playerName': playerName}),
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
              content: Text(
                errorData['error']?.toString() ?? 'Failed to remove player',
              ),
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
