// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;

// /// 📍 Location Picker - Works exactly like Google Maps
// class LocationPicker extends StatefulWidget {
//   final Function(double latitude, double longitude, String placeName)
//       onLocationSelected;
//   final double? initialLatitude;
//   final double? initialLongitude;

//   const LocationPicker({
//     super.key,
//     required this.onLocationSelected,
//     this.initialLatitude,
//     this.initialLongitude,
//   });

//   @override
//   State<LocationPicker> createState() => _LocationPickerState();
// }

// class _LocationPickerState extends State<LocationPicker> {
//   GoogleMapController? _mapController;
//   LatLng _selectedLocation = const LatLng(33.6844, 73.0479); // Default: Islamabad
//   final Set<Marker> _markers = {};
  
//   String _placeName = "Tap on map to select location";
//   String? _plusCode;
//   bool _isLoadingAddress = false;
//   double _zoom = 15.0;
  
//   final Map<String, String> _addressCache = {};
//   static const String _googleApiKey = "AIzaSyDUPqpFrBwWcWnwcTvQp-RfW2rkCISUgyI";
  
//   // Track camera position for drag-to-update behavior
//   CameraPosition? _currentCameraPosition;
  
//   // 🔍 Search functionality
//   final TextEditingController _searchController = TextEditingController();
//   List<Map<String, dynamic>> _searchSuggestions = [];
//   bool _showSuggestions = false;
//   bool _isSearching = false;
//   bool _hasSearchText = false;
//   FocusNode _searchFocusNode = FocusNode();

//   @override
//   void initState() {
//     super.initState();
    
//     // Listen to focus changes to show suggestions
//     _searchFocusNode.addListener(() {
//       if (_searchFocusNode.hasFocus && _searchSuggestions.isNotEmpty) {
//         setState(() {
//           _showSuggestions = true;
//         });
//       }
//     });
    
//     if (widget.initialLatitude != null && widget.initialLongitude != null) {
//       _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
//       _updateMarker();
//       _getPlaceFromCoordinates(_selectedLocation);
//     } else {
//       _getCurrentLocation();
//     }
//   }

