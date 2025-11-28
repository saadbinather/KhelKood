import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterTeamPage extends StatefulWidget {
  const RegisterTeamPage({super.key});

  @override
  State<RegisterTeamPage> createState() => _RegisterTeamPageState();
}

class _RegisterTeamPageState extends State<RegisterTeamPage> {
  final TextEditingController teamNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  List<TextEditingController> playerControllers = [];

  String selectedSport = "futsal"; // default sport

  bool isLoading = false;

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
    final teamName = teamNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();

    // players list
    List<String> players = playerControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();

    if (teamName.isEmpty || email.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final response = await http.post(
      Uri.parse("http://localhost:5000/api/auth/registerTeam"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "teamName": teamName,
        "email": email,
        "phone": phone,
        "sports": selectedSport,
        "players": players,
      }),
    );

    setState(() => isLoading = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Team Registered Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } else {
      print("Register Error: ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${response.body}"),
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
              style: const TextStyle(color: Colors.white),
              decoration: inputStyle("Email"),
            ),
            const SizedBox(height: 20),

            // PHONE
            TextField(
              controller: phoneController,
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
