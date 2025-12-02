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

  String selectedSport = "futsal"; // default sport

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill email if from Google login
    if (widget.fromGoogle && widget.email != null) {
      emailController.text = widget.email!;
    }
  }

  // ADD PLAYER FIELD
  void addPlayerField() {
    setState(() {
      playerControllers.add(TextEditingController());
    });
  }

  // REMOVE PLAYER FIELD
  void removePlayerField(int index) {
    setState(() {
      playerControllers.removeAt(index);
    });
  }

  // SUBMIT TEAM REGISTRATION
  Future<void> registerTeam() async {
    final name = nameController.text.trim();
    final teamName = teamNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();

    // players list
    List<String> players = playerControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();

    // Validation - password not required for Google sign-in users
    if (name.isEmpty ||
        teamName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!widget.fromGoogle && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password is required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!widget.fromGoogle && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters"),
          backgroundColor: Colors.red,
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
          "password": widget.fromGoogle ? "" : password, // Empty password for Google users
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
            content: Text(responseData['message'] ?? "Team Registered Successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to login or choose register page
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text("Register Team"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // FULL NAME
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: inputStyle("Full Name"),
            ),
            const SizedBox(height: 20),

            // TEAM NAME
            TextField(
              controller: teamNameController,
              style: const TextStyle(color: Colors.white),
              decoration: inputStyle("Team Name"),
            ),
            const SizedBox(height: 20),

            // EMAIL
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              readOnly: widget.fromGoogle, // Disable editing if from Google
              style: const TextStyle(color: Colors.white),
              decoration: inputStyle("Email"),
            ),
            const SizedBox(height: 20),

            // PASSWORD (hidden for Google sign-in users)
            if (!widget.fromGoogle) ...[
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: inputStyle("Password (min 6 characters)"),
              ),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 20),

            // PHONE
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: inputStyle("Phone Number"),
            ),
            const SizedBox(height: 20),

            // SPORTS DROPDOWN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButton<String>(
                value: selectedSport,
                dropdownColor: Colors.grey[900],
                underline: Container(),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: [
                  "futsal",
                  "cricket",
                  "football",
                  "badminton",
                  "volleyball",
                ]
                    .map((sport) => DropdownMenuItem(
                          value: sport,
                          child: Text(sport.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedSport = value!);
                },
              ),
            ),

            const SizedBox(height: 30),

            // PLAYERS LABEL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Players",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                IconButton(
                  onPressed: addPlayerField,
                  icon: const Icon(Icons.add, color: Colors.redAccent),
                )
              ],
            ),

            // PLAYER INPUT FIELDS
            Column(
              children: List.generate(
                playerControllers.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: playerControllers[index],
                          style: const TextStyle(color: Colors.white),
                          decoration: inputStyle("Player Name"),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => removePlayerField(index),
                      )
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: isLoading ? null : registerTeam,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "REGISTER TEAM",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }

  InputDecoration inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
