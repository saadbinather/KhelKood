import 'package:flutter/material.dart';
import '../../core/models/team_model.dart';
import '../../core/models/court_model.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/team_stats_row.dart';
import '../../shared/widgets/court_card.dart';
import '../../shared/widgets/leaderboard_card.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../core/constants/app_colors.dart';

/// Team overview section component
/// Implements Single Responsibility - displays team overview
class TeamOverviewSection extends StatelessWidget {
  final TeamModel team;

  const TeamOverviewSection({
    super.key,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: Text(
                  team.teamName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.teamName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (team.preferredSport != null)
                      Text(
                        team.preferredSport!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TeamStatsRow(team: team),
        ],
      ),
    );
  }
}

/// Quick stats section component
/// Implements Single Responsibility - displays quick statistics
class QuickStatsSection extends StatelessWidget {
  final TeamModel team;
  final VoidCallback? onBookingsPressed;
  final VoidCallback? onChallengesPressed;

  const QuickStatsSection({
    super.key,
    required this.team,
    this.onBookingsPressed,
    this.onChallengesPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionHeader(
          title: 'Quick Stats',
          icon: Icons.dashboard,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Win Rate',
                value: '${team.winRate.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                iconColor: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Rank',
                value: team.rank?.toString() ?? 'N/A',
                icon: Icons.emoji_events,
                iconColor: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Verified courts section component
/// Implements Single Responsibility - displays list of courts
class VerifiedCourtsSection extends StatelessWidget {
  final List<CourtModel> courts;
  final bool isLoading;
  final VoidCallback? onViewAll;
  final Function(CourtModel)? onCourtTap;

  const VerifiedCourtsSection({
    super.key,
    required this.courts,
    this.isLoading = false,
    this.onViewAll,
    this.onCourtTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Verified Courts',
          icon: Icons.sports_tennis,
          actionLabel: courts.length > 3 ? 'View All' : null,
          onActionPressed: onViewAll,
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const LoadingIndicator(message: 'Loading courts...')
        else if (courts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No verified courts available',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: courts.length > 3 ? 3 : courts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return CourtCard(
                court: courts[index],
                onTap: onCourtTap != null 
                    ? () => onCourtTap!(courts[index]) 
                    : null,
              );
            },
          ),
      ],
    );
  }
}

/// Leaderboard section component
/// Implements Single Responsibility - displays team rankings
class LeaderboardSection extends StatelessWidget {
  final List<TeamModel> topTeams;
  final bool isLoading;
  final VoidCallback? onViewAll;
  final Function(TeamModel)? onTeamTap;

  const LeaderboardSection({
    super.key,
    required this.topTeams,
    this.isLoading = false,
    this.onViewAll,
    this.onTeamTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Top Teams',
          icon: Icons.leaderboard,
          actionLabel: topTeams.length > 5 ? 'View All' : null,
          onActionPressed: onViewAll,
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const LoadingIndicator(message: 'Loading leaderboard...')
        else if (topTeams.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No teams in leaderboard yet',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topTeams.length > 5 ? 5 : topTeams.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return LeaderboardCard(
                team: topTeams[index],
                rank: index + 1,
                onTap: onTeamTap != null 
                    ? () => onTeamTap!(topTeams[index]) 
                    : null,
              );
            },
          ),
      ],
    );
  }
}

