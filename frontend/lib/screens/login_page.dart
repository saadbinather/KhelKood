import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Admin/dashboard.dart';

import 'dashboard_page.dart';
import '../CourtOwner/dash_board.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  // REAL BACKEND AUTHENTICATION
  Future<Map<String, dynamic>> authenticateUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("http://localhost:5000/api/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        // Save token if available
        if (data.containsKey("data") && data["data"].containsKey("token")) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data["data"]["token"]);
        } else if (data.containsKey("token")) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data["token"]);
        }

        if (data.containsKey("role") || (data.containsKey("data") && data["data"].containsKey("role"))) {
          return {
            'success': true,
            'role': (data["role"] ?? data["data"]["role"]).toString().toLowerCase(),
          };
        }
      } else {
        // Parse error message
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Login failed';
        return {
          'success': false,
          'error': errorMessage,
        };
      }
      return {'success': false, 'error': 'Unknown error occurred'};
    } catch (e) {
      print("Login Error: $e");
      return {'success': false, 'error': 'Network error. Please check your connection.'};
    }
  }

  void handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter email and password"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final result = await authenticateUser(email, password);

    setState(() => isLoading = false);

    if (!result['success']) {
      final errorMessage = result['error'] ?? 'Login failed';
      
      // Check if it's a pending or rejected account
      if (errorMessage.toLowerCase().contains('pending')) {
        _showVerificationDialog(
          title: 'Account Pending Verification',
          message: 'Your account is pending admin approval. Please wait for approval before logging in.',
          icon: Icons.pending_actions,
          color: Colors.orange,
        );
      } else if (errorMessage.toLowerCase().contains('rejected')) {
        _showVerificationDialog(
          title: 'Account Rejected',
          message: 'Your account has been rejected by admin. Please contact support for assistance.',
          icon: Icons.cancel,
          color: Colors.red,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final role = result['role'];
    if (role == "courtowner") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CourtOwnerDashboard()),
      );
    } else if (role == "player" || role == "team") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } else if (role == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminDashboard()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unknown role: $role"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVerificationDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
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
        backgroundColor: Colors.redAccent,
        title: const Text("Login", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "KhelKood",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                labelText: "Email",
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                labelText: "Password",
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isLoading ? null : handleLogin,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "LOGIN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
