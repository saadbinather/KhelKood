/// Court data model
/// Implements OOP principles with encapsulation
class CourtModel {
  final String? id;
  final String courtName;
  final String? location;
  final String? city;
  final Map<String, double>? coordinates; // {latitude: double, longitude: double}
  final List<String> availableSports;
  final Map<String, int>? rates;
  final bool isVerified;
  final String? imageUrl;
  final String? ownerId;
  final String? ownerName;
  final double? rating;
  final List<String>? amenities;

  CourtModel({
    this.id,
    required this.courtName,
    this.location,
    this.city,
    this.coordinates,
    required this.availableSports,
    this.rates,
    this.isVerified = false,
    this.imageUrl,
    this.ownerId,
    this.ownerName,
    this.rating,
    this.amenities,
  });

  // Factory constructor for creating instance from JSON
  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      // Use courtName or court_name, avoid 'name' field as it might contain owner name
      courtName: json['courtName']?.toString() ?? 
                 json['court_name']?.toString() ?? 
                 'Unknown Court',
      location: json['location']?.toString(),
      city: json['city']?.toString(),
      coordinates: _parseCoordinates(json['coordinates']),
      availableSports: _parseStringList(json['availableSports']),
      rates: _parseRates(json['rates']),
      isVerified: json['isVerified'] == true || json['verified'] == true,
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      ownerId: json['ownerId']?.toString() ?? json['owner_id']?.toString(),
      ownerName: json['ownerName']?.toString() ?? json['owner_name']?.toString(),
      rating: _parseDouble(json['rating']),
      amenities: _parseStringList(json['amenities']),
    );
  }

  // Convert instance to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'courtName': courtName,
      if (location != null) 'location': location,
      if (city != null) 'city': city,
      if (coordinates != null) 'coordinates': coordinates,
      'availableSports': availableSports,
      if (rates != null) 'rates': rates,
      'isVerified': isVerified,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (ownerId != null) 'ownerId': ownerId,
      if (ownerName != null) 'ownerName': ownerName,
      if (rating != null) 'rating': rating,
      if (amenities != null) 'amenities': amenities,
    };
  }

  // Helper methods
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Map<String, int>? _parseRates(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final result = <String, int>{};
      value.forEach((key, val) {
        final intVal = val is int ? val : int.tryParse(val.toString());
        if (intVal != null) {
          result[key.toString()] = intVal;
        }
      });
      return result;
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Map<String, double>? _parseCoordinates(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final result = <String, double>{};
      final lat = _parseDouble(value['latitude']);
      final lng = _parseDouble(value['longitude']);
      if (lat != null && lng != null) {
        result['latitude'] = lat;
        result['longitude'] = lng;
        return result;
      }
    }
    return null;
  }

  // Copy with method
  CourtModel copyWith({
    String? id,
    String? courtName,
    String? location,
    String? city,
    Map<String, double>? coordinates,
    List<String>? availableSports,
    Map<String, int>? rates,
    bool? isVerified,
    String? imageUrl,
    String? ownerId,
    String? ownerName,
    double? rating,
    List<String>? amenities,
  }) {
    return CourtModel(
      id: id ?? this.id,
      courtName: courtName ?? this.courtName,
      location: location ?? this.location,
      city: city ?? this.city,
      availableSports: availableSports ?? this.availableSports,
      rates: rates ?? this.rates,
      isVerified: isVerified ?? this.isVerified,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      rating: rating ?? this.rating,
      amenities: amenities ?? this.amenities,
    );
  }

  // Get rate for specific sport
  int? getRateForSport(String sport) {
    return rates?[sport.toLowerCase()];
  }

  // Check if sport is available
  bool hasSport(String sport) {
    return availableSports
        .any((s) => s.toLowerCase() == sport.toLowerCase());
  }

  // Get formatted rating
  String get formattedRating {
    if (rating == null) return 'N/A';
    return rating!.toStringAsFixed(1);
  }

  @override
  String toString() => 'CourtModel(id: $id, courtName: $courtName, city: $city)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourtModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

