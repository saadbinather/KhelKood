/// Team data model
/// Implements OOP principles with encapsulation
class TeamModel {
  final String? id;
  final String teamName;
  final String email;
  final String? phone;
  final String? city;
  final String? preferredSport;
  final int? wins;
  final int? losses;
  final int? draws;
  final int? points;
  final int? rank;
  final DateTime? createdAt;

  TeamModel({
    this.id,
    required this.teamName,
    required this.email,
    this.phone,
    this.city,
    this.preferredSport,
    this.wins,
    this.losses,
    this.draws,
    this.points,
    this.rank,
    this.createdAt,
  });

  // Factory constructor for creating instance from JSON
  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      teamName: json['teamName']?.toString() ?? 'Unknown Team',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      preferredSport: json['preferredSport']?.toString(),
      wins: _parseInt(json['wins']),
      losses: _parseInt(json['losses']),
      draws: _parseInt(json['draws']),
      points: _parseInt(json['points']),
      rank: _parseInt(json['rank']),
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) 
          : null,
    );
  }

  // Convert instance to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'teamName': teamName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      if (preferredSport != null) 'preferredSport': preferredSport,
      if (wins != null) 'wins': wins,
      if (losses != null) 'losses': losses,
      if (draws != null) 'draws': draws,
      if (points != null) 'points': points,
      if (rank != null) 'rank': rank,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  // Helper method to safely parse integers
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  // Create a copy with modified fields
  TeamModel copyWith({
    String? id,
    String? teamName,
    String? email,
    String? phone,
    String? city,
    String? preferredSport,
    int? wins,
    int? losses,
    int? draws,
    int? points,
    int? rank,
    DateTime? createdAt,
  }) {
    return TeamModel(
      id: id ?? this.id,
      teamName: teamName ?? this.teamName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      preferredSport: preferredSport ?? this.preferredSport,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      points: points ?? this.points,
      rank: rank ?? this.rank,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Calculate win rate
  double get winRate {
    final totalMatches = (wins ?? 0) + (losses ?? 0) + (draws ?? 0);
    if (totalMatches == 0) return 0.0;
    return ((wins ?? 0) / totalMatches) * 100;
  }

  // Get match summary
  String get matchSummary => '${wins ?? 0}W - ${losses ?? 0}L - ${draws ?? 0}D';

  @override
  String toString() => 'TeamModel(id: $id, teamName: $teamName, email: $email)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

