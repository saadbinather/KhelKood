import 'package:flutter/material.dart';
import '../../core/models/team_model.dart';
import '../../core/constants/app_colors.dart';

/// Reusable leaderboard card widget
/// Implements Single Responsibility - displays team ranking
class LeaderboardCard extends StatelessWidget {
  final TeamModel team;
  final int rank;
  final VoidCallback? onTap;

  const LeaderboardCard({
    super.key,
    required this.team,
    required this.rank,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Rank badge
            _buildRankBadge(),
            const SizedBox(width: 16),
            // Team info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.teamName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    team.matchSummary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Points
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${team.points ?? 0} pts',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge() {
    Color badgeColor;
    IconData? icon;

    switch (rank) {
      case 1:
        badgeColor = const Color(0xFFFFD700); // Gold
        icon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = const Color(0xFFC0C0C0); // Silver
        icon = Icons.emoji_events;
        break;
      case 3:
        badgeColor = const Color(0xFFCD7F32); // Bronze
        icon = Icons.emoji_events;
        break;
      default:
        badgeColor = AppColors.textSecondary;
        icon = null;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: badgeColor,
          width: 2,
        ),
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: badgeColor, size: 20)
            : Text(
                '$rank',
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

