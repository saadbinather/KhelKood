/**
 * Sport Utility Functions
 * 
 * Single Responsibility: Sport-related helper functions
 */

import 'package:flutter/material.dart';

class SportUtils {
  /// Get icon for a specific sport
  static IconData getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'padel':
        return Icons.sports_tennis;
      case 'cricket':
        return Icons.sports_cricket;
      case 'futsal':
      case 'football':
        return Icons.sports_soccer;
      default:
        return Icons.sports;
    }
  }

  /// Normalize sport name (football -> futsal)
  static String normalizeSportName(String sport) {
    final normalized = sport.toLowerCase();
    if (normalized == 'football') {
      return 'futsal';
    }
    return normalized;
  }

  /// Check if two sports match (considering football = futsal)
  static bool sportsMatch(String sport1, String sport2) {
    return normalizeSportName(sport1) == normalizeSportName(sport2);
  }

  /// Get sport display name
  static String getSportDisplayName(String sport) {
    switch (sport.toLowerCase()) {
      case 'futsal':
      case 'football':
        return 'Futsal';
      case 'cricket':
        return 'Cricket';
      case 'padel':
        return 'Padel';
      default:
        return sport;
    }
  }

  /// Get all available sports
  static List<String> getAllSports() {
    return ['cricket', 'futsal', 'padel'];
  }
}

