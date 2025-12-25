import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Maps API Key from environment variables
class ApiKeys {
  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'GOOGLE_MAPS_API_KEY is not set in .env file. '
        'Please create a .env file with GOOGLE_MAPS_API_KEY=your_key_here'
      );
    }
    return key;
  }
}

