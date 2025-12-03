/// Challenge data model
/// Implements OOP principles with encapsulation
class ChallengeModel {
  final String? id;
  final String challengerTeamId;
  final String challengerTeamName;
  final String opponentTeamId;
  final String opponentTeamName;
  final String courtId;
  final String courtName;
  final String sport;
  final DateTime date;
  final int startSlot;
  final int endSlot;
  final String status;
  final int? amount;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final String? winnerId;
  final String? winnerName;

  ChallengeModel({
    this.id,
    required this.challengerTeamId,
    required this.challengerTeamName,
    required this.opponentTeamId,
    required this.opponentTeamName,
    required this.courtId,
    required this.courtName,
    required this.sport,
    required this.date,
    required this.startSlot,
    required this.endSlot,
    required this.status,
    this.amount,
    this.createdAt,
    this.acceptedAt,
    this.winnerId,
    this.winnerName,
  });

  // Factory constructor for creating instance from JSON
  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      challengerTeamId: json['challengerTeamId']?.toString() ?? 
                       json['challenger_team_id']?.toString() ?? '',
      challengerTeamName: json['challengerTeamName']?.toString() ?? 
                         json['challenger_team_name']?.toString() ?? 'Unknown',
      opponentTeamId: json['opponentTeamId']?.toString() ?? 
                     json['opponent_team_id']?.toString() ?? '',
      opponentTeamName: json['opponentTeamName']?.toString() ?? 
                       json['opponent_team_name']?.toString() ?? 'Unknown',
      courtId: json['courtId']?.toString() ?? json['court_id']?.toString() ?? '',
      courtName: json['courtName']?.toString() ?? json['court_name']?.toString() ?? 'Unknown',
      sport: json['sport']?.toString() ?? '',
      date: _parseDate(json['date']) ?? DateTime.now(),
      startSlot: _parseInt(json['startSlot']) ?? _parseInt(json['start_slot']) ?? 0,
      endSlot: _parseInt(json['endSlot']) ?? _parseInt(json['end_slot']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      amount: _parseInt(json['amount']),
      createdAt: _parseDate(json['createdAt']) ?? _parseDate(json['created_at']),
      acceptedAt: _parseDate(json['acceptedAt']) ?? _parseDate(json['accepted_at']),
      winnerId: json['winnerId']?.toString() ?? json['winner_id']?.toString(),
      winnerName: json['winnerName']?.toString() ?? json['winner_name']?.toString(),
    );
  }

  // Convert instance to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'challengerTeamId': challengerTeamId,
      'challengerTeamName': challengerTeamName,
      'opponentTeamId': opponentTeamId,
      'opponentTeamName': opponentTeamName,
      'courtId': courtId,
      'courtName': courtName,
      'sport': sport,
      'date': date.toIso8601String(),
      'startSlot': startSlot,
      'endSlot': endSlot,
      'status': status,
      if (amount != null) 'amount': amount,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
      if (winnerId != null) 'winnerId': winnerId,
      if (winnerName != null) 'winnerName': winnerName,
    };
  }

  // Helper methods
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // Copy with method
  ChallengeModel copyWith({
    String? id,
    String? challengerTeamId,
    String? challengerTeamName,
    String? opponentTeamId,
    String? opponentTeamName,
    String? courtId,
    String? courtName,
    String? sport,
    DateTime? date,
    int? startSlot,
    int? endSlot,
    String? status,
    int? amount,
    DateTime? createdAt,
    DateTime? acceptedAt,
    String? winnerId,
    String? winnerName,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      challengerTeamId: challengerTeamId ?? this.challengerTeamId,
      challengerTeamName: challengerTeamName ?? this.challengerTeamName,
      opponentTeamId: opponentTeamId ?? this.opponentTeamId,
      opponentTeamName: opponentTeamName ?? this.opponentTeamName,
      courtId: courtId ?? this.courtId,
      courtName: courtName ?? this.courtName,
      sport: sport ?? this.sport,
      date: date ?? this.date,
      startSlot: startSlot ?? this.startSlot,
      endSlot: endSlot ?? this.endSlot,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
    );
  }

  // Business logic methods
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  String get timeRange {
    return 'Slot $startSlot - $endSlot';
  }

  bool get isPending {
    return status.toLowerCase() == 'pending' || status.toLowerCase() == 'open';
  }

  bool get isAccepted {
    return status.toLowerCase() == 'accepted';
  }

  bool get isCompleted {
    return status.toLowerCase() == 'completed';
  }

  bool get isCancelled {
    return status.toLowerCase() == 'cancelled';
  }

  bool get isUpcoming {
    return date.isAfter(DateTime.now()) && (isPending || isAccepted);
  }

  @override
  String toString() => 
      'ChallengeModel(id: $id, challenger: $challengerTeamName, opponent: $opponentTeamName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChallengeModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

