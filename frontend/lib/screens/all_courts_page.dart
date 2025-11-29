import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'court_detail_page.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchVerifiedCourts();
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourtDetailPage(court: court),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
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
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sports_soccer,
              color: Colors.redAccent,
              size: 24,
            ),
          ),
          title: Text(
            court['name'] ?? 'Unknown Court',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                court['address'] ?? 'Unknown Address',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${court['openingTime'] ?? 8}:00 - ${court['closingTime'] ?? 23}:00',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                '${court['rating'] ?? 0}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text(
          'All Courts',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Search Bar
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search courts...',
                                hintStyle: const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                                filled: true,
                                fillColor: Colors.grey[900],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Filter Dropdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Sort by:',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                                DropdownButton<String>(
                                  value: _selectedFilter,
                                  dropdownColor: Colors.grey[900],
                                  style: const TextStyle(color: Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  items: const [
                                    DropdownMenuItem(value: 'A-Z', child: Text('A-Z')),
                                    DropdownMenuItem(value: 'Z-A', child: Text('Z-A')),
                                    DropdownMenuItem(value: 'Rating', child: Text('Rating')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedFilter = value!;
                                      _applyFilters();
                                    });
                                  },
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