//   void _updateMarker() {
//     setState(() {
//       _markers.clear();
//       _markers.add(
//         Marker(
//           markerId: const MarkerId("selected_location"),
//           position: _selectedLocation,
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//           anchor: const Offset(0.5, 1.0), // Pin point at bottom center
//         ),
//       );
//     });
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       if (!await Geolocator.isLocationServiceEnabled()) {
//         _showSnack("Location services are disabled");
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.deniedForever) {
//         _showSnack("Location permission denied");
//         return;
//       }

//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       _selectedLocation = LatLng(position.latitude, position.longitude);
//       _updateMarker();
//       _getPlaceFromCoordinates(_selectedLocation);

//       await _mapController?.animateCamera(
//         CameraUpdate.newLatLngZoom(_selectedLocation, _zoom),
//       );
//     } catch (_) {
//       _showSnack("Failed to get location");
//     }
//   }

//   /// Extract comprehensive address (Google Maps format)
//   /// ALWAYS shows the exact place name if available (like "Raheel General Store")
//   String _extractPlaceName(Map<String, dynamic> result) {
//     final components = result["address_components"] as List<dynamic>?;

//     // 🎯 PRIORITY 1: Get place name from "name" field - this is the EXACT location name
//     // Google Maps shows this first (e.g., "Raheel General Store")
//     String? placeName = result["name"] as String?;
    
//     // Check if "name" is actually a place name (not just formatted address)
//     bool isActualPlaceName = false;
//     if (placeName != null && placeName.isNotEmpty) {
//       // If name doesn't contain commas and is not too long, it's likely a place name
//       if (!placeName.contains(',') && placeName.length < 100) {
//         isActualPlaceName = true;
//       }
//       // Also check if it has establishment types
//       if (components != null) {
//         for (var comp in components) {
//           final types = List<String>.from(comp["types"] ?? []);
//           if (types.contains("point_of_interest") ||
//               types.contains("establishment") ||
//               types.contains("premise") ||
//               types.contains("store") ||
//               types.contains("restaurant") ||
//               types.contains("hospital") ||
//               types.contains("school") ||
//               types.contains("mosque") ||
//               types.contains("church")) {
//             isActualPlaceName = true;
//             break;
//           }
//         }
//       }
//     }

//     String? establishmentName;
//     String? locality;
//     String? city;
//     String? state;
//     String? country;

//     // Parse address components
//     if (components != null) {
//       for (var comp in components) {
//         final types = List<String>.from(comp["types"] ?? []);
//         final longName = comp["long_name"] as String?;
//         if (longName == null || longName.isEmpty) continue;

//         if (types.contains("point_of_interest") ||
//             types.contains("establishment") ||
//             types.contains("premise")) {
//           establishmentName ??= longName;
//         } else if (types.contains("sublocality") ||
//             types.contains("sublocality_level_1") ||
//             types.contains("neighborhood")) {
//           locality ??= longName;
//         } else if (types.contains("locality")) {
//           city ??= longName;
//         } else if (types.contains("administrative_area_level_1")) {
//           state ??= longName;
//         } else if (types.contains("country")) {
//           country ??= longName;
//         }
//       }
//     }

//     // Use place name from "name" field if it's a real place name, otherwise use establishment
//     final finalPlaceName = (isActualPlaceName && placeName != null) 
//         ? placeName 
//         : (placeName ?? establishmentName);

//     // Build address: ALWAYS show place name first if available, then locality, city, state, country
//     final addressParts = <String>[];
    
//     // 🎯 ALWAYS add place name FIRST if it exists (this is what Google Maps does)
//     if (finalPlaceName != null && finalPlaceName.isNotEmpty) {
//       // Only skip if it's exactly the same as locality or city (to avoid duplicates)
//       if (finalPlaceName != locality && finalPlaceName != city) {
//         addressParts.add(finalPlaceName);
//       }
//     }
    
//     // Add locality (neighborhood/sublocality)
//     if (locality != null &&
//         locality != finalPlaceName &&
//         locality != city) {
//       addressParts.add(locality);
//     }
    
//     // Add city
//     if (city != null && city != locality && city != finalPlaceName) {
//       addressParts.add(city);
//     }
    
//     // Add state
//     if (state != null) {
//       addressParts.add(state);
//     }
    
//     // Add country
//     if (country != null) {
//       addressParts.add(country);
//     }

//     if (addressParts.isNotEmpty) {
//       return addressParts.join(", ");
//     }

//     // Fallback to formatted_address
//     return result["formatted_address"] ?? "Unknown Location";
//   }

//   /// Reverse geocoding with location snapping (Google Maps style)
//   Future<void> _getPlaceFromCoordinates(LatLng position) async {
//     final cacheKey =
//         "${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}";

//     // Check cache
//     if (_addressCache.containsKey(cacheKey)) {
//       setState(() {
//         _placeName = _addressCache[cacheKey]!;
//         _isLoadingAddress = false;
//       });
//       return;
//     }

//     setState(() {
//       _isLoadingAddress = true;
//       _placeName = "Detecting place...";
//       _plusCode = null;
//     });

//     try {
//       final url = Uri.parse(
//         "https://maps.googleapis.com/maps/api/geocode/json"
//         "?latlng=${position.latitude},${position.longitude}"
//         "&key=$_googleApiKey&language=en",
//       );

//       final response = await http.get(url).timeout(const Duration(seconds: 6));
//       final data = json.decode(response.body);

//       if (data["status"] != "OK" || data["results"].isEmpty) {
//         throw Exception("No results");
//       }

//       // 🎯 Google Maps behavior: Find the result with the EXACT place name
//       // Priority: establishment/POI results with "name" field = exact location name
//       Map<String, dynamic>? bestResult;
      
//       // Priority 1: Look for results with types "establishment" or "point_of_interest"
//       // These have the exact place names like "Raheel General Store"
//       for (var result in data["results"]) {
//         final resultMap = result as Map<String, dynamic>;
//         final types = List<String>.from(resultMap["types"] ?? []);
        
//         // Check if this is an establishment or POI result
//         if (types.contains("establishment") || 
//             types.contains("point_of_interest") ||
//             types.contains("premise")) {
//           final name = resultMap["name"] as String?;
//           // If it has a name, this is the exact place we want
//           if (name != null && name.isNotEmpty) {
//             bestResult = resultMap;
//             break;
//           }
//         }
//       }
      
//       // Priority 2: Look for any result with a "name" field that's not just an address
//       if (bestResult == null) {
//         for (var result in data["results"]) {
//           final resultMap = result as Map<String, dynamic>;
//           final name = resultMap["name"] as String?;
//           final components = resultMap["address_components"] as List<dynamic>?;
          
//           if (name != null && name.isNotEmpty) {
//             // Check if name is actually a place name (not just locality/city)
//             Set<String> addressNames = {};
//             if (components != null) {
//               for (var comp in components) {
//                 final longName = comp["long_name"] as String?;
//                 final shortName = comp["short_name"] as String?;
//                 if (longName != null) addressNames.add(longName);
//                 if (shortName != null) addressNames.add(shortName);
//               }
//             }
            
//             // If name doesn't match any address component, it's a place name
//             if (!addressNames.contains(name)) {
//               bestResult = resultMap;
//               break;
//             }
//           }
//         }
//       }
      
//       // Priority 3: Use the FIRST result (most specific) - Google Maps default
//       // The first result is always the most accurate location
//       bestResult ??= data["results"][0] as Map<String, dynamic>;
      
//       String place = _extractPlaceName(bestResult);

//       // Extract Plus Code
//       String? plusCode;
//       final plusCodeData = bestResult["plus_code"] as Map<String, dynamic>?;
//       if (plusCodeData != null) {
//         plusCode = plusCodeData["compound_code"] as String?;
//         if (plusCode == null || plusCode.isEmpty) {
//           plusCode = plusCodeData["global_code"] as String?;
//         }
//         // Extract just the code (e.g., "HC63+JH5" from "HC63+JH5 Tajpura, Lahore")
//         if (plusCode != null && plusCode.contains(' ')) {
//           plusCode = plusCode.split(' ').first;
//         }
//       }

//       // 🎯 Location Snapping: Snap to nearest known location
//       LatLng? snappedLocation;
//       final geometry = bestResult["geometry"] as Map<String, dynamic>?;
//       if (geometry != null) {
//         final location = geometry["location"] as Map<String, dynamic>?;
//         if (location != null) {
//           final lat = location["lat"] as double?;
//           final lng = location["lng"] as double?;
//           if (lat != null && lng != null) {
//             snappedLocation = LatLng(lat, lng);
//           }
//         }
//       }

//       // Cache the result
//       _addressCache[cacheKey] = place;

//       setState(() {
//         _placeName = place;
//         _plusCode = plusCode;
        
//         // Snap location if available and different from current
//         if (snappedLocation != null) {
//           final distance = _calculateDistance(position, snappedLocation);
//           // Only snap if the distance is significant (more than 10 meters)
//           if (distance > 10) {
//             _selectedLocation = snappedLocation;
//             _updateMarker();
//             // Smoothly animate to snapped location
//             _mapController?.animateCamera(
//               CameraUpdate.newLatLng(snappedLocation),
//             );
//           }
//         }
        
//         _isLoadingAddress = false;
//       });
//     } catch (_) {
//       setState(() {
//         _placeName = "Nearby Location";
//         _plusCode = null;
//         _isLoadingAddress = false;
//       });
//     }
//   }

//   /// Calculate distance between two points in meters
//   double _calculateDistance(LatLng point1, LatLng point2) {
//     return Geolocator.distanceBetween(
//       point1.latitude,
//       point1.longitude,
//       point2.latitude,
//       point2.longitude,
//     );
//   }

//   /// 🔍 Search places using Google Places Autocomplete
//   Future<void> _searchPlaces(String query) async {
//     if (query.isEmpty) {
//       if (!mounted) return;
//       setState(() {
//         _searchSuggestions = [];
//         _showSuggestions = false;
//         _isSearching = false;
//       });
//       return;
//     }

//     if (!mounted) return;
//     setState(() {
//       _isSearching = true;
//       _showSuggestions = true;
//     });

//     try {
//       // Use Google Places Autocomplete API
//       final url = Uri.parse(
//         "https://maps.googleapis.com/maps/api/place/autocomplete/json"
//         "?input=${Uri.encodeComponent(query)}"
//         "&key=$_googleApiKey"
//         "&language=en"
//         "&components=country:pk", // Restrict to Pakistan (optional)
//       );

//       final response = await http.get(url).timeout(const Duration(seconds: 5));
//       final data = json.decode(response.body);

//       if (!mounted) return;
      
//       if (data["status"] == "OK" && data["predictions"] != null) {
//         final predictions = List<Map<String, dynamic>>.from(data["predictions"]);
//         setState(() {
//           _searchSuggestions = predictions;
//           _isSearching = false;
//           _showSuggestions = predictions.isNotEmpty; // Show suggestions if we have any
//         });
//       } else {
//         setState(() {
//           _searchSuggestions = [];
//           _isSearching = false;
//           _showSuggestions = false; // Hide if no results
//         });
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _searchSuggestions = [];
//         _isSearching = false;
//       });
//     }
//   }

//   /// 📍 Get place details and move map to location
//   Future<void> _selectPlaceFromSearch(Map<String, dynamic> prediction) async {
//     final placeId = prediction["place_id"] as String?;
//     if (placeId == null) return;

//     if (!mounted) return;
//     final description = prediction["description"] as String? ?? "";
//     setState(() {
//       _showSuggestions = false;
//       _searchController.text = description;
//       _hasSearchText = description.isNotEmpty;
//       _searchFocusNode.unfocus();
//       _isLoadingAddress = true;
//     });

//     try {
//       // Get place details using Place Details API
//       final url = Uri.parse(
//         "https://maps.googleapis.com/maps/api/place/details/json"
//         "?place_id=$placeId"
//         "&key=$_googleApiKey"
//         "&fields=geometry,formatted_address,name,plus_code",
//       );

//       final response = await http.get(url).timeout(const Duration(seconds: 5));
//       final data = json.decode(response.body);

//       if (data["status"] == "OK" && data["result"] != null) {
//         final result = data["result"] as Map<String, dynamic>;
//         final geometry = result["geometry"] as Map<String, dynamic>?;
        
//         if (geometry != null) {
//           final location = geometry["location"] as Map<String, dynamic>?;
//           if (location != null) {
//             final lat = location["lat"] as double?;
//             final lng = location["lng"] as double?;
            
//             if (lat != null && lng != null) {
//               final newLocation = LatLng(lat, lng);
              
//               // Update location and marker
//               _selectedLocation = newLocation;
//               _updateMarker();
              
//               // Get address from coordinates (to get full address with place name)
//               await _getPlaceFromCoordinates(newLocation);
              
//               // Animate camera to new location
//               await _mapController?.animateCamera(
//                 CameraUpdate.newLatLngZoom(newLocation, 17.0),
//               );
//             }
//           }
//         }
//       }
//     } catch (e) {
//       if (!mounted) return;
//       _showSnack("Failed to load place details");
//       setState(() {
//         _isLoadingAddress = false;
//       });
//     }
//   }

//   /// Handle map tap
//   Future<void> _onMapTap(LatLng position) async {
//     // Close search suggestions when tapping map
//     setState(() {
//       _showSuggestions = false;
//       _searchFocusNode.unfocus();
//     });
    
//     _selectedLocation = position;
//     _updateMarker();
    
//     // Animate camera to tapped location
//     await _mapController?.animateCamera(
//       CameraUpdate.newLatLng(position),
//     );
    
//     // Small delay for smooth animation
//     await Future.delayed(const Duration(milliseconds: 300));
    
//     // Get place information
//     _getPlaceFromCoordinates(position);
//   }

//   /// Handle camera movement (for drag-to-update)
//   void _onCameraMove(CameraPosition position) {
//     _currentCameraPosition = position;
//     setState(() {
//       _zoom = position.zoom;
//     });
//   }

//   /// Handle camera idle (when user stops dragging)
//   void _onCameraIdle() {
//     if (_currentCameraPosition != null) {
//       final center = _currentCameraPosition!.target;
//       _selectedLocation = center;
//       _updateMarker();
//       _getPlaceFromCoordinates(center);
//     }
//   }

//   void _confirmLocation() {
//     widget.onLocationSelected(
//       _selectedLocation.latitude,
//       _selectedLocation.longitude,
//       _placeName,
//     );
//     Navigator.pop(context);
//   }

//   void _showSnack(String text) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(text)),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: const Text(
//           "Select Court Location",
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
//         ),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         iconTheme: const IconThemeData(color: Colors.white),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.my_location),
//             onPressed: _getCurrentLocation,
//             tooltip: "Use current location",
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           // Google Map (drawn first, behind everything)
//           GoogleMap(
//             onMapCreated: (controller) => _mapController = controller,
//             initialCameraPosition: CameraPosition(
//               target: _selectedLocation,
//               zoom: _zoom,
//             ),
//             onTap: _onMapTap,
//             onCameraMove: _onCameraMove,
//             onCameraIdle: _onCameraIdle,
//             markers: _markers,
//             myLocationEnabled: true,
//             myLocationButtonEnabled: false,
//             zoomControlsEnabled: false,
//             mapType: MapType.normal,
//             onLongPress: (LatLng position) {
//               // Long press also selects location
//               _onMapTap(position);
//             },
//           ),

//           // 🔍 Search Bar (Google Maps style) - drawn on top
//           Positioned(
//             top: 10,
//             left: 10,
//             right: 10,
//             child: Material(
//               color: Colors.transparent,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Container(
//                     width: double.infinity,
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(8),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.2),
//                           blurRadius: 8,
//                           offset: const Offset(0, 2),
//                         ),
//                       ],
//                     ),
//                     child: TextField(
//                     controller: _searchController,
//                     focusNode: _searchFocusNode,
//                     decoration: InputDecoration(
//                       hintText: "Search for places...",
//                       prefixIcon: _isSearching
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: Padding(
//                                 padding: EdgeInsets.all(12.0),
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                             )
//                           : const Icon(Icons.search, color: Colors.grey),
//                       suffixIcon: _hasSearchText
//                           ? IconButton(
//                               icon: const Icon(Icons.clear, color: Colors.grey),
//                               onPressed: () {
//                                 _searchController.clear();
//                                 setState(() {
//                                   _hasSearchText = false;
//                                   _searchSuggestions = [];
//                                   _showSuggestions = false;
//                                   _isSearching = false;
//                                 });
//                                 _searchFocusNode.unfocus();
//                               },
//                             )
//                           : null,
//                       border: InputBorder.none,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 12,
//                       ),
//                     ),
//                     onChanged: (value) {
//                       setState(() {
//                         _hasSearchText = value.isNotEmpty;
//                       });
                      
