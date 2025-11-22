import 'package:flutter/material.dart';
import 'view_court_details_page.dart'; // (to be created later)

class AvailableCourtsPage extends StatefulWidget {
  final String actionType; // <-- ADD THIS

  const AvailableCourtsPage({
    super.key,
    required this.actionType, // <-- ADD THIS
  });

  @override
  State<AvailableCourtsPage> createState() => _AvailableCourtsPageState();
}

class _AvailableCourtsPageState extends State<AvailableCourtsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'A-Z';
  List<Map<String, dynamic>> _courts = [];

  @override
  void initState() {
    super.initState();
    _fetchCourts();
  }

  void _fetchCourts() {
    // Mock API data (later replaced with backend call)
    _courts = [
      {
        "courtId": "C001",
        "name": "Urban Futsal Arena",
        "location": "Downtown Karachi",
        "rating": 4.8,
      },
      {
        "courtId": "C002",
        "name": "Street Hoops Court",
        "location": "Clifton Karachi",
        "rating": 4.5,
      },
      {
        "courtId": "C003",
        "name": "Legends Turf Ground",
        "location": "Gulshan Karachi",
        "rating": 4.9,
      },
      {
        "courtId": "C004",
        "name": "SportsZone Field",
        "location": "PECHS Karachi",
        "rating": 4.3,
      },
    ];
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      switch (_selectedFilter) {
        case 'A-Z':
          _courts.sort((a, b) => a['name'].compareTo(b['name']));
          break;
        case 'Z-A':
          _courts.sort((a, b) => b['name'].compareTo(a['name']));
          break;
        case 'Rating':
          _courts.sort((a, b) => b['rating'].compareTo(a['rating']));
          break;
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredCourts() {
    String query = _searchController.text.toLowerCase();
    return _courts
        .where((court) => court['name'].toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredCourts = _getFilteredCourts();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Available Courts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔍 Search Bar
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search courts...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1C1C1C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ⚙️ Filter Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sort by:',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: _selectedFilter,
                  dropdownColor: const Color(0xFF1C1C1C),
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

            // 🏟️ Courts List
            Expanded(
              child: ListView.builder(
                itemCount: filteredCourts.length,
                itemBuilder: (context, index) {
                  final court = filteredCourts[index];
                  return _buildCourtCard(context, court);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtCard(BuildContext context, Map<String, dynamic> court) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewCourtDetailsPage(
              courtId: court['courtId'].toString(),
              actionType: widget.actionType, // <-- PASS IT FORWARD
            ),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            court['name'],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          subtitle: Text(
            court['location'],
            style: const TextStyle(color: Colors.white60),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 4),
              Text(
                court['rating'].toString(),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.deepPurpleAccent.shade100,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
