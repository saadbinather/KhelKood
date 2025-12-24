import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../shared/widgets/location_picker.dart';

class RegisterCourtPage extends StatefulWidget {
  final String ownerName;
  final String ownerEmail;
  final String ownerPassword;
  final String ownerPhone;
  final String ownerCnic;
  final String? firebaseUid;
  final bool fromGoogle;

  const RegisterCourtPage({
    super.key,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPassword,
    required this.ownerPhone,
    required this.ownerCnic,
    this.firebaseUid,
    this.fromGoogle = false,
  });

  @override
  State<RegisterCourtPage> createState() => _RegisterCourtPageState();
}

class _RegisterCourtPageState extends State<RegisterCourtPage> {
  final TextEditingController courtTitleCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();
  final TextEditingController openingCtrl = TextEditingController();
  final TextEditingController closingCtrl = TextEditingController();
  final TextEditingController cricketRateCtrl = TextEditingController();
  final TextEditingController futsalRateCtrl = TextEditingController();
  final TextEditingController padelRateCtrl = TextEditingController();
  final TextEditingController cricketFieldsCtrl = TextEditingController();
  final TextEditingController padelCourtsCtrl = TextEditingController();
  final TextEditingController futsalFieldsCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;

  bool isLoading = false;
  String? lastErrorMessage;

  void _selectLocation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPicker(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          onLocationSelected: (latitude, longitude, address) {
            setState(() {
              _latitude = latitude;
              _longitude = longitude;
              locationCtrl.text = address;
            });
          },
        ),
      ),
    );
  }

  Future<bool> registerCourtOwner() async {
    lastErrorMessage = null;
    try {
      if (courtTitleCtrl.text.trim().isEmpty ||
          locationCtrl.text.trim().isEmpty ||
          _latitude == null ||
          _longitude == null ||
          openingCtrl.text.trim().isEmpty ||
          closingCtrl.text.trim().isEmpty ||
          cricketRateCtrl.text.trim().isEmpty ||
          futsalRateCtrl.text.trim().isEmpty ||
          padelRateCtrl.text.trim().isEmpty ||
          cricketFieldsCtrl.text.trim().isEmpty ||
          padelCourtsCtrl.text.trim().isEmpty ||
          futsalFieldsCtrl.text.trim().isEmpty) {
        lastErrorMessage = "All fields are required. Please select a location on the map.";
        return false;
      }

      final response = await http.post(
        Uri.parse("http://localhost:5000/api/auth/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": widget.ownerName,
          "email": widget.ownerEmail,
          "password": widget.fromGoogle ? "" : widget.ownerPassword,
          "role": "courtowner",
          ...(widget.fromGoogle && widget.firebaseUid != null
              ? {"firebase_uid": widget.firebaseUid}
              : {}),
          "phone": widget.ownerPhone,
          "cnic": widget.ownerCnic,
          "latitude": _latitude,
          "longitude": _longitude,
          "location": locationCtrl.text.trim(),
          "courtTitle": courtTitleCtrl.text.trim(),
          "courtAddress": locationCtrl.text.trim(), // Use location as address
          "openingTime": int.parse(openingCtrl.text.trim()),
          "closingTime": int.parse(closingCtrl.text.trim()),
          "cricketRate": int.parse(cricketRateCtrl.text.trim()),
          "futsalRate": int.parse(futsalRateCtrl.text.trim()),
          "padelRate": int.parse(padelRateCtrl.text.trim()),
          "numOfCricketFields": int.parse(cricketFieldsCtrl.text.trim()),
          "numOfPadelCourts": int.parse(padelCourtsCtrl.text.trim()),
          "numOfFutsalFields": int.parse(futsalFieldsCtrl.text.trim()),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        try {
          final errorData = jsonDecode(response.body);
          lastErrorMessage = errorData['error'] ?? "Registration failed. Please try again.";
        } catch (e) {
          lastErrorMessage = "Registration failed. Please try again.";
        }
        return false;
      }
    } catch (e) {
      lastErrorMessage = "Error: ${e.toString()}";
      return false;
    }
  }

  void handleSubmit() async {
    if (courtTitleCtrl.text.isEmpty ||
        locationCtrl.text.isEmpty ||
        _latitude == null ||
        _longitude == null ||
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
          content: Text("All fields are required. Please select a location on the map."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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
          backgroundColor: Colors.redAccent,
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
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lastErrorMessage ?? "Could not register court owner. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Court Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              "Complete your court registration",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField("Court Title/Name", courtTitleCtrl),
            const SizedBox(height: 20),
            _buildLocationField(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField("Opening Time (0-23)", openingCtrl),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField("Closing Time (0-23)", closingCtrl),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Rates (Rs./hour)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField("Cricket", cricketRateCtrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField("Futsal", futsalRateCtrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField("Padel", padelRateCtrl),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Field Counts",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField("Cricket Fields", cricketFieldsCtrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField("Futsal Fields", futsalFieldsCtrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField("Padel Courts", padelCourtsCtrl),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: isLoading ? null : handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Register Court",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildLocationField() {
    return TextField(
      controller: locationCtrl,
      readOnly: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: "Court Location",
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.map, color: Colors.redAccent),
          onPressed: _selectLocation,
          tooltip: "Pick location on map",
        ),
        hintText: "Tap the map icon to select location",
        hintStyle: const TextStyle(color: Colors.white38),
      ),
    );
  }
}
