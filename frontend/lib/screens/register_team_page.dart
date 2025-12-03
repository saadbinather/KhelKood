import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterTeamPage extends StatefulWidget {
  final String? firebaseUid;
  final String? email;
  final bool fromGoogle;

  const RegisterTeamPage({
    super.key,
    this.firebaseUid,
    this.email,
    this.fromGoogle = false,
  });

  @override
  State<RegisterTeamPage> createState() => _RegisterTeamPageState();
}

class _RegisterTeamPageState extends State<RegisterTeamPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController teamNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  List<TextEditingController> playerControllers = [];
  String selectedSport = "futsal";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.fromGoogle && widget.email != null) {
      emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    teamNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    for (var controller in playerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void addPlayerField() {
    setState(() {
      playerControllers.add(TextEditingController());
    });
  }

  void removePlayerField(int index) {
    if (index < 0 || index >= playerControllers.length) {
      return;
    }

    setState(() {
      // Dispose the controller
      playerControllers[index].dispose();
      playerControllers.removeAt(index);
    });
  }

  Future<void> registerTeam() async {
    final name = nameController.text.trim();
    final teamName = teamNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();

    List<String> players = playerControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();

    if (name.isEmpty || teamName.isEmpty || email.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!widget.fromGoogle && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password is required"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!widget.fromGoogle && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate player count based on sport
    final minPlayers = (selectedSport == "padel") ? 2 : 5;
    final sportName = selectedSport.toUpperCase();

    if (players.length < minPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "$sportName requires at least $minPlayers players. You have ${players.length} player${players.length == 1 ? '' : 's'}.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("http://localhost:5000/api/auth/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": widget.fromGoogle ? "" : password,
          "role": "team",
          "teamName": teamName,
          "phone": phone,
          "sports": selectedSport,
          "players": players,
          ...(widget.fromGoogle && widget.firebaseUid != null
              ? {"firebase_uid": widget.firebaseUid}
              : {}),
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ?? "Team Registered Successfully!",
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
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
    final verticalPadding = isSmallScreen ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.group_add,
              color: Colors.redAccent,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              "Register Team",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 18 : 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isSmallScreen ? 4 : 8),
            Row(
              children: [
                Icon(
                  Icons.sports_soccer,
                  color: Colors.redAccent.withOpacity(0.8),
                  size: isSmallScreen ? 18 : 20,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Text(
                    "Create your team profile",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            _buildTextField(
              "Full Name",
              nameController,
              icon: Icons.person_outline,
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            _buildTextField(
              "Team Name",
              teamNameController,
              icon: Icons.flag_outlined,
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            _buildTextField(
              "Email",
              emailController,
              isEmail: true,
              readOnly: widget.fromGoogle,
              icon: Icons.email_outlined,
            ),
            if (!widget.fromGoogle) ...[
              SizedBox(height: isSmallScreen ? 16 : 20),
              _buildTextField(
                "Password (min 6 characters)",
                passwordController,
                isPassword: true,
                icon: Icons.lock_outline,
              ),
            ],
            SizedBox(height: isSmallScreen ? 16 : 20),
            _buildTextField(
              "Phone Number",
              phoneController,
              isPhone: true,
              icon: Icons.phone_outlined,
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            _buildSportDropdown(),
            SizedBox(height: isSmallScreen ? 24 : 32),
            _buildPlayersSection(),
            SizedBox(height: isSmallScreen ? 32 : 40),
            _buildRegisterButton(),
            SizedBox(height: isSmallScreen ? 20 : 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
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
                  size: isSmallScreen ? 18 : 20,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Players",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white54,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          selectedSport == "padel"
                              ? "Minimum 2 players"
                              : "Minimum 5 players",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: isSmallScreen ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: addPlayerField,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: Colors.redAccent,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        if (playerControllers.isEmpty)
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.grey[900]!.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[800]!.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Colors.white38,
                  size: isSmallScreen ? 18 : 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tap the + button to add players",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: isSmallScreen ? 13 : 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(playerControllers.length, (index) {
            // Safety check before building
            if (index >= 0 && index < playerControllers.length) {
              return Padding(
                padding: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
                child: _buildPlayerField(index),
              );
            }
            return const SizedBox.shrink();
          }),
      ],
    );
  }

  Widget _buildPlayerField(int index) {
    // Safety check: ensure index is valid
    if (index < 0 || index >= playerControllers.length) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.person,
            color: Colors.redAccent,
            size: isSmallScreen ? 18 : 20,
          ),
        ),
        SizedBox(width: isSmallScreen ? 10 : 12),
        Expanded(
          child: _buildTextField(
            "Player ${index + 1}",
            playerControllers[index],
            showIcon: false,
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (index >= 0 && index < playerControllers.length) {
                removePlayerField(index);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.close,
                color: Colors.redAccent,
                size: isSmallScreen ? 18 : 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;

    return Center(
      child: ElevatedButton(
        onPressed: isLoading ? null : registerTeam,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen
                ? 40
                : isTablet
                ? 56
                : 48,
            vertical: isSmallScreen ? 12 : 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: isSmallScreen ? 18 : 20,
                height: isSmallScreen ? 18 : 20,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.app_registration, size: isSmallScreen ? 18 : 20),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Text(
                    "Register Team",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    bool isEmail = false,
    bool isPhone = false,
    bool readOnly = false,
    IconData? icon,
    bool showIcon = true,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return TextField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      keyboardType: isEmail
          ? TextInputType.emailAddress
          : isPhone
          ? TextInputType.phone
          : TextInputType.text,
      style: TextStyle(
        color: readOnly ? Colors.white54 : Colors.white,
        fontSize: isSmallScreen ? 14 : 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white54,
          fontSize: isSmallScreen ? 14 : 16,
        ),
        prefixIcon: showIcon && icon != null
            ? Icon(
                icon,
                color: Colors.redAccent.withOpacity(0.7),
                size: isSmallScreen ? 20 : 22,
              )
            : null,
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: showIcon && icon != null ? 12 : 16,
          vertical: isSmallScreen ? 14 : 16,
        ),
      ),
    );
  }

  Widget _buildSportDropdown() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 4 : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            _getSportIcon(selectedSport),
            color: Colors.redAccent,
            size: isSmallScreen ? 18 : 20,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: DropdownButton<String>(
              value: selectedSport,
              dropdownColor: Colors.grey[900],
              underline: Container(),
              isExpanded: true,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.redAccent,
                size: isSmallScreen ? 24 : 28,
              ),
              items:
                  [
                    {"value": "futsal", "icon": Icons.sports_soccer},
                    {"value": "cricket", "icon": Icons.sports_cricket},
                    {"value": "padel", "icon": Icons.sports_tennis},
                  ].map<DropdownMenuItem<String>>((sport) {
                    return DropdownMenuItem<String>(
                      value: sport["value"] as String,
                      child: Row(
                        children: [
                          Icon(
                            sport["icon"] as IconData,
                            color: Colors.redAccent.withOpacity(0.7),
                            size: isSmallScreen ? 18 : 20,
                          ),
                          SizedBox(width: isSmallScreen ? 8 : 12),
                          Text(
                            (sport["value"] as String).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() => selectedSport = value!);
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case "futsal":
        return Icons.sports_soccer;
      case "cricket":
        return Icons.sports_cricket;
      case "padel":
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }
}
