import 'package:flutter/material.dart';

class BookingHistoryPage extends StatelessWidget {
  const BookingHistoryPage({super.key});

  final List<Map<String, dynamic>> bookings = const [
    {
      "date": "Nov 7, 2025",
      "time": "6:00 PM - 7:00 PM",
      "court": "Court 1",
      "opponent": "Team Lightning",
      "status": "Won",
      "pointsEarned": 10,
    },
    {
      "date": "Nov 6, 2025",
      "time": "5:00 PM - 6:00 PM",
      "court": "Court 2",
      "opponent": "Team Thunder",
      "status": "Lost",
      "pointsEarned": 0,
    },
    {
      "date": "Nov 5, 2025",
      "time": "7:00 PM - 8:00 PM",
      "court": "Court 3",
      "opponent": "Team Hurricanes",
      "status": "Won",
      "pointsEarned": 15,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text("Booking History"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          final isWon = booking['status'] == 'Won';
          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Column: Date, Time, Court, Opponent
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['date'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          booking['time'],
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Text("Court: ${booking['court']}"),
                        Text("Opponent: ${booking['opponent']}"),
                      ],
                    ),
                  ),

                  // Right Column: Status & Points
                  Column(
                    children: [
                      Text(
                        booking['status'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isWon ? Colors.green : Colors.red,
                        ),
                      ),
                      Text("Points: ${booking['pointsEarned']}"),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