//                       // Debounce search
//                       if (value.isEmpty) {
//                         setState(() {
//                           _searchSuggestions = [];
//                           _showSuggestions = false;
//                           _isSearching = false;
//                         });
//                       } else {
//                         // Show suggestions immediately if we already have some
//                         if (_searchSuggestions.isNotEmpty) {
//                           setState(() {
//                             _showSuggestions = true;
//                           });
//                         }
                        
//                         // Cancel previous search if any
//                         Future.delayed(const Duration(milliseconds: 500), () {
//                           if (mounted && _searchController.text == value && value.isNotEmpty) {
//                             _searchPlaces(value);
//                           }
//                         });
//                       }
//                     },
//                     onTap: () {
//                       // Show suggestions if we have any
//                       if (_searchSuggestions.isNotEmpty) {
//                         setState(() {
//                           _showSuggestions = true;
//                         });
//                       }
//                     },
//                     onSubmitted: (value) {
//                       // Keep suggestions visible after submitting
//                       if (_searchSuggestions.isNotEmpty) {
//                         setState(() {
//                           _showSuggestions = true;
//                         });
//                       }
//                     },
//                   ),
//                 ),
                
//                 // Search Suggestions List - show whenever we have suggestions
//                 if (_searchSuggestions.isNotEmpty)
//                   Container(
//                     margin: const EdgeInsets.only(top: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(8),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.2),
//                           blurRadius: 8,
//                           offset: const Offset(0, 2),
//                         ),
//                       ],
//                     ),
//                     constraints: const BoxConstraints(maxHeight: 300),
//                     child: ListView.builder(
//                       shrinkWrap: true,
//                       itemCount: _searchSuggestions.length,
//                       itemBuilder: (context, index) {
//                         final suggestion = _searchSuggestions[index];
//                         final mainText = suggestion["structured_formatting"]?["main_text"] as String? ?? 
//                                         suggestion["description"] as String? ?? "";
//                         final secondaryText = suggestion["structured_formatting"]?["secondary_text"] as String? ?? "";
                        
