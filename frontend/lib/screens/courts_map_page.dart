import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/models/court_model.dart';
import '../core/repositories/court_repository.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Map view page showing user location and all courts
/// Google Maps UI with markers for courts
class CourtsMapPage extends StatefulWidget {
  const CourtsMapPage({super.key});

  @override
  State<CourtsMapPage> createState() => _CourtsMapPageState();
}

class _CourtsMapPageState extends State<CourtsMapPage> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  bool _isLoadingCourts = false;
  List<CourtModel> _courts = [];
  String? _errorMessage;
  double _zoom = 15.0;
  CourtModel? _selectedCourt;
  final Set<Marker> _markers = {};

  // 🔍 Search + filter for courts
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Distance'; // Distance, Rating, A-Z

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchCourts();
  }

  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Location services are disabled. Please enable them.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _errorMessage = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Location permissions are permanently denied. Please enable them in settings.';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
        _zoom = 15.0;
      });

      _updateMarkers();

      // Move map to user location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, _zoom),
      );
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  Future<void> _fetchCourts() async {
    setState(() {
      _isLoadingCourts = true;
      _errorMessage = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'No authentication token found';
          _isLoadingCourts = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/courts/verified'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final courtsData = data['data']?['courts'] ?? [];
        
        setState(() {
          _courts = (courtsData as List)
              .map((courtJson) => CourtModel.fromJson(courtJson as Map<String, dynamic>))
              .where((court) => court.coordinates != null) // Only courts with coordinates
              .toList();
          _isLoadingCourts = false;
        });
        _updateMarkers();
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch courts';
          _isLoadingCourts = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoadingCourts = false;
      });
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      
      // User location marker (blue point)
      if (_userLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: _userLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        );
      }
      
      // Court markers (red points) - filter by search if needed
      final visibleCourts = _getVisibleCourts();
      for (var court in visibleCourts) {
        if (court.coordinates != null) {
          final coords = LatLng(
            court.coordinates!['latitude']!,
            court.coordinates!['longitude']!,
          );
          _markers.add(
            Marker(
              markerId: MarkerId('court_${court.id}'),
              position: coords,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: court.courtName,
                snippet: court.location,
                onTap: () => _showCourtInfo(court),
              ),
              onTap: () => _showCourtInfo(court),
            ),
          );
        }
      }
    });
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// 🔢 Filter + sort courts based on search + selected filter
  List<CourtModel> _getVisibleCourts() {
    List<CourtModel> visible = List<CourtModel>.from(_courts);

    // Text search (name, location, city)
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      visible = visible.where((court) {
        final name = court.courtName.toLowerCase();
        final location = (court.location ?? '').toLowerCase();
        final city = (court.city ?? '').toLowerCase();
        return name.contains(query) ||
            location.contains(query) ||
            city.contains(query);
      }).toList();
    }

    // Sorting
    switch (_selectedFilter) {
      case 'A-Z':
        visible.sort((a, b) => a.courtName.compareTo(b.courtName));
        break;
      case 'Z-A':
        visible.sort((a, b) => b.courtName.compareTo(a.courtName));
        break;
      case 'Rating':
        visible.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case 'Distance':
      default:
        if (_userLocation != null) {
          visible.sort((a, b) {
            if (a.coordinates == null || b.coordinates == null) return 0;
            final aCoords = LatLng(
              a.coordinates!['latitude']!,
              a.coordinates!['longitude']!,
            );
            final bCoords = LatLng(
              b.coordinates!['latitude']!,
              b.coordinates!['longitude']!,
            );
            final distA = _calculateDistance(_userLocation!, aCoords);
            final distB = _calculateDistance(_userLocation!, bCoords);
            return distA.compareTo(distB);
          });
        }
        break;
    }

    return visible;
  }

  /// Alias for backward compatibility
  void _showCourtInfo(CourtModel court) {
    _selectCourt(court);
  }

  void _selectCourt(CourtModel court) {
    setState(() {
      _selectedCourt = court;
    });

    // Center map on selected court
    if (court.coordinates != null && _mapController != null) {
      final coords = LatLng(court.coordinates!['latitude']!, court.coordinates!['longitude']!);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(coords, 16.0),
      );
    }

    // Show bottom sheet with court details

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    court.courtName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (court.location != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      court.location!,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
            if (_userLocation != null && court.coordinates != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.directions_walk, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${(_calculateDistance(_userLocation!, LatLng(court.coordinates!['latitude']!, court.coordinates!['longitude']!)) / 1000).toStringAsFixed(1)} km away',
                    style: const TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                ],
              ),
            ],
            if (court.rating != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    court.rating!.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _zoomIn() {
    setState(() {
      _zoom = _zoom < 20.0 ? _zoom + 1 : _zoom;
    });
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    setState(() {
      _zoom = _zoom > 3.0 ? _zoom - 1 : _zoom;
    });
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    final initialLocation = _userLocation ?? const LatLng(33.6844, 73.0479); // Default: Islamabad

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Find Courts",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: initialLocation,
              zoom: _zoom,
            ),
            onTap: (LatLng position) {
              // Close court info if tapping on map
              setState(() {
                _selectedCourt = null;
              });
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),

          // 🔍 Search + Filter row
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search courts or areas...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {
                        _updateMarkers(); // Update markers when search changes
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (_isLoadingLocation || _isLoadingCourts)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.redAccent,
                ),
              ),
            ),
          // Error message
          if (_errorMessage != null && !_isLoadingLocation && !_isLoadingCourts)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          // Zoom controls
          Positioned(
            right: 10,
            top: 100,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "zoom_in",
                  onPressed: _zoomIn,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "zoom_out",
                  onPressed: _zoomOut,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
          // Current location button
          Positioned(
            right: 10,
            top: 200,
            child: FloatingActionButton.small(
              heroTag: "current_location",
              onPressed: _userLocation != null
                  ? () {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_userLocation!, 15.0),
                      );
                    }
                  : _getCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.my_location, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
