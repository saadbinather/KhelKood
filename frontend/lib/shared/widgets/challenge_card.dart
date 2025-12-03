import 'package:flutter/material.dart';
import '../../core/models/challenge_model.dart';
import '../../core/constants/app_colors.dart';

/// Reusable challenge card widget
/// Implements Single Responsibility - displays challenge information
class ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final bool isIncoming;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;
  final bool isProcessing;

  const ChallengeCard({
    super.key,
    required this.challenge,
    this.isIncoming = false,
    this.onTap,
    this.onAccept,
    this.onDecline,
    this.onCancel,
    this.isProcessing = false,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with teams
            _buildHeader(),
            const SizedBox(height: 12),
            // Challenge details
            _buildDetails(),
            // Action buttons
            if (_shouldShowActions()) ...[
              const SizedBox(height: 16),
              _buildActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isIncoming 
                    ? challenge.challengerTeamName 
                    : challenge.opponentTeamName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIncoming ? AppColors.warning : AppColors.info,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isIncoming ? 'Incoming Challenge' : 'Outgoing Challenge',
                    style: TextStyle(
                      color: isIncoming ? AppColors.warning : AppColors.info,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color statusColor;
    String statusText;

    if (challenge.isPending) {
      statusColor = AppColors.warning;
      statusText = 'Pending';
    } else if (challenge.isAccepted) {
      statusColor = AppColors.success;
      statusText = 'Accepted';
    } else if (challenge.isCompleted) {
      statusColor = AppColors.info;
      statusText = 'Completed';
    } else {
      statusColor = AppColors.error;
      statusText = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      children: [
        _buildDetailRow(Icons.sports, challenge.sport),
        const SizedBox(height: 8),
        _buildDetailRow(Icons.location_on, challenge.courtName),
        const SizedBox(height: 8),
        _buildDetailRow(Icons.calendar_today, challenge.formattedDate),
        const SizedBox(height: 8),
        _buildDetailRow(Icons.access_time, challenge.timeRange),
        if (challenge.amount != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(Icons.monetization_on, '₹${challenge.amount}'),
        ],
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldShowActions() {
    if (isProcessing) return true;
    if (isIncoming && challenge.isPending) return true;
    if (!isIncoming && challenge.isPending && onCancel != null) return true;
    return false;
  }

  Widget _buildActions() {
    if (isProcessing) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (isIncoming && challenge.isPending) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onDecline,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Decline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    if (!isIncoming && challenge.isPending && onCancel != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.cancel, size: 18),
          label: const Text('Cancel Challenge'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

