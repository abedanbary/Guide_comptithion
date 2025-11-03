import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'EditRoadScreen.dart';
import '../utils/route_helpers.dart';

class GuideRoadsScreen extends StatefulWidget {
  const GuideRoadsScreen({super.key});

  @override
  State<GuideRoadsScreen> createState() => _GuideRoadsScreenState();
}

class _GuideRoadsScreenState extends State<GuideRoadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Professional color palette
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);
  static const Color lightBlue = Color(0xFF6B89A8);
  static const Color darkBlue = Color(0xFF2A3F5F);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: cardColor,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
                decoration: InputDecoration(
                  hintText: 'Search routes...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, color: primaryBlue),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Roads List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('roads')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(context);
                }

                final roads = snapshot.data!.docs;

                // Filter roads based on search query
                final filteredRoads = roads.where((road) {
                  final data = road.data() as Map<String, dynamic>;
                  final roadName = (data['roadName'] ?? '').toString().toLowerCase();
                  return roadName.contains(_searchQuery);
                }).toList();

                if (filteredRoads.isEmpty && _searchQuery.isNotEmpty) {
                  return _buildNoResultsState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRoads.length,
                  itemBuilder: (context, index) {
                    final road = filteredRoads[index];
                    final data = road.data() as Map<String, dynamic>;
                    return _buildRoadCard(context, road.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No routes found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.route_outlined,
              size: 80,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Routes Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first hiking route\nto get started!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoadCard(BuildContext context, String roadId, Map<String, dynamic> data) {
    final name = data['roadName'] ?? 'Untitled Route';
    final createdAt = data['createdAt']?.toDate();
    final points = (data['points'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pointsCount = points.length;
    final routePolyline = (data['routePolyline'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final imageUrl = data['imageUrl'] as String?;

    // Calculate distance and time
    Map<String, dynamic> routeInfo = {'distanceFormatted': '---', 'timeFormatted': '---'};
    if (routePolyline.isNotEmpty) {
      routeInfo = RouteHelpers.calculateRouteInfo(routePolyline);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showRoadDetails(context, roadId, data),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route Image (if available)
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Image.network(
                    imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.terrain,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (imageUrl == null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.terrain,
                              color: primaryBlue,
                              size: 28,
                            ),
                          ),
                        if (imageUrl == null) const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (createdAt != null)
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatChip(
                      Icons.location_on,
                      '$pointsCount waypoints',
                      primaryBlue,
                    ),
                    _buildStatChip(
                      Icons.straighten,
                      routeInfo['distanceFormatted'],
                      Colors.green.shade700,
                    ),
                    _buildStatChip(
                      Icons.access_time,
                      routeInfo['timeFormatted'],
                      Colors.orange.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showRoadDetails(context, roadId, data),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View'),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditRoadScreen(
                              roadId: roadId,
                              roadData: data,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGold,
                        foregroundColor: darkBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteRoad(context, roadId, name),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red.shade700,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showRoadDetails(BuildContext context, String roadId, Map<String, dynamic> data) {
    final name = data['roadName'] ?? 'Untitled Route';
    final points = (data['points'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final routePolyline = (data['routePolyline'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Use route polyline if available, otherwise use waypoints
    final displayPoints = routePolyline.isNotEmpty ? routePolyline : points;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.route, color: primaryBlue, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        Text(
                          '${points.length} waypoints',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: points.isEmpty
                  ? const Center(child: Text('No waypoints'))
                  : Column(
                      children: [
                        // Map Preview
                        Container(
                          height: 250,
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                points[0]['latitude'] as double,
                                points[0]['longitude'] as double,
                              ),
                              initialZoom: 13,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              ),
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: displayPoints
                                        .map((p) => LatLng(
                                              p['latitude'] as double,
                                              p['longitude'] as double,
                                            ))
                                        .toList(),
                                    color: primaryBlue,
                                    strokeWidth: 4,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: points.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final point = entry.value;
                                  return Marker(
                                    point: LatLng(
                                      point['latitude'] as double,
                                      point['longitude'] as double,
                                    ),
                                    width: 40,
                                    height: 40,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: primaryBlue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        // Waypoints List
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.list_alt, color: darkBlue),
                              const SizedBox(width: 8),
                              const Text(
                                'Waypoints',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: points.length,
                            itemBuilder: (context, index) {
                              final point = points[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: primaryBlue,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    point['name'] ?? 'Waypoint ${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        point['question'] ?? 'No question',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${point['latitude']?.toStringAsFixed(4)}, ${point['longitude']?.toStringAsFixed(4)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.quiz,
                                    color: accentGold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRoad(BuildContext context, String roadId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Text('Delete Route?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$name"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('roads')
                    .doc(roadId)
                    .delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Route "$name" deleted'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
