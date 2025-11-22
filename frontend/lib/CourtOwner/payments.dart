import 'package:flutter/material.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({Key? key}) : super(key: key);

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  // -----------------------------
  // Dummy JSON for payments
  // -----------------------------
  final List<Map<String, dynamic>> pendingPayments = [
    {
      "bookingId": "B001",
      "team": "Team Thunder",
      "sport": "Cricket",
      "date": "2025-11-25",
      "time": "10:00 AM",
      "amount": 500
    },
    {
      "bookingId": "B002",
      "team": "The Strikers",
      "sport": "Football",
      "date": "2025-11-26",
      "time": "3:00 PM",
      "amount": 700
    },
  ];

  final List<Map<String, dynamic>> paidPayments = [
    {
      "bookingId": "B100",
      "team": "Ace Players",
      "sport": "Padel",
      "date": "2025-11-15",
      "time": "1:00 PM",
      "amount": 600
    },
    {
      "bookingId": "B101",
      "team": "Goal Masters",
      "sport": "Football",
      "date": "2025-11-18",
      "time": "11:00 AM",
      "amount": 800
    },
  ];

  // -----------------------------
  // Payment card widget
  // -----------------------------
  Widget buildPaymentCard(Map<String, dynamic> payment, bool isPaid) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(
          payment['team'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${payment['sport']} | ${payment['date']} at ${payment['time']}",
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "₹${payment['amount']}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPaid ? "Paid" : "Pending",
              style: TextStyle(
                color: isPaid ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------
  // Build page
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: const Text("Payments"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Pending"),
              Tab(text: "Paid"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // -------------------------
            // Pending Payments (Upcoming Bookings)
            // -------------------------
            ListView.builder(
              itemCount: pendingPayments.length,
              itemBuilder: (context, index) {
                return buildPaymentCard(pendingPayments[index], false);
              },
            ),

            // -------------------------
            // Paid Payments (Past Bookings)
            // -------------------------
            ListView.builder(
              itemCount: paidPayments.length,
              itemBuilder: (context, index) {
                return buildPaymentCard(paidPayments[index], true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
