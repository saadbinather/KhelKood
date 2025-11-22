import 'package:flutter/material.dart';

class BookingManagementPage extends StatefulWidget {
  const BookingManagementPage({Key? key}) : super(key: key);

  @override
  State<BookingManagementPage> createState() => _BookingManagementPageState();
}

class _BookingManagementPageState extends State<BookingManagementPage> {
  // Dummy data
  List<Map<String, dynamic>> upcomingBookings = [
    {
      "id": 1,
      "court": "Court 1",
      "sport": "Cricket",
      "date": "2025-11-25",
      "time": "10:00 AM"
    },
    {
      "id": 2,
      "court": "Court 2",
      "sport": "Football",
      "date": "2025-11-26",
      "time": "2:00 PM"
    },
  ];

  List<Map<String, dynamic>> pastBookings = [
    {
      "id": 3,
      "court": "Court 3",
      "sport": "Padel",
      "date": "2025-11-20",
      "time": "11:00 AM"
    },
    {
      "id": 4,
      "court": "Court 1",
      "sport": "Cricket",
      "date": "2025-11-21",
      "time": "3:00 PM"
    },
  ];

  void cancelBooking(int id) {
    setState(() {
      upcomingBookings.removeWhere((booking) => booking['id'] == id);
    });
  }

  void addResult(Map<String, dynamic> booking) {
    final TextEditingController resultController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add Result for ${booking['sport']}"),
        content: TextField(
          controller: resultController,
          decoration: InputDecoration(
            labelText: booking['sport'] == "Cricket"
                ? "Runs scored / Winner"
                : booking['sport'] == "Football"
                    ? "Score (Team A - Team B)"
                    : "Padel Result",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              // Here you can send the result to your backend API later
              print(
                  "Result for booking ${booking['id']}: ${resultController.text}");
              Navigator.pop(context);
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Widget buildBookingCard(Map<String, dynamic> booking, {bool isUpcoming = true}) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text("${booking['court']} - ${booking['sport']}"),
        subtitle: Text("${booking['date']} at ${booking['time']}"),
        trailing: ElevatedButton(
          onPressed: () {
            if (isUpcoming) {
              cancelBooking(booking['id']);
            } else {
              addResult(booking);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isUpcoming ? Colors.redAccent : Colors.green,
          ),
          child: Text(isUpcoming ? "Cancel" : "Add Result"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Bookings"),
        backgroundColor: Colors.redAccent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Upcoming Bookings",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...upcomingBookings
                  .map((booking) => buildBookingCard(booking, isUpcoming: true))
                  .toList(),
              const SizedBox(height: 20),
              const Text(
                "Past Bookings",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...pastBookings
                  .map((booking) => buildBookingCard(booking, isUpcoming: false))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }
}
