import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/road.dart';
import '../models/point.dart';
import '../models/quiz.dart';
import '../models/route_result.dart';
import '../servers/osrm_route_service.dart';
import '../widgets/road_name_input.dart';
import '../widgets/save_road_button.dart';
import '../widgets/point_dialog.dart';
import 'my_roads_screen.dart';
import 'competition_screen.dart';

class MapCreateScreen extends StatefulWidget {
  const MapCreateScreen({super.key});

  @override
  State<MapCreateScreen> createState() => _MapCreateScreenState();
}

class _MapCreateScreenState extends State<MapCreateScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _roadNameController = TextEditingController();
  List<LatLng> _points = [];
  List<Map<String, dynamic>> _pointDetails = [];
  RouteResult? _currentRoute;
  bool _isLoadingRoute = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  // Professional color palette
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color accentOrange = Color(0xFFFF6F00);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
  }

  /// Handle map tap: open dialog to add point details
  Future<void> _onMapTap(LatLng latLng) async {
    final result = await showDialog(
      context: context,
      builder: (context) => const PointDialog(),
    );

    if (result != null) {
      setState(() {
        _points.add(latLng);
        _pointDetails.add({
          'latitude': latLng.latitude,
          'longitude': latLng.longitude,
          'name': result['name'],
          'question': result['question'],
          'options': result['options'],
          'correctIndex': result['correctIndex'],
        });
      });

      if (_points.length >= 2) {
        await _getRouteBetweenPoints();
      }
    }
  }

  /// Get route between two points
  Future<void> _getRouteBetweenPoints() async {
    setState(() => _isLoadingRoute = true);
    final start = _points[_points.length - 2];
    final end = _points.last;

    final route = await ORSRouteService.getRoute(start, end);
    if (route != null) {
      setState(() {
        if (_currentRoute == null) {
          _currentRoute = route;
        } else {
          _currentRoute!.points.addAll(route.points);
        }
      });
    }
    setState(() => _isLoadingRoute = false);
  }

  /// Save road to Firebase Firestore
  Future<void> _saveRoad() async {
    if (_roadNameController.text.isEmpty || _points.isEmpty) {
      _showSnackBar(
        'Please enter a route name and add waypoints',
        isError: true,
      );
      return;
    }

    final roadId = DateTime.now().millisecondsSinceEpoch;

    final List<Map<String, dynamic>> numberedPoints = [];
    for (int i = 0; i < _pointDetails.length; i++) {
      final point = _pointDetails[i];
      numberedPoints.add({'id': i + 1, ...point});
    }

    final road = {
      'id': roadId,
      'roadName': _roadNameController.text,
      'createdAt': DateTime.now(),
      'points': numberedPoints,
    };

    try {
      await FirebaseFirestore.instance.collection('roads').add(road);
      _showSnackBar('Route saved successfully! 🎉');

      setState(() {
        _points.clear();
        _pointDetails.clear();
        _currentRoute = null;
        _roadNameController.clear();
      });
    } catch (e) {
      _showSnackBar('Failed to save route. Please try again.', isError: true);
    }
  }

  /// Clear all current data from map
  void _clearAll() {
    if (_points.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: accentOrange),
            SizedBox(width: 12),
            Text('Clear Map?'),
          ],
        ),
        content: const Text(
          'This will remove all waypoints and routes from the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _points.clear();
                _pointDetails.clear();
                _currentRoute = null;
              });
              Navigator.pop(context);
              _showSnackBar('Map cleared');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Show professional snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: primaryGreen,
            title: const Row(
              children: [
                Icon(Icons.terrain, size: 24),
                SizedBox(width: 8),
                Text(
                  'Hiking Route Creator',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            actions: [
              _buildAppBarButton(
                icon: Icons.list_alt_rounded,
                tooltip: 'My Routes',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyRoadsScreen()),
                  );
                },
              ),
              _buildAppBarButton(
                icon: Icons.delete_sweep_rounded,
                tooltip: 'Clear Map',
                onPressed: _clearAll,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Route Name Input Card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Route Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _roadNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter route name...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(
                              Icons.hiking_rounded,
                              color: primaryGreen,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: backgroundColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: primaryGreen,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Map Container
                Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(31.9539, 35.9106),
                          initialZoom: 13,
                          onTap: (tapPosition, latLng) => _onMapTap(latLng),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          ),
                          if (_currentRoute != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _currentRoute!.points,
                                  color: primaryGreen,
                                  strokeWidth: 6,
                                  borderColor: Colors.white,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: _points.asMap().entries.map((entry) {
                              final index = entry.key;
                              final point = entry.value;
                              return Marker(
                                point: point,
                                width: 50,
                                height: 50,
                                child: _buildMarker(index),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      // Loading overlay
                      if (_isLoadingRoute)
                        Container(
                          color: Colors.black.withOpacity(0.4),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: primaryGreen,
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Calculating route...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: darkGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Points counter badge
                      if (_points.isNotEmpty)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryGreen, lightGreen],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryGreen.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_points.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Save Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  child: _buildSaveButton(),
                ),
              ],
            ),
          ),
        ],
      ),

      // Competition FAB
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          backgroundColor: accentOrange,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.emoji_events_rounded, size: 22),
          label: const Text(
            'Competition',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompetitionScreen()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      color: Colors.white,
    );
  }

  Widget _buildMarker(int index) {
    final isStart = index == 0;
    final isEnd = index == _points.length - 1;
    final Color markerColor = isStart
        ? primaryGreen
        : isEnd
        ? Colors.red.shade600
        : Colors.blue.shade600;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: markerColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: markerColor, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryGreen, lightGreen]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _saveRoad,
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Save Route',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roadNameController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
}
