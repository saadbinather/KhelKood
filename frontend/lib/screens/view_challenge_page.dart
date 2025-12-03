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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen
        ? 12.0
        : isTablet
        ? 24.0
        : 20.0;

    DateTime start = DateTime.parse(challenge["Start_Time"]);
    DateTime end = DateTime.parse(challenge["End_Time"]);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              'Challenge Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 8 : 12),
              _infoRow(
                Icons.calendar_today,
                "Date",
                challenge["Date"],
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _infoRow(
                Icons.access_time,
                "Time Slot",
                "${_formatTime(start)} - ${_formatTime(end)}",
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _infoRow(
                Icons.sports_soccer,
                "Court Name",
                challenge["Court_Name"],
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _infoRow(
                Icons.group,
                "Host Team",
                challenge["Host_Team_Name"],
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _infoRow(
                Icons.currency_rupee,
                "Total Price",
                "Rs ${challenge["Total_Price"]}",
                isSmallScreen,
              ),

              const Spacer(),

              SizedBox(height: isSmallScreen ? 20 : 24),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isIncoming
                          ? Colors.green
                          : Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 24 : 32,
                        vertical: isSmallScreen ? 14 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                    icon: Icon(
                      isIncoming ? Icons.check_circle : Icons.cancel,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    label: Text(
                      isIncoming ? "Accept Challenge" : "Cancel Challenge",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.redAccent,
          size: isSmallScreen ? 18 : 20,
        ),
        SizedBox(width: isSmallScreen ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$label:",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 13 : 14,
                ),
              ),
              SizedBox(height: isSmallScreen ? 4 : 6),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 15 : 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
