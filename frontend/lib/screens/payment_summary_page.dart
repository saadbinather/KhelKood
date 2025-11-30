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
    final int totalAmount = slotCount * ratePerHour;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          "Payment Summary",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------ RECEIPT ------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurpleAccent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Booking Summary",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _row("Slots Selected:", "$slotCount"),
                  _row("Rate per Hour:", "Rs $ratePerHour"),
                  const Divider(color: Colors.white30),
                  _row(
                    "Total Amount:",
                    "Rs $totalAmount",
                    isBold: true,
                    isLarge: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ------------------ ACTION BUTTON ------------------
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
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
                child: Text(
                  actionType == "booking"
                      ? "Confirm Booking"
                      : "Create Challenge",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLarge ? 20 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

