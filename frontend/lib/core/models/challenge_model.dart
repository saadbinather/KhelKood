/**
 * Challenge Model - Data entity for challenges
 * 
 * OOP Principles:
 * - Encapsulation: Data structure with business logic
 * - Single Responsibility: Only handles challenge data
 */

class ChallengeModel {
  final String id;
  final String courtId;
  final int courtNum;
  final String hostTeamId;
  final String hostTeamName;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? guestTeamId;
  final String? guestTeamName;
  final String? sportType;
  final DateTime? createdAt;

  ChallengeModel({
    required this.id,
    required this.courtId,
    required this.courtNum,
    required this.hostTeamId,
    required this.hostTeamName,
    required this.startTime,
    required this.endTime,
    this.status = 'open',
    this.guestTeamId,
    this.guestTeamName,
    this.sportType,
    this.createdAt,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id'] ?? '',
      courtId: json['courtID'] ?? json['courtId'] ?? '',
      courtNum: json['courtNum'] ?? 0,
      hostTeamId: json['hostTeamID'] ?? json['hostTeamId'] ?? '',
      hostTeamName: json['hostTeamName'] ?? 'Unknown',
      startTime: _parseDateTime(json['startTime']),
      endTime: _parseDateTime(json['endTime']),
      status: json['status'] ?? 'open',
      guestTeamId: json['guestTeamID'] ?? json['guestTeamId'],
      guestTeamName: json['guestTeamName'],
      sportType: json['sportType'],
      createdAt: json['createdAt'] != null 
          ? _parseDateTime(json['createdAt'])
          : null,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is Map && value.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value['_seconds'] as int) * 1000
      );
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courtID': courtId,
      'courtNum': courtNum,
      'hostTeamID': hostTeamId,
      'hostTeamName': hostTeamName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'status': status,
      'guestTeamID': guestTeamId,
      'guestTeamName': guestTeamName,
      'sportType': sportType,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Business logic methods
  bool isOpen() => status.toLowerCase() == 'open';
  bool isAccepted() => status.toLowerCase() == 'accepted';
  bool isCancelled() => status.toLowerCase() == 'cancelled';

  int getDurationInHours() {
    return endTime.difference(startTime).inHours;
  }

  bool isPast() {
    return endTime.isBefore(DateTime.now());
  }

  bool isUpcoming() {
    return startTime.isAfter(DateTime.now());
  }

  ChallengeModel copyWith({
    String? id,
    String? courtId,
    int? courtNum,
    String? hostTeamId,
    String? hostTeamName,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? guestTeamId,
    String? guestTeamName,
    String? sportType,
    DateTime? createdAt,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      courtId: courtId ?? this.courtId,
      courtNum: courtNum ?? this.courtNum,
      hostTeamId: hostTeamId ?? this.hostTeamId,
      hostTeamName: hostTeamName ?? this.hostTeamName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      guestTeamId: guestTeamId ?? this.guestTeamId,
      guestTeamName: guestTeamName ?? this.guestTeamName,
      sportType: sportType ?? this.sportType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

