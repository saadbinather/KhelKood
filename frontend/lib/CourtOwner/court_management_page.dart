import 'package:flutter/material.dart';

class CourtManagementPage extends StatefulWidget {
  const CourtManagementPage({Key? key}) : super(key: key);

  @override
  State<CourtManagementPage> createState() => _CourtManagementPageState();
}

class _CourtManagementPageState extends State<CourtManagementPage> {
  // Dummy JSON data
  List<Map<String, dynamic>> courts = [
    {"id": 1, "name": "Court 1", "sport": "Cricket", "status": "Available"},
    {"id": 2, "name": "Court 2", "sport": "Football", "status": "Maintenance"},
    {"id": 3, "name": "Court 3", "sport": "Padel", "status": "Available"},
  ];

  final TextEditingController _courtNameController = TextEditingController();
  String _selectedSport = "Cricket";

  void addCourt() {
    setState(() {
      courts.add({
        "id": courts.length + 1,
        "name": _courtNameController.text,
        "sport": _selectedSport,
        "status": "Available",
      });
      _courtNameController.clear();
    });
    Navigator.pop(context);
  }

  void deleteCourt(int id) {
    setState(() {
      courts.removeWhere((court) => court['id'] == id);
    });
  }

  void toggleMaintenance(int id) {
    setState(() {
      final court = courts.firstWhere((c) => c['id'] == id);
      court['status'] = court['status'] == "Available" ? "Maintenance" : "Available";
    });
  }

  void showAddCourtDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Court"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _courtNameController,
              decoration: const InputDecoration(labelText: "Court Name"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedSport,
              items: ["Cricket", "Football", "Padel"]
                  .map((sport) => DropdownMenuItem(value: sport, child: Text(sport)))
                  .toList(),
              onChanged: (value) {
                if (value != null) _selectedSport = value;
              },
              decoration: const InputDecoration(labelText: "Sport Type"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: addCourt,
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Court Management"),
        backgroundColor: Colors.redAccent,
      ),
      body: ListView.builder(
        itemCount: courts.length,
        itemBuilder: (context, index) {
          final court = courts[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(court['name']),
              subtitle: Text("${court['sport']} | Status: ${court['status']}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => deleteCourt(court['id']),
                  ),
                  IconButton(
                    icon: Icon(
                      court['status'] == "Available" ? Icons.build : Icons.check,
                      color: Colors.blue,
                    ),
                    onPressed: () => toggleMaintenance(court['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddCourtDialog,
        child: const Icon(Icons.add),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
