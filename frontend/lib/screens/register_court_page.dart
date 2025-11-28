import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterCourtPage extends StatefulWidget {
  final String courtOwnerId;

  const RegisterCourtPage({super.key, required this.courtOwnerId});

  @override
  State<RegisterCourtPage> createState() => _RegisterCourtPageState();
}

class _RegisterCourtPageState extends State<RegisterCourtPage> {
  final TextEditingController courtNameCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController openingCtrl = TextEditingController();
  final TextEditingController closingCtrl = TextEditingController();
  final TextEditingController cricketRateCtrl = TextEditingController();
  final TextEditingController futsalRateCtrl = TextEditingController();
  final TextEditingController padelRateCtrl = TextEditingController();
  final TextEditingController cricketFieldsCtrl = TextEditingController();
  final TextEditingController padelCourtsCtrl = TextEditingController();
  final TextEditingController padelFieldsCtrl = TextEditingController();
  final TextEditingController ratingCtrl = TextEditingController(text: "0");

  bool isLoading = false;

  Future<bool> registerCourt() async {
    try {
      final response = await http.post(
        Uri.parse("http://localhost:5000/api/courts/registerCourt"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "courtName": courtNameCtrl.text.trim(),
          "address": addressCtrl.text.trim(),
          "openingTime": int.parse(openingCtrl.text.trim()),
          "closingTime": int.parse(closingCtrl.text.trim()),
          "cricketRate": int.parse(cricketRateCtrl.text.trim()),
          "futsalRate": int.parse(futsalRateCtrl.text.trim()),
          "padelRate": int.parse(padelRateCtrl.text.trim()),
          "numOfCricketFields": int.parse(cricketFieldsCtrl.text.trim()),
          "numOfPadelCourts": int.parse(padelCourtsCtrl.text.trim()),
          "numOfPadelFields": int.parse(padelFieldsCtrl.text.trim()),
          "rating": double.parse(ratingCtrl.text.trim()),
          "courtownerID": widget.courtOwnerId,
        }),
      );

      print("Court Register Response: ${response.body}");

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("Court Register Error: $e");
      return false;
    }
  }

  void handleSubmit() async {
    if (courtNameCtrl.text.isEmpty ||
        addressCtrl.text.isEmpty ||
        openingCtrl.text.isEmpty ||
        closingCtrl.text.isEmpty ||
        cricketRateCtrl.text.isEmpty ||
        futsalRateCtrl.text.isEmpty ||
        padelRateCtrl.text.isEmpty ||
        cricketFieldsCtrl.text.isEmpty ||
        padelCourtsCtrl.text.isEmpty ||
        padelFieldsCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All fields are required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final success = await registerCourt();

    setState(() => isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Court Registered Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not register court."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Court"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            textField("Court Name", courtNameCtrl),
            textField("Address", addressCtrl),
            numberField("Opening Time (0–23)", openingCtrl),
            numberField("Closing Time (0–23)", closingCtrl),
            numberField("Cricket Rate", cricketRateCtrl),
            numberField("Futsal Rate", futsalRateCtrl),
            numberField("Padel Rate", padelRateCtrl),
            numberField("Number of Cricket Fields", cricketFieldsCtrl),
            numberField("Number of Padel Courts", padelCourtsCtrl),
            numberField("Number of Padel Fields", padelFieldsCtrl),
            numberField("Rating (0–10)", ratingCtrl),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Register Court"),
            )
          ],
        ),
      ),
    );
  }

  Widget textField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget numberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
