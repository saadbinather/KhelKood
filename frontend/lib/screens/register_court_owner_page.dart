import 'package:flutter/material.dart';
import 'register_court_page.dart';

class RegisterCourtOwnerPage extends StatefulWidget {
  final String? firebaseUid;
  final String? email;
  final bool fromGoogle;

  const RegisterCourtOwnerPage({
    super.key,
    this.firebaseUid,
    this.email,
    this.fromGoogle = false,
  });

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

  @override
  void initState() {
    super.initState();
    if (widget.fromGoogle && widget.email != null) {
      emailCtrl.text = widget.email!;
    }
  }

  void goToCourtRegister() {
    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        phoneCtrl.text.isEmpty ||
        cnicCtrl.text.isEmpty ||
        locationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All fields are required"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!widget.fromGoogle && passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password is required"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!widget.fromGoogle && passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterCourtPage(
          ownerName: nameCtrl.text.trim(),
          ownerEmail: emailCtrl.text.trim(),
          ownerPassword: widget.fromGoogle ? "" : passwordCtrl.text.trim(),
          ownerPhone: phoneCtrl.text,
          ownerCnic: cnicCtrl.text,
          ownerLocation: locationCtrl.text.trim(),
          firebaseUid: widget.firebaseUid,
          fromGoogle: widget.fromGoogle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Court Owner Details",
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
              "Enter your personal information",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField("Full Name", nameCtrl),
            const SizedBox(height: 20),
            _buildTextField(
              "Email",
              emailCtrl,
              isEmail: true,
              readOnly: widget.fromGoogle,
            ),
            if (!widget.fromGoogle) ...[
              const SizedBox(height: 20),
              _buildTextField(
                "Password (min 6 characters)",
                passwordCtrl,
                isPassword: true,
              ),
            ],
            const SizedBox(height: 20),
            _buildTextField("Phone Number", phoneCtrl, isNumber: true),
            const SizedBox(height: 20),
            _buildTextField("CNIC", cnicCtrl, isNumber: true),
            const SizedBox(height: 20),
            _buildTextField("Location", locationCtrl),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: goToCourtRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Next: Register Courts",
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    bool isEmail = false,
    bool isNumber = false,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      keyboardType: isEmail
          ? TextInputType.emailAddress
          : isNumber
              ? TextInputType.number
              : TextInputType.text,
      style: TextStyle(
        color: readOnly ? Colors.white54 : Colors.white,
      ),
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
}
