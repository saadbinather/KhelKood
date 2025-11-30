import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../screens/login_page.dart';
import 'court_management_page.dart';
import 'booking_management_page.dart';
import 'feedback.dart'; // Court Feedback Page
import 'payments.dart'; // Payments Page
import 'profile_settings_page.dart';

class CourtOwnerDashboard extends StatelessWidget {
  const CourtOwnerDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Call logout endpoint
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (token != null) {
          await http.post(
            Uri.parse('http://localhost:5000/api/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        }

        // Clear local token
        await prefs.remove('auth_token');
      } catch (e) {
        // Even if API call fails, clear local token
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
      }

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // dark theme

      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text(
          "Court Owner Dashboard",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome, Court Owner!",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------------
            // Dashboard Buttons / Features
            // -------------------------------
            dashboardButton(
              title: "Manage Courts",
              icon: Icons.sports_tennis,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CourtManagementPage(),
                  ),
                );
              },
            ),



            dashboardButton(
              title: "View Feedback",
              icon: Icons.feedback,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CourtFeedbackPage(),
                  ),
                );
              },
            ),

            dashboardButton(
              title: "Payments",
              icon: Icons.payments,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentsPage()),
                );
              },
            ),

            dashboardButton(
              title: "Profile Settings",
              icon: Icons.settings,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileSettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------
  // Reusable Button Widget
  // ---------------------------------------
  Widget dashboardButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),

      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[900],
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        onPressed: onTap,

        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent, size: 28),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
