import 'package:flutter/material.dart';

class PaymentSummaryPage extends StatelessWidget {
  final int slotCount; // how many slots user selected
  final int ratePerHour; // court rate
  final String actionType; // "booking" OR "challenge"

  const PaymentSummaryPage({
    super.key,
    required this.slotCount,
    required this.ratePerHour,
    required this.actionType,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen
        ? 12.0
        : isTablet
        ? 24.0
        : 20.0;

    final int totalAmount = slotCount * ratePerHour;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              "Payment Summary",
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isSmallScreen ? 16 : 20),
            // ------------------ RECEIPT ------------------
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.summarize,
                        color: Colors.redAccent,
                        size: isSmallScreen ? 20 : 24,
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      Text(
                        "Booking Summary",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 14 : 16),
                  _row(
                    context,
                    Icons.schedule,
                    "Slots Selected:",
                    "$slotCount",
                    isSmallScreen,
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 12),
                  _row(
                    context,
                    Icons.currency_rupee,
                    "Rate per Hour:",
                    "Rs $ratePerHour",
                    isSmallScreen,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Divider(color: Colors.white24),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _row(
                    context,
                    Icons.payments,
                    "Total Amount:",
                    "Rs $totalAmount",
                    isSmallScreen,
                    isBold: true,
                    isLarge: true,
                  ),
                ],
              ),
            ),

            SizedBox(height: isSmallScreen ? 32 : 40),

            // ------------------ ACTION BUTTON ------------------
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 32 : 40,
                    vertical: isSmallScreen ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  if (actionType == "booking") {
                    // =======================
                    // TODO: Call Booking API
                    // send slots, time, field, date, userId, etc.
                    // =======================
                  } else {
                    // =======================
                    // TODO: Navigate to Create Challenge Flow
                    // send cost, slot info, court info, etc.
                    // =======================
                  }
                },
                icon: Icon(
                  actionType == "booking"
                      ? Icons.check_circle
                      : Icons.add_circle,
                  size: isSmallScreen ? 20 : 24,
                ),
                label: Text(
                  actionType == "booking"
                      ? "Confirm Booking"
                      : "Create Challenge",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    bool isSmallScreen, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Colors.redAccent,
              size: isSmallScreen ? 16 : 18,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isLarge
                ? (isSmallScreen ? 18 : 20)
                : (isSmallScreen ? 14 : 16),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

