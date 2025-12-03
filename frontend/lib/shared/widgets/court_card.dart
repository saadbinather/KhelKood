/**
 * Reusable Court Card Widget
 * 
 * OOP Principles:
 * - Encapsulation: All court card UI logic in one place
 * - Single Responsibility: Only displays court information
 * - Reusability: Can be used in multiple screens
 */

import 'package:flutter/material.dart';
import '../../core/models/court_model.dart';

class CourtCard extends StatelessWidget {
  final CourtModel court;
  final bool isSelected;
  final VoidCallback? onTap;
  final String? displaySport; // Sport to display info for

  const CourtCard({
    super.key,
    required this.court,
    this.isSelected = false,
    this.onTap,
    this.displaySport,
  });

  IconData _getSportIcon(String sport) {
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

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.redAccent.withOpacity(0.2) : Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.redAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sports_tennis,
                    color: Colors.redAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      court.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (court.isVerified)
                    const Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      court.location,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              if (displaySport != null)
                _buildSportInfo(displaySport!)
              else
                _buildAllSportsInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportInfo(String sport) {
    final courts = court.getCourtsForSport(sport);
    final rate = court.getRateForSport(sport);
    
    return Row(
      children: [
        Icon(
          _getSportIcon(sport),
          color: Colors.white70,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '$courts ${sport.capitalize()} ${courts == 1 ? 'Court' : 'Courts'}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          'Rs. $rate/hr',
          style: const TextStyle(
            color: Colors.green,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAllSportsInfo() {
    final sports = <String, int>{};
    if (court.cricketCourts > 0) sports['cricket'] = court.cricketCourts;
    if (court.futsalCourts > 0) sports['futsal'] = court.futsalCourts;
    if (court.padelCourts > 0) sports['padel'] = court.padelCourts;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: sports.entries.map((entry) {
        return Chip(
          avatar: Icon(
            _getSportIcon(entry.key),
            color: Colors.white,
            size: 16,
          ),
          label: Text(
            '${entry.value} ${entry.key.capitalize()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          backgroundColor: Colors.grey[800],
        );
      }).toList(),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

