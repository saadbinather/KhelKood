import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterCourtPage extends StatefulWidget {
  final String ownerName;
  final String ownerEmail;
  final String ownerPassword;
  final String ownerPhone;
  final String ownerCnic;
  final String ownerLocation;

  const RegisterCourtPage({
    super.key,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPassword,
    required this.ownerPhone,
    required this.ownerCnic,
    required this.ownerLocation,
  });

  @override
  State<RegisterCourtPage> createState() => _RegisterCourtPageState();
}

class _RegisterCourtPageState extends State<RegisterCourtPage> {
  final TextEditingController courtTitleCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController openingCtrl = TextEditingController();
  final TextEditingController closingCtrl = TextEditingController();
  final TextEditingController cricketRateCtrl = TextEditingController();
  final TextEditingController futsalRateCtrl = TextEditingController();
  final TextEditingController padelRateCtrl = TextEditingController();
  final TextEditingController cricketFieldsCtrl = TextEditingController();
  final TextEditingController padelCourtsCtrl = TextEditingController();
  final TextEditingController futsalFieldsCtrl = TextEditingController();
  final TextEditingController ratingCtrl = TextEditingController(text: "0");

  bool isLoading = false;

  Future<bool> registerCourtOwner() async {
    try {
      // Validate all fields
      if (courtTitleCtrl.text.trim().isEmpty ||
          addressCtrl.text.trim().isEmpty ||
          openingCtrl.text.trim().isEmpty ||
          closingCtrl.text.trim().isEmpty ||
          cricketRateCtrl.text.trim().isEmpty ||
          futsalRateCtrl.text.trim().isEmpty ||
          padelRateCtrl.text.trim().isEmpty ||
          cricketFieldsCtrl.text.trim().isEmpty ||
          padelCourtsCtrl.text.trim().isEmpty ||
          futsalFieldsCtrl.text.trim().isEmpty) {
        return false;
      }

      final response = await http.post(
        Uri.parse("http://localhost:5000/api/auth/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": widget.ownerName,
          "email": widget.ownerEmail,
          "password": widget.ownerPassword,
          "role": "courtowner",
          "phone": widget.ownerPhone,
          "cnic": widget.ownerCnic,
          "courtName": widget.ownerLocation, // Using location as courtName
          "location": widget.ownerLocation,
          "courtTitle": courtTitleCtrl.text.trim(),
          "courtAddress": addressCtrl.text.trim(),
          "openingTime": int.parse(openingCtrl.text.trim()),
          "closingTime": int.parse(closingCtrl.text.trim()),
          "cricketRate": int.parse(cricketRateCtrl.text.trim()),
          "futsalRate": int.parse(futsalRateCtrl.text.trim()),
          "padelRate": int.parse(padelRateCtrl.text.trim()),
          "numOfCricketFields": int.parse(cricketFieldsCtrl.text.trim()),
          "numOfPadelCourts": int.parse(padelCourtsCtrl.text.trim()),
          "numOfFutsalFields": int.parse(futsalFieldsCtrl.text.trim()),
          "rating": double.parse(ratingCtrl.text.trim()),
        }),
      );

      print("Court Owner Register Response: ${response.body}");

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("Court Owner Register Error: $e");
      return false;
    }
  }

  void handleSubmit() async {
    if (courtTitleCtrl.text.isEmpty ||
        addressCtrl.text.isEmpty ||
        openingCtrl.text.isEmpty ||
        closingCtrl.text.isEmpty ||
        cricketRateCtrl.text.isEmpty ||
        futsalRateCtrl.text.isEmpty ||
        padelRateCtrl.text.isEmpty ||
        cricketFieldsCtrl.text.isEmpty ||
        padelCourtsCtrl.text.isEmpty ||
        futsalFieldsCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All fields are required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate time range
    final openingTime = int.tryParse(openingCtrl.text.trim());
    final closingTime = int.tryParse(closingCtrl.text.trim());
    if (openingTime == null ||
        closingTime == null ||
        openingTime < 0 ||
        openingTime > 23 ||
        closingTime < 0 ||
        closingTime > 23 ||
        openingTime >= closingTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid time range. Opening time must be less than closing time (0-23)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final success = await registerCourtOwner();
      setState(() => isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Court Owner Registered Successfully! Please wait for admin verification."),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to login or choose register page
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not register court owner. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
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
            textField("Court Title/Name", courtTitleCtrl),
            textField("Court Address", addressCtrl),
            numberField("Opening Time (0–23)", openingCtrl),
            numberField("Closing Time (0–23)", closingCtrl),
            numberField("Cricket Rate", cricketRateCtrl),
            numberField("Futsal Rate", futsalRateCtrl),
            numberField("Padel Rate", padelRateCtrl),
            numberField("Number of Cricket Fields", cricketFieldsCtrl),
            numberField("Number of Padel Courts", padelCourtsCtrl),
            numberField("Number of Futsal Fields", futsalFieldsCtrl),
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
