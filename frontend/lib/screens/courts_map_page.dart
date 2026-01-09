import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/models/court_model.dart';
import '../core/repositories/court_repository.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';
import '../utils/map_icons.dart';
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

  // 🔍 Search for courts
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<CourtModel> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchCourts();
    
    // Listen to search text changes for real-time filtering
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        // Show all courts when search field is focused (even if empty)
        if (_searchController.text.isEmpty) {
          setState(() {
            _searchResults = List.from(_courts); // Show all courts
            _showSearchResults = true;
          });
        } else {
          setState(() {
            _showSearchResults = true;
          });
        }
      }
    });
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    
    if (query.isEmpty) {
      // If field is focused, show all courts; otherwise hide dropdown
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _searchResults = List.from(_courts); // Show all courts
          _showSearchResults = true;
        });
      } else {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
        });
      }
      _updateMarkers(); // Show all courts on map
      return;
    }
    
    // Filter courts in real-time
    final filtered = _courts.where((court) {
      final name = court.courtName.toLowerCase();
      final location = (court.location ?? '').toLowerCase();
      final city = (court.city ?? '').toLowerCase();
      return name.contains(query) ||
          location.contains(query) ||
          city.contains(query);
    }).toList();
    
    // Sort by rating (default when searching)
    filtered.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    
    setState(() {
      _searchResults = filtered;
      _showSearchResults = true;
    });
    
    // Update markers to show only filtered courts
    _updateMarkers();
  }
  
  void _selectCourtFromSearch(CourtModel court) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showSearchResults = false;
    });
    
    // Center map on selected court
    if (court.coordinates != null && _mapController != null) {
      final coords = LatLng(
        court.coordinates!['latitude']!,
        court.coordinates!['longitude']!,
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(coords, 16.0),
      );
      
      // Show court info
      _selectCourt(court);
    }
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

      await _updateMarkers();

      // Move map to user location - use a slight delay to ensure map is ready
      if (_mapController != null && _userLocation != null) {
        // Small delay to ensure map controller is fully initialized
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_userLocation!, _zoom),
          );
        }
      }
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
        
        final allCourts = (courtsData as List)
            .map((courtJson) => CourtModel.fromJson(courtJson as Map<String, dynamic>))
            .where((court) => court.coordinates != null) // Only courts with coordinates
            .toList();
        
        // Sort by rating by default (when no search)
        allCourts.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        
        setState(() {
          _courts = allCourts;
          _isLoadingCourts = false;
        });
        await _updateMarkers();
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

  Future<void> _updateMarkers() async {
    BitmapDescriptor? userLocationIcon;
    
    // Create blue circle icon for user location
    if (_userLocation != null) {
      userLocationIcon = await MapIcons.createBlueCircleIcon();
    }
    
    setState(() {
      _markers.clear();
      
      // User location marker (blue circle)
      if (_userLocation != null && userLocationIcon != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: _userLocation!,
            icon: userLocationIcon,
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

  /// 🔢 Filter courts based on search (for markers)
  List<CourtModel> _getVisibleCourts() {
    final query = _searchController.text.trim().toLowerCase();
    
    // If no search query, show all courts sorted by rating (default)
    if (query.isEmpty) {
      final allCourts = List<CourtModel>.from(_courts);
      allCourts.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      return allCourts;
    }
    
    // Filter by search query
    return _searchResults;
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
    // Wait for location before showing map, or use a very wide default that won't show a specific country
    // If location is still loading, show loading indicator
    if (_isLoadingLocation && _userLocation == null) {
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
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.redAccent,
          ),
        ),
      );
    }

    // Use user location if available, otherwise use a neutral default (center of world map)
    final initialLocation = _userLocation ?? const LatLng(0.0, 0.0);

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
              // If we already have user location, animate to it immediately
              if (_userLocation != null) {
                // Small delay to ensure map controller is fully initialized
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted && _mapController != null && _userLocation != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(_userLocation!, _zoom),
                    );
                  }
                });
              }
            },
            initialCameraPosition: CameraPosition(
              target: initialLocation,
              zoom: _userLocation != null ? _zoom : 2.0, // Wide zoom if no location
            ),
            onTap: (LatLng position) {
              // Close court info and search results if tapping on map
              setState(() {
                _selectedCourt = null;
                _showSearchResults = false;
                _searchFocusNode.unfocus();
              });
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),

          // 🔍 Search Bar with Suggestions
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
                    focusNode: _searchFocusNode,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search courts...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                                setState(() {
                                  _showSearchResults = false;
                                });
                                _updateMarkers();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onTap: () {
                      // Show all courts when search field is clicked (even if empty)
                      if (_searchController.text.isEmpty) {
                        setState(() {
                          _searchResults = List.from(_courts); // Show all courts
                          _showSearchResults = true;
                        });
                      } else {
                        setState(() {
                          _showSearchResults = true;
                        });
                      }
                    },
                  ),
                ),
                // Search Results Dropdown
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 300),
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final court = _searchResults[index];
                        final distance = _userLocation != null && court.coordinates != null
                            ? _calculateDistance(
                                _userLocation!,
                                LatLng(
                                  court.coordinates!['latitude']!,
                                  court.coordinates!['longitude']!,
                                ),
                              ) / 1000
                            : null;
                        
                        return ListTile(
                          leading: const Icon(Icons.sports_soccer, color: Colors.redAccent),
                          title: Text(
                            court.courtName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (court.location != null)
                                Text(
                                  court.location!,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (distance != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.near_me, size: 12, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${distance.toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: court.rating != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      court.rating!.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () => _selectCourtFromSearch(court),
                        );
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
