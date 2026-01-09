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
import '../core/constants/app_constants.dart';

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

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: GoogleAuthConfig.clientId,
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception("Failed to get ID token from Google");
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final token = await userCredential.user!.getIdToken();
      
      if (token == null) {
        setState(() => isGoogleLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to get authentication token"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final response = await http.post(
        Uri.parse("${AppConstants.baseUrl}/auth/google-login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      );

      setState(() => isGoogleLoading = false);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data["status"] == "choose_role") {
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
          if (mounted) {
            _showVerificationDialog(
              title: 'Account Not Verified',
              message: 'Your account is not verified. Please wait for admin approval.',
              icon: Icons.block,
              color: Colors.red,
            );
          }
        } else if (data["status"] == "ok") {
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
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Google login failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isGoogleLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Google sign-in failed. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> authenticateUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("${AppConstants.baseUrl}/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

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
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Login failed';
        return {
          'success': false,
          'error': errorMessage,
        };
      }
      return {'success': false, 'error': 'Unknown error occurred'};
    } catch (e) {
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
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final result = await authenticateUser(email, password);

    setState(() => isLoading = false);

    if (!result['success']) {
      final errorMessage = result['error'] ?? 'Login failed';
      
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
            backgroundColor: Colors.redAccent,
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
          backgroundColor: Colors.redAccent,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen ? 16.0 : isTablet ? 32.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Icon(
              Icons.login,
              color: Colors.redAccent,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              "Login",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 18 : 20,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: isSmallScreen ? 20 : 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sports_soccer,
                  color: Colors.redAccent,
                  size: isSmallScreen ? 32 : 40,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
              "KhelKood",
              style: TextStyle(
                    fontSize: isSmallScreen ? 28 : 32,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
                    letterSpacing: 1,
              ),
            ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              "Welcome back",
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: isSmallScreen ? 32 : 40),

            // GOOGLE SIGN-IN BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[700]!, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 14 : 16,
                  ),
                ),
                onPressed: isGoogleLoading ? null : googleLogin,
                icon: isGoogleLoading
                    ? SizedBox(
                        width: isSmallScreen ? 18 : 20,
                        height: isSmallScreen ? 18 : 20,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : Icon(
                        Icons.g_mobiledata,
                        color: Colors.white70,
                        size: isSmallScreen ? 20 : 24,
                      ),
                label: isGoogleLoading
                    ? Text(
                        "Signing in...",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      )
                    : Text(
                        "Continue with Google",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 24),

            // DIVIDER
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[700])),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                  child: Text(
                    "OR",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[700])),
              ],
            ),

            SizedBox(height: isSmallScreen ? 20 : 24),

            // EMAIL FIELD
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: Colors.redAccent.withOpacity(0.7),
                  size: isSmallScreen ? 20 : 22,
                ),
                filled: true,
                fillColor: Colors.grey[900],
                labelText: "Email",
                labelStyle: TextStyle(
                  color: Colors.white54,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
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
                  horizontal: 16,
                  vertical: isSmallScreen ? 14 : 16,
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 16 : 20),

            // PASSWORD FIELD
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: Colors.redAccent.withOpacity(0.7),
                  size: isSmallScreen ? 20 : 22,
                ),
                filled: true,
                fillColor: Colors.grey[900],
                labelText: "Password",
                labelStyle: TextStyle(
                  color: Colors.white54,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
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
                  horizontal: 16,
                  vertical: isSmallScreen ? 14 : 16,
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 24 : 30),

            // LOGIN BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: (isLoading || isGoogleLoading) ? null : handleLogin,
                icon: isLoading
                    ? SizedBox(
                        width: isSmallScreen ? 18 : 20,
                        height: isSmallScreen ? 18 : 20,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.login,
                        size: isSmallScreen ? 18 : 20,
                      ),
                label: isLoading
                    ? const Text("Logging in...")
                    : Text(
                        "LOGIN",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 24),

            // REGISTER LINK
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  color: Colors.white54,
                  size: isSmallScreen ? 16 : 18,
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChooseRegisterPage()),
                );
              },
                  child: Text(
                    "New to KhelKood? Register",
                style: TextStyle(
                  color: Colors.redAccent,
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w500,
                ),
              ),
            ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 20 : 24),
          ],
        ),
      ),
    );
  }
}
