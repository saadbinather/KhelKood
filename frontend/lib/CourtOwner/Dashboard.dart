import 'package:flutter/material.dart';
import 'court_management_page.dart'; // Import the Court Management Page

class CourtOwnerDashboard extends StatelessWidget {
  const CourtOwnerDashboard({super.key});

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
                // Navigate to Court Management Page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CourtManagementPage(),
                  ),
                );
              },
            ),

            dashboardButton(
              title: "View Bookings",
              icon: Icons.calendar_month,
              onTap: () {},
            ),

            dashboardButton(
              title: "Payments",
              icon: Icons.payments,
              onTap: () {},
            ),

            dashboardButton(
              title: "Profile Settings",
              icon: Icons.settings,
              onTap: () {},
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
