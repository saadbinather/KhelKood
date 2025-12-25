import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'create_booking_or_challenge_page.dart';
import 'courts_map_page.dart';

class AllCourtsPage extends StatefulWidget {
  const AllCourtsPage({super.key});

  @override
  State<AllCourtsPage> createState() => _AllCourtsPageState();
}

class _AllCourtsPageState extends State<AllCourtsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'A-Z';
  List<Map<String, dynamic>> _courts = [];
  List<Map<String, dynamic>> _allCourts = [];
  bool isLoading = true;
  String? errorMessage;
  String? teamSport; // Team's sport type
  LatLng? _userLocation; // User's current location

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchTeamSport();
    _fetchVerifiedCourts();
  }

  /// Get user's current location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Re-apply filters to sort by distance if selected
      _applyFilters();
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    ) / 1000; // Convert to kilometers
  }

  /// Get distance from user location to court
  double? _getCourtDistance(Map<String, dynamic> court) {
    if (_userLocation == null || court['coordinates'] == null) return null;
    
    final coords = court['coordinates'] as Map<String, dynamic>?;
    if (coords == null) return null;
    
    final lat = coords['latitude'];
    final lng = coords['longitude'];
    if (lat == null || lng == null) return null;
    
    final courtCoords = LatLng(
      lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0,
      lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0,
    );
    
    return _calculateDistance(_userLocation!, courtCoords);
  }

  Future<void> _fetchTeamSport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/team/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final team = data['data']?['team'] ?? data['team'];
        final sport = team?['sports'] ?? data['data']?['sports'] ?? data['sports'];
        setState(() {
          teamSport = sport?.toString().toLowerCase();
        });
        // Re-filter courts after getting sport
        _filterCourtsBySport();
      }
    } catch (e) {
      print('Error fetching team sport: $e');
    }
  }

  void _filterCourtsBySport() {
    if (teamSport == null) return;
    
    setState(() {
      _courts = _allCourts.where((court) {
        // Filter courts that have fields/courts for the team's sport
        if (teamSport == 'cricket') {
          return (court['numOfCricketFields'] ?? 0) > 0;
        } else if (teamSport == 'futsal' || teamSport == 'football') {
          return (court['numOfFutsalFields'] ?? 0) > 0;
        } else if (teamSport == 'padel') {
          return (court['numOfPadelCourts'] ?? 0) > 0;
        }
        return true; // Show all if sport not recognized
      }).toList();
      _applyFilters();
    });
  }

  Future<void> _fetchVerifiedCourts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          errorMessage = 'No authentication token found';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/courts/verified'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        setState(() {
          _allCourts = List<Map<String, dynamic>>.from(
            data['data']?['courts'] ?? data['courts'] ?? [],
          );
          _courts = List.from(_allCourts);
          _filterCourtsBySport(); // Filter by sport if available
          _applyFilters();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load courts';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      switch (_selectedFilter) {
        case 'A-Z':
          _courts.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
          break;
        case 'Z-A':
          _courts.sort((a, b) => (b['name'] ?? '').compareTo(a['name'] ?? ''));
          break;
        case 'Rating':
          _courts.sort((a, b) => ((b['rating'] ?? 0) as num).compareTo((a['rating'] ?? 0) as num));
          break;
        case 'Nearest':
          if (_userLocation != null) {
            _courts.sort((a, b) {
              final distA = _getCourtDistance(a);
              final distB = _getCourtDistance(b);
              // Courts without coordinates go to the end
              if (distA == null && distB == null) return 0;
              if (distA == null) return 1;
              if (distB == null) return -1;
              return distA.compareTo(distB);
            });
          } else {
            // If no location, fall back to A-Z
            _courts.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
          }
          break;
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredCourts() {
    String query = _searchController.text.toLowerCase();
    return _courts
        .where((court) => (court['name'] ?? '').toLowerCase().contains(query) ||
            (court['address'] ?? '').toLowerCase().contains(query))
        .toList();
  }

  Widget _buildCourtCard(BuildContext context, Map<String, dynamic> court) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateBookingOrChallengePage(
              actionType: 'both',
              preSelectedCourt: court,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.redAccent.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateBookingOrChallengePage(
                    actionType: 'both',
                    preSelectedCourt: court,
                  ),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
                    child: Icon(
              Icons.sports_soccer,
              color: Colors.redAccent,
                      size: isSmallScreen ? 20 : 24,
            ),
          ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
            court['name'] ?? 'Unknown Court',
                          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 16 : 18,
            ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
          ),
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Row(
            children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: Colors.white60,
                              size: isSmallScreen ? 14 : 16,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                court['address'] ?? 'Unknown Address',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
              ),
                          ],
                        ),
                        // Distance from user location
                        if (_getCourtDistance(court) != null) ...[
                          SizedBox(height: isSmallScreen ? 4 : 6),
                          Row(
                            children: [
                              Icon(
                                Icons.near_me,
                                color: Colors.blue,
                                size: isSmallScreen ? 14 : 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${_getCourtDistance(court)!.toStringAsFixed(1)} km away',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: isSmallScreen ? 11 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: isSmallScreen ? 4 : 6),
              Row(
                children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.white70,
                              size: isSmallScreen ? 14 : 16,
                            ),
                            SizedBox(width: 4),
                  Text(
                    '${court['openingTime'] ?? 8}:00 - ${court['closingTime'] ?? 23}:00',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                  ),
                ],
              ),
            ],
          ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          SizedBox(width: 4),
              Text(
                '${court['rating'] ?? 0}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
              ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.redAccent,
                        size: isSmallScreen ? 14 : 16,
                      ),
                    ],
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isSmallScreen ? 12.0 : isTablet ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Icon(
              Icons.sports_soccer,
              color: Colors.redAccent,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
          'All Courts',
          style: TextStyle(
            color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 18 : 20,
              ),
          ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            tooltip: 'View on Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourtsMapPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchVerifiedCourts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _allCourts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            size: 64,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No courts available',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchVerifiedCourts,
                      color: Colors.redAccent,
                      child: Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Column(
                          children: [
                            // Search Bar
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search courts...',
                                hintStyle: TextStyle(
                                  color: Colors.white54,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.redAccent.withOpacity(0.7),
                                  size: isSmallScreen ? 20 : 22,
                                ),
                                filled: true,
                                fillColor: Colors.grey[900],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isSmallScreen ? 12 : 16,
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            // Filter Dropdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.sort,
                                      color: Colors.redAccent,
                                      size: isSmallScreen ? 18 : 20,
                                    ),
                                    SizedBox(width: isSmallScreen ? 6 : 8),
                                    Text(
                                  'Sort by:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: isSmallScreen ? 14 : 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 8 : 12,
                                    vertical: isSmallScreen ? 4 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                ),
                                  child: DropdownButton<String>(
                                  value: _selectedFilter,
                                  dropdownColor: Colors.grey[900],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 14 : 16,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    underline: Container(),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.redAccent,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                  items: const [
                                    DropdownMenuItem(value: 'A-Z', child: Text('A-Z')),
                                    DropdownMenuItem(value: 'Z-A', child: Text('Z-A')),
                                    DropdownMenuItem(value: 'Rating', child: Text('Rating')),
                                    DropdownMenuItem(value: 'Nearest', child: Text('Nearest')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedFilter = value!;
                                      _applyFilters();
                                    });
                                  },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Courts List
                            Expanded(
                              child: ListView.builder(
                                itemCount: _getFilteredCourts().length,
                                itemBuilder: (context, index) {
                                  final court = _getFilteredCourts()[index];
                                  return _buildCourtCard(context, court);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

