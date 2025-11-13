import 'package:flutter/material.dart';

class ViewChallengePage extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final bool isIncoming;

  const ViewChallengePage({
    super.key,
    required this.challenge,
    required this.isIncoming,
  });

  @override
  Widget build(BuildContext context) {
    DateTime start = DateTime.parse(challenge["Start_Time"]);
    DateTime end = DateTime.parse(challenge["End_Time"]);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Challenge Details',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurpleAccent.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow("Date", challenge["Date"]),
              _infoRow(
                "Time Slot",
                "${_formatTime(start)} - ${_formatTime(end)}",
              ),
              _infoRow("Court Name", challenge["Court_Name"]),
              _infoRow("Host Team", challenge["Host_Team_Name"]),
              _infoRow("Total Price", "Rs ${challenge["Total_Price"]}"),

              const Spacer(),

              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isIncoming
                        ? Colors.green
                        : Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isIncoming
                              ? 'Challenge Accepted!'
                              : 'Challenge Cancelled!',
                        ),
                        backgroundColor: isIncoming
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(
                    isIncoming ? "Accept Challenge" : "Cancel Challenge",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "$label:",
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
