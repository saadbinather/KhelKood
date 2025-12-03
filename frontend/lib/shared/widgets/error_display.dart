/**
 * Reusable Error Display Widget
 * 
 * OOP Principles:
 * - Encapsulation: Self-contained error UI
 * - Reusability: Consistent error display across app
 */

import 'package:flutter/material.dart';

class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final Color textColor;
  final Color buttonColor;

  const ErrorDisplay({
    super.key,
    required this.message,
    this.onRetry,
    this.textColor = Colors.redAccent,
    this.buttonColor = Colors.redAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: textColor,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

