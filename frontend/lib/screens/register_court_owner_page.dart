import 'package:flutter/material.dart';
import 'register_court_page.dart';

class RegisterCourtOwnerPage extends StatefulWidget {
  const RegisterCourtOwnerPage({super.key});

  @override
  State<RegisterCourtOwnerPage> createState() => _RegisterCourtOwnerPageState();
}

class _RegisterCourtOwnerPageState extends State<RegisterCourtOwnerPage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController cnicCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();

  void goToCourtRegister() {
    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        passwordCtrl.text.isEmpty ||
        phoneCtrl.text.isEmpty ||
        cnicCtrl.text.isEmpty ||
        locationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All fields are required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Pass owner data to court registration page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterCourtPage(
          ownerName: nameCtrl.text.trim(),
          ownerEmail: emailCtrl.text.trim(),
          ownerPassword: passwordCtrl.text.trim(),
          ownerPhone: phoneCtrl.text,
          ownerCnic: cnicCtrl.text,
          ownerLocation: locationCtrl.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Court Owner"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            textField("Full Name", nameCtrl),
            textField("Email", emailCtrl, isEmail: true),
            textField(
              "Password (min 6 characters)",
              passwordCtrl,
              isPassword: true,
            ),
            textField("Phone Number", phoneCtrl, isNumber: true),
            textField("CNIC", cnicCtrl, isNumber: true),
            textField("Location", locationCtrl),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: goToCourtRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                "Next: Register Courts",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget textField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    bool isEmail = false,
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isEmail
            ? TextInputType.emailAddress
            : isNumber
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
