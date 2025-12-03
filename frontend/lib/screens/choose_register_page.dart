import 'package:flutter/material.dart';
import 'register_team_page.dart';
import '../CourtOwner/register_court_owner_page.dart';

class ChooseRegisterPage extends StatelessWidget {
  final String? firebaseUid;
  final String? email;
  final bool fromGoogle;

  const ChooseRegisterPage({
    super.key,
    this.firebaseUid,
    this.email,
    this.fromGoogle = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen ? 16.0 : isTablet ? 32.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.app_registration,
              color: Colors.redAccent,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              "Register",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 18 : 20,
              ),
            ),
          ],
      ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group_add,
                  color: Colors.redAccent,
                  size: isSmallScreen ? 24 : 28,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
              "Register as",
              style: TextStyle(
                color: Colors.white,
                    fontSize: isSmallScreen ? 24 : 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              "Choose your account type",
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: isSmallScreen ? 40 : 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterTeamPage(
                        firebaseUid: firebaseUid,
                        email: email,
                        fromGoogle: fromGoogle,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 40 : isTablet ? 56 : 48,
                    vertical: isSmallScreen ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                  Icons.groups,
                  size: isSmallScreen ? 18 : 20,
                ),
                label: Text(
                  "Team",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterCourtOwnerPage(
                        firebaseUid: firebaseUid,
                        email: email,
                        fromGoogle: fromGoogle,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 40 : isTablet ? 56 : 48,
                    vertical: isSmallScreen ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.business,
                  size: isSmallScreen ? 18 : 20,
                ),
                label: Text(
                  "Court Owner",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
