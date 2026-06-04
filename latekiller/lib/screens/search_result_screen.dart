import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import 'stop_detail_screen.dart';

class SearchResultScreen extends StatelessWidget {
  final String query;
  final List<BusStop> stops;
  const SearchResultScreen(
      {super.key, required this.query, required this.stops});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('"$query" 검색결과')),
      body: stops.isEmpty
          ? const Center(child: Text('일치하는 정류장이 없어요'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: stops.length,
              itemBuilder: (_, i) {
                final s = stops[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.directions_bus,
                        color: Color(0xFF4A90E2)),
                    title: Text(s.stopName,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('정류소 ${s.stopNumber}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StopDetailScreen(stop: s),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
