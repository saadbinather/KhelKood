import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple map widget showing court location and user's current location
class CourtLocationMap extends StatefulWidget {
  final double courtLatitude;
  final double courtLongitude;
  final String courtName;
  final String? courtAddress;

  const CourtLocationMap({
    super.key,
    required this.courtLatitude,
    required this.courtLongitude,
    required this.courtName,
    this.courtAddress,
  });

  @override
  State<CourtLocationMap> createState() => _CourtLocationMapState();
}

class _CourtLocationMapState extends State<CourtLocationMap> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  double _zoom = 14.0;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMarkers();
    _getCurrentLocation();
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      
      // Court location marker
      _markers.add(
        Marker(
          markerId: const MarkerId('court_location'),
          position: LatLng(widget.courtLatitude, widget.courtLongitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: widget.courtName,
            snippet: widget.courtAddress,
          ),
        ),
      );
      
      // User location marker
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
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _updateMarkers();
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  void _centerOnBothLocations() {
    final courtLocation = LatLng(widget.courtLatitude, widget.courtLongitude);
    
    if (_userLocation != null && _mapController != null) {
      // Calculate center point between user and court
      final centerLat = (courtLocation.latitude + _userLocation!.latitude) / 2;
      final centerLng = (courtLocation.longitude + _userLocation!.longitude) / 2;
      final centerPoint = LatLng(centerLat, centerLng);
      
      // Calculate distance to determine zoom level
      final distance = _calculateDistance(_userLocation!, courtLocation);
      double zoomLevel = 14.0;
      
      if (distance > 10000) {
        zoomLevel = 11.0;
      } else if (distance > 5000) {
        zoomLevel = 12.0;
      } else if (distance > 2000) {
        zoomLevel = 13.0;
      } else {
        zoomLevel = 14.0;
      }
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(centerPoint, zoomLevel),
      );
      setState(() {
        _zoom = zoomLevel;
      });
    } else if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(courtLocation, 15.0),
      );
    }
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
    final courtLocation = LatLng(widget.courtLatitude, widget.courtLongitude);
    final distance = _userLocation != null
        ? _calculateDistance(_userLocation!, courtLocation) / 1000
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Court Location",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_userLocation != null)
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              tooltip: "Center on both locations",
              onPressed: _centerOnBothLocations,
            ),
          IconButton(
            icon: Icon(_isLoadingLocation ? Icons.hourglass_empty : Icons.my_location),
            tooltip: "Get current location",
            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // Center on court location initially
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(courtLocation, _zoom),
              );
            },
            initialCameraPosition: CameraPosition(
              target: courtLocation,
              zoom: _zoom,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),
          // Info card at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.courtName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.courtAddress != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.courtAddress!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (distance != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_walk, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(1)} km away from you',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${widget.courtLatitude},${widget.courtLongitude}',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Get Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
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
                  heroTag: "zoom_in_map",
                  onPressed: _zoomIn,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "zoom_out_map",
                  onPressed: _zoomOut,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
