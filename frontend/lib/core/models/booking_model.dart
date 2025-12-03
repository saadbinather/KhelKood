/**
 * Booking Model - Data entity for bookings
 * 
 * OOP Principles:
 * - Encapsulation: Data structure with validation
 * - Single Responsibility: Only handles booking data
 */

class BookingModel {
  final String id;
  final String courtId;
  final int courtNum;
  final String teamId;
  final String teamName;
  final DateTime startTime;
  final DateTime endTime;
  final int totalPrice;
  final String status;
  final bool isUnavailable;
  final String? sportType;
  final String? matchType; // 'friendly' or 'competitive'
  final String? guestTeamName;
  final DateTime? createdAt;

  BookingModel({
    required this.id,
    required this.courtId,
    required this.courtNum,
    required this.teamId,
    required this.teamName,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    this.status = 'pending',
    this.isUnavailable = false,
    this.sportType,
    this.matchType,
    this.guestTeamName,
    this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      courtId: json['courtID'] ?? json['courtId'] ?? '',
      courtNum: json['courtNum'] ?? 0,
      teamId: json['teamID'] ?? json['teamId'] ?? '',
      teamName: json['teamName'] ?? 'Unknown',
      startTime: _parseDateTime(json['startTime']),
      endTime: _parseDateTime(json['endTime']),
      totalPrice: json['totalPrice'] ?? 0,
      status: json['status'] ?? 'pending',
      isUnavailable: json['isUnavailable'] ?? false,
      sportType: json['sportType'],
      matchType: json['matchType'],
      guestTeamName: json['guestTeamName'],
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
      'teamID': teamId,
      'teamName': teamName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'totalPrice': totalPrice,
      'status': status,
      'isUnavailable': isUnavailable,
      'sportType': sportType,
      'matchType': matchType,
      'guestTeamName': guestTeamName,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Business logic methods
  bool isFriendly() => matchType?.toLowerCase() == 'friendly';
  bool isCompetitive() => matchType?.toLowerCase() == 'competitive';
  
  int getDurationInHours() {
    return endTime.difference(startTime).inHours;
  }

  bool isPast() {
    return endTime.isBefore(DateTime.now());
  }

  bool isActive() {
    final now = DateTime.now();
    return startTime.isBefore(now) && endTime.isAfter(now);
  }

  bool isUpcoming() {
    return startTime.isAfter(DateTime.now());
  }
}

