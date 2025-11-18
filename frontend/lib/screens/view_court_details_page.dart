import 'package:flutter/material.dart';

class ViewCourtDetailsPage extends StatefulWidget {
  final String courtId; // now a String

  const ViewCourtDetailsPage({super.key, required this.courtId});

  @override
  State<ViewCourtDetailsPage> createState() => _ViewCourtDetailsPageState();
}

class _ViewCourtDetailsPageState extends State<ViewCourtDetailsPage> {
  Map<String, dynamic>? courtData;
  DateTime selectedDate = DateTime.now();
  List<String> selectedSlots = [];

  // -------------------- Simulated API Call --------------------
  Future<Map<String, dynamic>> _fetchCourtDetails() async {
    await Future.delayed(const Duration(milliseconds: 500)); // fake delay

    // Dummy response (always same) — you can later use widget.courtId to call real API
    return {
      "courtId": widget.courtId,
      "courtName": "Mega Futsal Arena",
      "location": "F-11 Markaz, Islamabad",
      "peakRate": 1700,
      "offPeakRate": 1300,
      "contact": "0311-1234567",
      "fields": [
        {
          "name": "Field 1",
          "slots": [
            {"time": "7pm-8pm", "available": true},
            {"time": "8pm-9pm", "available": true},
            {"time": "9pm-10pm", "available": false},
            {"time": "10pm-11pm", "available": true},
          ],
        },
        {
          "name": "Field 2",
          "slots": [
            {"time": "7pm-8pm", "available": true},
            {"time": "8pm-9pm", "available": false},
            {"time": "9pm-10pm", "available": true},
            {"time": "10pm-11pm", "available": true},
          ],
        },
      ],
    };
  }

  List<String> get allTimes => ["7pm-8pm", "8pm-9pm", "9pm-10pm", "10pm-11pm"];

  bool isConsecutive(List<String> slots) {
    if (slots.length < 2) return true;
    List<int> indices = slots.map((t) => allTimes.indexOf(t)).toList()..sort();
    for (int i = 1; i < indices.length; i++) {
      if (indices[i] - indices[i - 1] != 1) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadCourtData();
  }

  void _loadCourtData() async {
    final data = await _fetchCourtDetails();
    if (!mounted) return;
    setState(() => courtData = data);
  }

  @override
  Widget build(BuildContext context) {
    if (courtData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0E0E),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final fields = courtData!["fields"] as List;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        title: Text(
          "${courtData!["courtName"]} (${courtData!["courtId"]})",
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courtData!["location"],
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Peak Rate: ${courtData!["peakRate"]}/hr",
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              "Off-Peak Rate: ${courtData!["offPeakRate"]}/hr",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 15),

            // Calendar
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected =
                      date.year == selectedDate.year &&
                      date.month == selectedDate.month &&
                      date.day == selectedDate.day;

                  return GestureDetector(
                    onTap: () => setState(() => selectedDate = date),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.deepPurpleAccent
                            : Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              [
                                "Sun",
                                "Mon",
                                "Tue",
                                "Wed",
                                "Thu",
                                "Fri",
                                "Sat",
                              ][date.weekday % 7],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${date.day}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Slots table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Time column
                    Column(
                      children: [
                        Container(
                          width: 100,
                          padding: const EdgeInsets.all(8),
                          color: Colors.red,
                          child: const Text(
                            "Time",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...allTimes.map(
                          (t) => Container(
                            width: 100,
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              t,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Field columns
                    ...fields.map((field) {
                      final slots = field["slots"] as List;
                      return Column(
                        children: [
                          Container(
                            width: 180,
                            padding: const EdgeInsets.all(8),
                            color: Colors.red,
                            child: Text(
                              field["name"],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...slots.map((slot) {
                            final time = slot["time"];
                            final available = slot["available"];
                            final isSelected = selectedSlots.contains(time);

                            return GestureDetector(
                              onTap: () {
                                if (!available) return;
                                setState(() {
                                  if (isSelected) {
                                    selectedSlots.remove(time);
                                  } else {
                                    selectedSlots.add(time);
                                  }
                                });
                              },
                              child: Container(
                                width: 180,
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !available
                                      ? Colors.black
                                      : (isSelected
                                            ? Colors.deepPurpleAccent
                                            : Colors.grey[900]),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: available
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      )
                                    : const Icon(
                                        Icons.block,
                                        color: Colors.red,
                                      ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                ),
                onPressed: () {
                  if (selectedSlots.isEmpty) {
                    _error("Select at least 1 time slot");
                    return;
                  }
                  if (!isConsecutive(selectedSlots)) {
                    _error("Select consecutive time slots only");
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaymentPage()),
                  );
                },
                child: const Text(
                  "Proceed to Payment",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0E0E0E),
      body: Center(
        child: Text(
          "Payment Page",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
      ),
    );
  }
}
