import 'package:flutter/material.dart';

class CourtFeedbackPage extends StatefulWidget {
  const CourtFeedbackPage({Key? key}) : super(key: key);

  @override
  State<CourtFeedbackPage> createState() => _CourtFeedbackPageState();
}

class _CourtFeedbackPageState extends State<CourtFeedbackPage> {
  // -----------------------------
  // Dummy JSON feedback data
  // -----------------------------
  final List<Map<String, dynamic>> feedbackList = [
    {
      "team": "Team Thunder",
      "rating": 5,
      "comment": "Amazing court! Well maintained and friendly staff."
    },
    {
      "team": "The Strikers",
      "rating": 4,
      "comment": "Good experience but parking was limited."
    },
    {
      "team": "Ace Players",
      "rating": 3,
      "comment": null
    },
    {
      "team": "Goal Masters",
      "rating": 5,
      "comment": "Perfect for football matches! Will come again."
    },
  ];

  // -----------------------------
  // Widget to display star rating
  // -----------------------------
  Widget buildStars(int rating) {
    return Row(
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        ),
      ),
    );
  }

  // -----------------------------
  // Feedback card
  // -----------------------------
  Widget buildFeedbackCard(Map<String, dynamic> feedback) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              feedback['team'],
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            buildStars(feedback['rating']),
            const SizedBox(height: 8),
            Text(
              feedback['comment'] ?? "No comment provided.",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Court Feedback"),
        backgroundColor: Colors.redAccent,
      ),
      body: ListView.builder(
        itemCount: feedbackList.length,
        itemBuilder: (context, index) {
          return buildFeedbackCard(feedbackList[index]);
        },
      ),
    );
  }
}
