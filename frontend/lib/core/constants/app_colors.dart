import 'package:flutter/material.dart';

/// Application color scheme
/// Implements Single Responsibility Principle - manages only colors
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // Primary Colors
  static const Color primary = Colors.redAccent;
  static const Color secondary = Color(0xFF1E1E1E);
  static const Color background = Colors.black;
  static const Color surface = Color(0xFF1E1E1E);
  
  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textHint = Colors.white54;
  
  // Status Colors
  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;
  static const Color info = Colors.blue;
  
  // Card Colors
  static const Color cardBackground = Color(0xFF1E1E1E);
  static const Color cardBorder = Color(0xFF333333);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.redAccent, Colors.deepOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF2E2E2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

