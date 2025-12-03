/// Booking data model
/// Implements OOP principles with encapsulation
class BookingModel {
  final String? id;
  final String teamId;
  final String teamName;
  final String courtId;
  final String courtName;
  final String sport;
  final DateTime date;
  final int startSlot;
  final int endSlot;
  final int totalAmount;
  final String status;
  final bool isPaid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BookingModel({
    this.id,
    required this.teamId,
    required this.teamName,
    required this.courtId,
    required this.courtName,
    required this.sport,
    required this.date,
    required this.startSlot,
    required this.endSlot,
    required this.totalAmount,
    required this.status,
    this.isPaid = false,
    this.createdAt,
    this.updatedAt,
  });

  // Factory constructor for creating instance from JSON
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      teamId: json['teamId']?.toString() ?? json['team_id']?.toString() ?? '',
      teamName: json['teamName']?.toString() ?? json['team_name']?.toString() ?? 'Unknown',
      courtId: json['courtId']?.toString() ?? json['court_id']?.toString() ?? '',
      courtName: json['courtName']?.toString() ?? json['court_name']?.toString() ?? 'Unknown',
      sport: json['sport']?.toString() ?? '',
      date: _parseDate(json['date']) ?? DateTime.now(),
      startSlot: _parseInt(json['startSlot']) ?? _parseInt(json['start_slot']) ?? 0,
      endSlot: _parseInt(json['endSlot']) ?? _parseInt(json['end_slot']) ?? 0,
      totalAmount: _parseInt(json['totalAmount']) ?? _parseInt(json['total_amount']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      isPaid: json['isPaid'] == true || json['is_paid'] == true,
      createdAt: _parseDate(json['createdAt']) ?? _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updatedAt']) ?? _parseDate(json['updated_at']),
    );
  }

  // Convert instance to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'teamId': teamId,
      'teamName': teamName,
      'courtId': courtId,
      'courtName': courtName,
      'sport': sport,
      'date': date.toIso8601String(),
      'startSlot': startSlot,
      'endSlot': endSlot,
      'totalAmount': totalAmount,
      'status': status,
      'isPaid': isPaid,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
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
  BookingModel copyWith({
    String? id,
    String? teamId,
    String? teamName,
    String? courtId,
    String? courtName,
    String? sport,
    DateTime? date,
    int? startSlot,
    int? endSlot,
    int? totalAmount,
    String? status,
    bool? isPaid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      courtId: courtId ?? this.courtId,
      courtName: courtName ?? this.courtName,
      sport: sport ?? this.sport,
      date: date ?? this.date,
      startSlot: startSlot ?? this.startSlot,
      endSlot: endSlot ?? this.endSlot,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Business logic methods
  int get durationInSlots => endSlot - startSlot;

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  String get timeRange {
    return 'Slot $startSlot - $endSlot';
  }

  bool get isUpcoming {
    return date.isAfter(DateTime.now()) && status == 'confirmed';
  }

  bool get isPending {
    return status == 'pending';
  }

  bool get isConfirmed {
    return status == 'confirmed';
  }

  bool get isCancelled {
    return status == 'cancelled';
  }

  @override
  String toString() => 'BookingModel(id: $id, courtName: $courtName, date: $formattedDate)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookingModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