//                         return ListTile(
//                           leading: const Icon(Icons.place, color: Colors.grey),
//                           title: Text(mainText),
//                           subtitle: secondaryText.isNotEmpty 
//                               ? Text(secondaryText, style: const TextStyle(fontSize: 12))
//                               : null,
//                           onTap: () {
//                             _selectPlaceFromSearch(suggestion);
//                           },
//                           dense: true,
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // Zoom controls (positioned below search bar)
//           Positioned(
//             right: 10,
//             top: 70,
//             child: Column(
//               children: [
//                 FloatingActionButton.small(
//                   heroTag: "zoom_in",
//                   onPressed: () {
//                     setState(() {
//                       _zoom = _zoom < 20.0 ? _zoom + 1 : _zoom;
//                     });
//                     _mapController?.animateCamera(CameraUpdate.zoomIn());
//                   },
//                   backgroundColor: Colors.white,
//                   child: const Icon(Icons.add, color: Colors.black),
//                 ),
//                 const SizedBox(height: 8),
//                 FloatingActionButton.small(
//                   heroTag: "zoom_out",
//                   onPressed: () {
//                     setState(() {
//                       _zoom = _zoom > 3.0 ? _zoom - 1 : _zoom;
//                     });
//                     _mapController?.animateCamera(CameraUpdate.zoomOut());
//                   },
//                   backgroundColor: Colors.white,
//                   child: const Icon(Icons.remove, color: Colors.black),
//                 ),
//               ],
//             ),
//           ),

