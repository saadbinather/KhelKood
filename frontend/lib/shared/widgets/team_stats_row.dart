import 'package:flutter/material.dart';
import '../../core/models/team_model.dart';
import '../../core/constants/app_colors.dart';

/// Reusable team statistics row widget
/// Implements Single Responsibility - displays team stats in a row
class TeamStatsRow extends StatelessWidget {
  final TeamModel team;
  final bool isCompact;

  const TeamStatsRow({
    super.key,
    required this.team,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          'Wins',
          team.wins?.toString() ?? '0',
          AppColors.success,
        ),
        _buildStatItem(
          'Losses',
          team.losses?.toString() ?? '0',
          AppColors.error,
        ),
        _buildStatItem(
          'Draws',
          team.draws?.toString() ?? '0',
          AppColors.warning,
        ),
        _buildStatItem(
          'Points',
          team.points?.toString() ?? '0',
          AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isCompact ? 18 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: isCompact ? 12 : 14,
          ),
        ),
      ],
    );
  }
}

