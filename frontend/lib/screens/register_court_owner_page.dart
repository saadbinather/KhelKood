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
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController cnicCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();

  void goToCourtRegister() {
    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
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

    // No API — just navigate with a fake owner ID
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterCourtPage(
          courtOwnerId: "TEMP_OWNER_ID_123",
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
            textField("Email", emailCtrl),
            textField("Phone Number", phoneCtrl),
            textField("CNIC", cnicCtrl),
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
}