//           // Bottom sheet with location info
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.9),
//                 borderRadius: const BorderRadius.vertical(
//                   top: Radius.circular(20),
//                 ),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Selected Location:",
//                     style: TextStyle(
//                       color: Colors.white70,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     _placeName,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w400,
//                     ),
//                   ),
//                   if (_plusCode != null && _plusCode!.isNotEmpty) ...[
//                     const SizedBox(height: 4),
//                     Text(
//                       _plusCode!,
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 12,
//                         fontFamily: 'monospace',
//                       ),
//                     ),
//                   ],
//                   const SizedBox(height: 16),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       onPressed: _isLoadingAddress ? null : _confirmLocation,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.redAccent,
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                       child: _isLoadingAddress
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 color: Colors.white,
//                                 strokeWidth: 2,
//                               ),
//                             )
//                           : const Text(
//                               "Confirm Location",
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _mapController?.dispose();
//     _searchController.dispose();
//     _searchFocusNode.dispose();
//     super.dispose();
//   }
// }
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/google_maps_service.dart';

class LocationPicker extends StatefulWidget {
  final Function(double latitude, double longitude, String placeName)
      onLocationSelected;
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  final Set<Marker> _markers = {};

  String _placeName = "Tap on map to select location";
  String? _plusCode;
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = true;
  double _zoom = 15.0;

