/**
 * Reusable Loading Indicator Widget
 * 
 * OOP Principles:
 * - Encapsulation: Self-contained widget
 * - Reusability: Can be used across the app
 */

import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final Color color;
  final String? message;

  const LoadingIndicator({
    super.key,
    this.color = Colors.redAccent,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: color),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

