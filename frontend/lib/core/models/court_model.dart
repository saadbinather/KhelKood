/**
 * Court Model - Data entity for courts
 * 
 * OOP Principles:
 * - Encapsulation: Private fields with getters
 * - Single Responsibility: Only handles court data structure
 */

class CourtModel {
  final String id;
  final String name;
  final String location;
  final int cricketCourts;
  final int futsalCourts;
  final int padelCourts;
  final int cricketRate;
  final int futsalRate;
  final int padelRate;
  final bool isVerified;
  final String ownerId;
  final DateTime? createdAt;

  CourtModel({
    required this.id,
    required this.name,
    required this.location,
    required this.cricketCourts,
    required this.futsalCourts,
    required this.padelCourts,
    required this.cricketRate,
    required this.futsalRate,
    required this.padelRate,
    this.isVerified = false,
    required this.ownerId,
    this.createdAt,
  });

  // Factory constructor for JSON deserialization
  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      cricketCourts: json['cricketCourts'] ?? 0,
      futsalCourts: json['futsalCourts'] ?? 0,
      padelCourts: json['padelCourts'] ?? 0,
      cricketRate: json['cricketRate'] ?? 0,
      futsalRate: json['futsalRate'] ?? 0,
      padelRate: json['padelRate'] ?? 0,
      isVerified: json['isVerified'] ?? false,
      ownerId: json['ownerId'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString())
          : null,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'cricketCourts': cricketCourts,
      'futsalCourts': futsalCourts,
      'padelCourts': padelCourts,
      'cricketRate': cricketRate,
      'futsalRate': futsalRate,
      'padelRate': padelRate,
      'isVerified': isVerified,
      'ownerId': ownerId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Get total courts for a specific sport
  int getCourtsForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'cricket':
        return cricketCourts;
      case 'futsal':
      case 'football':
        return futsalCourts;
      case 'padel':
        return padelCourts;
      default:
        return 0;
    }
  }

  // Get rate for a specific sport
  int getRateForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'cricket':
        return cricketRate;
      case 'futsal':
      case 'football':
        return futsalRate;
      case 'padel':
        return padelRate;
      default:
        return 0;
    }
  }

  // CopyWith for immutability
  CourtModel copyWith({
    String? id,
    String? name,
    String? location,
    int? cricketCourts,
    int? futsalCourts,
    int? padelCourts,
    int? cricketRate,
    int? futsalRate,
    int? padelRate,
    bool? isVerified,
    String? ownerId,
    DateTime? createdAt,
  }) {
    return CourtModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      cricketCourts: cricketCourts ?? this.cricketCourts,
      futsalCourts: futsalCourts ?? this.futsalCourts,
      padelCourts: padelCourts ?? this.padelCourts,
      cricketRate: cricketRate ?? this.cricketRate,
      futsalRate: futsalRate ?? this.futsalRate,
      padelRate: padelRate ?? this.padelRate,
      isVerified: isVerified ?? this.isVerified,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