  CameraPosition? _currentCameraPosition;

  // 🔍 Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation =
          LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _isLoadingLocation = false;
      _updateMarker();
      _getPlaceFromCoordinates(_selectedLocation!);
    } else {
      _getCurrentLocation();
    }
  }

  // ===================== LOCATION =====================

  void _updateMarker() {
    if (_selectedLocation == null) return;
    
    _markers
      ..clear()
      ..add(
        Marker(
          markerId: const MarkerId("selected"),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _selectedLocation = const LatLng(33.6844, 73.0479); // Fallback to Islamabad
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoadingLocation = false;
            _selectedLocation = const LatLng(33.6844, 73.0479); // Fallback to Islamabad
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _selectedLocation = const LatLng(33.6844, 73.0479); // Fallback to Islamabad
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (!mounted) return;
      setState(() {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
        _isLoadingLocation = false;
      });
      
      _updateMarker();
      _getPlaceFromCoordinates(_selectedLocation!);
      
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 16),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _selectedLocation = const LatLng(33.6844, 73.0479); // Fallback to Islamabad
      });
    }
  }

  // ===================== SEARCH =====================

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;
    if (!mounted) return;

    setState(() => _isSearching = true);

    // Call backend API instead of Google directly
    final result = await GoogleMapsService.searchPlaces(query);

    if (!mounted) return;

    setState(() {
      if (result != null && result["predictions"] != null) {
        _searchSuggestions =
            List<Map<String, dynamic>>.from(result["predictions"] ?? []);
      } else {
        _searchSuggestions = [];
      }
      _isSearching = false;
    });
  }

  Future<void> _selectSuggestion(Map<String, dynamic> p) async {
    if (!mounted) return;
    _showSuggestions = false;
    _searchFocusNode.unfocus();
    setState(() {});

    final placeId = p["place_id"];
    
    // Call backend API instead of Google directly
    final result = await GoogleMapsService.getPlaceDetails(placeId);

    if (!mounted) return;

    if (result != null && result["result"] != null) {
      final loc = result["result"]["geometry"]["location"];
      final latLng = LatLng(loc["lat"], loc["lng"]);

      setState(() {
        _selectedLocation = latLng;
      });
      _updateMarker();

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 17),
      );

      _getPlaceFromCoordinates(latLng);
    }
  }

  // ===================== GEOCODING =====================

  Future<void> _getPlaceFromCoordinates(LatLng pos) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);

    // Call backend API instead of Google directly
    final result = await GoogleMapsService.getAddressFromCoords(
      pos.latitude,
      pos.longitude,
    );

    if (!mounted) return;
    
    if (result != null && result["results"] != null) {
      final results = result["results"] as List;
      if (results.isNotEmpty) {
        _placeName = results[0]["formatted_address"] ?? "Unknown location";
      }
    }

    if (!mounted) return;
    setState(() => _isLoadingAddress = false);
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    // Wait for location before showing map
    if (_isLoadingLocation || _selectedLocation == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.redAccent,
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              // If we already have location, animate to it
              if (_selectedLocation != null) {
                c.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedLocation!, _zoom),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: _selectedLocation!,
              zoom: _zoom,
            ),
            markers: _markers,
            onTap: (p) {
              _showSuggestions = false;
              _searchFocusNode.unfocus();
              setState(() {
                _selectedLocation = p;
              });
              _updateMarker();
              _getPlaceFromCoordinates(p);
            },
            onCameraMove: (p) => _currentCameraPosition = p,
            onCameraIdle: () {
              if (_currentCameraPosition != null) {
                final c = _currentCameraPosition!.target;
                setState(() {
                  _selectedLocation = c;
                });
                _updateMarker();
                _getPlaceFromCoordinates(c);
              }
            },
          ),

          // 🔍 SEARCH BAR
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: const InputDecoration(
                      hintText: "Search places",
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                    ),
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) {
                        _debounce!.cancel();
                      }

                      if (value.isEmpty) {
                        setState(() {
                          _searchSuggestions.clear();
                          _showSuggestions = false;
                        });
                        return;
                      }

                      setState(() {
                        _showSuggestions = true;
                        _isSearching = true;
                      });

                      _debounce =
                          Timer(const Duration(milliseconds: 300), () {
                        _searchPlaces(value);
                      });
                    },
                  ),
                ),

                // 🔽 SUGGESTIONS
                if (_showSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchSuggestions.length,
                            itemBuilder: (_, i) {
                              final s = _searchSuggestions[i];
                              return ListTile(
                                leading: const Icon(Icons.place),
                                title: Text(
                                  s["structured_formatting"]["main_text"],
                                ),
                                subtitle: Text(
                                  s["structured_formatting"]
                                          ["secondary_text"] ??
                                      "",
                                ),
                                onTap: () => _selectSuggestion(s),
                              );
                            },
                          ),
                  ),
              ],
            ),
          ),

          // 📍 BOTTOM
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Selected Location",
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text(
                    _placeName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: (_isLoadingAddress || _selectedLocation == null)
                        ? null
                        : () {
                            widget.onLocationSelected(
                              _selectedLocation!.latitude,
                              _selectedLocation!.longitude,
                              _placeName,
                            );
                            Navigator.pop(context);
                          },
                    child: _isLoadingAddress
                        ? const CircularProgressIndicator()
                        : const Text("Confirm Location"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
