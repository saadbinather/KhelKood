import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../Admin/dashboard.dart';
import '../CourtOwner/dash_board.dart';
import 'dashboard_page.dart';
import 'choose_register_page.dart';
import '../config/google_auth_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool isGoogleLoading = false;

  // GOOGLE SIGN-IN
  Future<void> googleLogin() async {
    try {
      setState(() => isGoogleLoading = true);

      // IMPORTANT: You need to get your OAuth Client ID from Google Cloud Console
      // Steps:
      // 1. Go to: https://console.cloud.google.com/apis/credentials?project=khelkooddb
      // 2. Click "Create Credentials" > "OAuth client ID"
      // 3. Application type: "Web application"
      // 4. Name: "KhelKood Web Client"
      // 5. Authorized JavaScript origins: Add "http://localhost:5000" and your domain
      // 6. Authorized redirect URIs: Add "http://localhost:5000" and your domain
      // 7. Copy the Client ID (format: 123456789-abc...xyz.apps.googleusercontent.com)
      // 8. Replace the value below with your actual Client ID
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // Use clientId from config if available, otherwise read from meta tag
        clientId: GoogleAuthConfig.clientId,
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        setState(() => isGoogleLoading = false);
        return;
      }

      // Step 2: Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception("Failed to get ID token from Google");
      }

      // Step 3: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // Step 4: Sign in to Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Step 5: Get Firebase ID token
      final token = await userCredential.user!.getIdToken();
      
      if (token == null) {
        setState(() => isGoogleLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to get authentication token"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Step 6: Send token to backend
      final response = await http.post(
        Uri.parse("http://localhost:5000/api/auth/google-login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      );

      setState(() => isGoogleLoading = false);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        // Handle different response statuses
        if (data["status"] == "choose_role") {
          // User needs to choose role and complete registration
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChooseRegisterPage(
                  firebaseUid: data["firebase_uid"],
                  email: data["email"],
                  fromGoogle: true,
                ),
              ),
            );
          }
        } else if (data["status"] == "blocked") {
          // Account not verified or rejected
          if (mounted) {
            _showVerificationDialog(
              title: 'Account Not Verified',
              message: 'Your account is not verified. Please wait for admin approval.',
              icon: Icons.block,
              color: Colors.red,
            );
          }
        } else if (data["status"] == "ok") {
          // Verified user - save token and redirect
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);

          final role = data["role"];
          if (mounted) {
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
                MaterialPageRoute(builder: (_) => AdminDashboard()),
              );
            }
          }
        }
      } else {
        // Handle error response
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Google login failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isGoogleLoading = false);
      print("Google Login Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Google sign-in failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
        MaterialPageRoute(builder: (_) => AdminDashboard()),
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

            // GOOGLE SIGN-IN BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isGoogleLoading ? null : googleLogin,
                icon: isGoogleLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_mobiledata, color: Colors.white70),
                label: isGoogleLoading
                    ? const Text(
                        "Signing in...",
                        style: TextStyle(color: Colors.white70),
                      )
                    : const Text(
                        "Continue with Google",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // DIVIDER
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[700])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "OR",
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[700])),
              ],
            ),

            const SizedBox(height: 20),

            // EMAIL FIELD
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

            // PASSWORD FIELD
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

            // LOGIN BUTTON
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
                onPressed: (isLoading || isGoogleLoading) ? null : handleLogin,
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

            const SizedBox(height: 20),

            // NEW TEXT BUTTON: New to KhelKood?
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChooseRegisterPage()),
                );
              },
              child: const Text(
                "New to KhelKood?",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
